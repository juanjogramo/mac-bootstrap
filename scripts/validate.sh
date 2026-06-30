#!/usr/bin/env bash
# Validate mac-bootstrap installation and configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

declare -i VALIDATION_PASSED=0
declare -i VALIDATION_WARNINGS=0
declare -i VALIDATION_FAILED=0
declare -i VALIDATION_MANUAL=0

report_pass() {
  printf '  \033[0;32m✓\033[0m %s\n' "$1"
  VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
}

report_warn() {
  printf '  \033[0;33m⚠\033[0m %s\n' "$1"
  VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
}

report_fail() {
  printf '  \033[0;31m✗\033[0m %s\n' "$1"
  VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
}

report_manual() {
  printf '  \033[0;34m⚠\033[0m %s (requires manual action)\n' "$1"
  VALIDATION_MANUAL=$((VALIDATION_MANUAL + 1))
}

validate_applications() {
  log_section "Validating Applications"

  local apps_json
  apps_json="$(yaml_get_list "${CONFIG_DIR}/apps.yaml" "apps")"

  while IFS='|' read -r name token; do
    if command_exists brew && app_installed_cask "$token"; then
      report_pass "${name} installed (cask: ${token})"
    elif [[ -d "/Applications/${name}.app" ]]; then
      report_pass "${name} found in /Applications"
    else
      report_fail "${name} not installed (cask: ${token})"
    fi
  done < <(echo "$apps_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |app|
      puts [app["name"], app["token"]].join("|")
    end
  ')
}

validate_mas_apps() {
  log_section "Validating Mac App Store Applications"

  local mas_json
  mas_json="$(yaml_get_list "${CONFIG_DIR}/mas.yaml" "mas_apps")"

  while IFS='|' read -r name app_id; do
    if command_exists mas && app_installed_mas "$app_id"; then
      report_pass "${name} installed (MAS id: ${app_id})"
    elif [[ -d "/Applications/${name}.app" ]]; then
      report_pass "${name} found in /Applications"
    else
      report_fail "${name} not installed (MAS id: ${app_id})"
    fi
  done < <(echo "$mas_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |app|
      puts [app["name"], app["id"]].join("|")
    end
  ')
}

validate_cli_tools() {
  log_section "Validating CLI Tools"

  if command_exists brew; then
    local version
    version="$(brew --version | head -1)"
    report_pass "Homebrew: ${version}"
  else
    report_fail "Homebrew not installed"
  fi

  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    report_pass "Oh My Zsh installed"
  else
    report_fail "Oh My Zsh not installed"
  fi

  local cli_json
  cli_json="$(yaml_get_list "${CONFIG_DIR}/cli.yaml" "cli")"

  while IFS='|' read -r name formula; do
    if command_exists "$formula" || brew list "$formula" &>/dev/null; then
      local ver=""
      if command_exists "$formula"; then
        ver="$("$formula" --version 2>/dev/null | head -1 || true)"
      fi
      if [[ -n "$ver" ]]; then
        report_pass "${name}: ${ver}"
      else
        report_pass "${name} installed"
      fi
    else
      report_fail "${name} not installed (formula: ${formula})"
    fi
  done < <(echo "$cli_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |tool|
      puts [tool["name"], tool["formula"]].join("|")
    end
  ')
}

validate_macos_preferences() {
  log_section "Validating macOS Preferences"

  # Time format (AM/PM)
  local time_format
  time_format="$(defaults read com.apple.menuextra.clock DateFormat 2>/dev/null || echo "")"
  if [[ "$time_format" == *"a"* ]] || [[ "$time_format" == *"A"* ]]; then
    report_pass "Clock format: AM/PM (${time_format})"
  else
    report_warn "Clock format may not be AM/PM (current: ${time_format:-not set})"
  fi

  # Dock size
  local dock_size
  dock_size="$(defaults read com.apple.dock tilesize 2>/dev/null || echo "")"
  if [[ -n "$dock_size" ]]; then
    report_pass "Dock size: ${dock_size}px"
  else
    report_warn "Dock size not configured"
  fi

  # Dock magnification
  local dock_mag
  dock_mag="$(defaults read com.apple.dock magnification 2>/dev/null || echo "")"
  if [[ "$dock_mag" == "1" ]]; then
    report_pass "Dock magnification enabled"
  else
    report_warn "Dock magnification not enabled"
  fi

  # Battery percentage
  local battery_pct
  battery_pct="$(defaults read com.apple.menuextra.battery ShowPercent 2>/dev/null || echo "")"
  if [[ "$battery_pct" == "1" ]]; then
    report_pass "Battery percentage shown"
  else
    report_warn "Battery percentage not enabled (may require System Settings)"
  fi

  # Safari restore windows
  local safari_windows
  safari_windows="$(defaults read com.apple.Safari NSQuitAlwaysKeepsWindows 2>/dev/null || echo "")"
  if [[ "$safari_windows" == "1" ]]; then
    report_pass "Safari restores windows from last session"
  else
    report_warn "Safari window restoration not configured"
  fi

  # Stage Manager
  local stage_recent
  stage_recent="$(defaults read com.apple.WindowManager StageManagerRecentApps 2>/dev/null || echo "")"
  if [[ "$stage_recent" == "0" ]] || [[ -z "$stage_recent" ]]; then
    report_pass "Stage Manager recent apps disabled"
  else
    report_warn "Stage Manager recent apps may still be enabled"
  fi

  report_manual "Menu bar username (verify in System Settings > Control Center)"
  report_manual "Sound icon in menu bar (verify in System Settings > Control Center)"
}

validate_xcode() {
  log_section "Validating Xcode"

  local install_dir="/Applications"
  local found=false

  while IFS= read -r xcode_app; do
  [[ -n "$xcode_app" ]] || continue
    found=true
    local ver
    ver="$(basename "$xcode_app" .app | sed 's/Xcode_//')"
    if [[ -x "${xcode_app}/Contents/Developer/usr/bin/xcodebuild" ]]; then
      local build_ver
      build_ver="$("${xcode_app}/Contents/Developer/usr/bin/xcodebuild" -version 2>/dev/null | head -1 || echo "unknown")"
      report_pass "${xcode_app}: ${build_ver}"
    else
      report_warn "${xcode_app} exists but xcodebuild not available"
    fi
  done < <(find "$install_dir" -maxdepth 1 -name 'Xcode_*.app' -type d 2>/dev/null | sort)

  if [[ "$found" == "false" ]]; then
    # Also check for plain Xcode.app
    if [[ -d "/Applications/Xcode.app" ]]; then
      report_pass "/Applications/Xcode.app exists"
      found=true
    else
      report_warn "No Xcode installations found (optional unless profile enables xcode)"
    fi
  fi

  if command_exists xcode-select; then
    local dev_dir
    dev_dir="$(xcode-select -p 2>/dev/null || echo "")"
    if [[ -n "$dev_dir" ]]; then
      report_pass "Active developer directory: ${dev_dir}"
    else
      report_fail "No active developer directory configured"
    fi
  fi

  if pkgutil --pkg-info=com.apple.pkg.CLTools_Executables &>/dev/null; then
    report_pass "Standalone Command Line Tools package installed"
  elif xcode-select -p &>/dev/null; then
    report_pass "Developer tools available via Xcode"
  else
    report_warn "Command Line Tools not detected"
  fi
}

print_validation_summary() {
  log_section "Validation Summary"

  printf '\n'
  printf '  \033[0;32m✓ Installed/Configured:\033[0m %d\n' "$VALIDATION_PASSED"
  printf '  \033[0;33m⚠ Warnings:\033[0m              %d\n' "$VALIDATION_WARNINGS"
  printf '  \033[0;34m⚠ Manual action:\033[0m         %d\n' "$VALIDATION_MANUAL"
  printf '  \033[0;31m✗ Failed:\033[0m                  %d\n' "$VALIDATION_FAILED"
  printf '\n'

  if [[ "$VALIDATION_FAILED" -gt 0 ]]; then
    log_error "Validation completed with failures"
    return 1
  elif [[ "$VALIDATION_WARNINGS" -gt 0 ]] || [[ "$VALIDATION_MANUAL" -gt 0 ]]; then
    log_warn "Validation completed with warnings"
    return 0
  else
    log_success "All validations passed"
    return 0
  fi
}

run_validation() {
  log_section "mac-bootstrap Validation"

  validate_applications
  validate_mas_apps
  validate_cli_tools
  validate_macos_preferences
  validate_xcode
  print_validation_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_validation
fi
