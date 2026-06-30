#!/usr/bin/env bash
# Install Xcode from .xip archive (NOT from Mac App Store)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

XCODE_INSTALL_DIR="/Applications"
XCODE_NAMING_PATTERN="Xcode_{version}.app"

find_xcode_xip() {
  local explicit_path="${1:-}"

  if [[ -n "$explicit_path" ]]; then
    local expanded
    expanded="$(expand_path "$explicit_path")"
    if [[ -f "$expanded" ]]; then
      echo "$expanded"
      return 0
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry_run_stderr "Xcode archive not present (dry-run): ${expanded}"
      echo "$expanded"
      return 0
    fi
    die "Xcode archive not found at: ${expanded}"
  fi

  local search_paths
  search_paths="$(yaml_get_value "${CONFIG_DIR}/xcode.yaml" "xcode.default_xip_search_paths")"

  local paths=()
  if [[ -n "$search_paths" ]]; then
    while IFS= read -r line; do
      paths+=("$(expand_path "$line")")
    done < <(echo "$search_paths" | ruby -ryaml -e 'YAML.load(STDIN.read).each { |p| puts p }' 2>/dev/null || true)
  fi

  paths+=("$(expand_path ~/Downloads)" "$(expand_path ~/Desktop)")

  local glob_pattern
  glob_pattern="$(yaml_get_value "${CONFIG_DIR}/xcode.yaml" "xcode.xip_glob")"
  glob_pattern="${glob_pattern:-Xcode_*.xip}"

  local found=""
  for dir in "${paths[@]}"; do
    [[ -d "$dir" ]] || continue
    local match
    match="$(find "$dir" -maxdepth 1 -name "$glob_pattern" -type f 2>/dev/null | sort -V | tail -1)"
    if [[ -n "$match" ]]; then
      found="$match"
      break
    fi
  done

  if [[ -z "$found" ]]; then
    die "No Xcode .xip archive found. Use --xcode-path to specify the archive location."
  fi

  echo "$found"
}

extract_version_from_xip() {
  local xip_path="$1"
  local basename_xip
  basename_xip="$(basename "$xip_path" .xip)"

  # Match patterns: Xcode_26.0, Xcode-26.0, Xcode26.0
  if [[ "$basename_xip" =~ ([0-9]+(\.[0-9]+)+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  die "Could not determine Xcode version from archive name: ${basename_xip}"
}

extract_version_from_app() {
  local app_path="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "0.0.0"
    return 0
  fi

  local version
  version="$("$app_path/Contents/Developer/usr/bin/xcodebuild" -version 2>/dev/null | head -1 | awk '{print $2}')"
  if [[ -n "$version" ]]; then
    echo "$version"
    return 0
  fi

  die "Could not read Xcode version from ${app_path}"
}

extract_xip() {
  local xip_path="$1"
  local extract_dir
  extract_dir="$(dirname "$xip_path")"

  log_info_stderr "Extracting ${xip_path} (this may take a while)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run_stderr "Would extract: ${xip_path}"
    echo "${extract_dir}/Xcode.app"
    return 0
  fi

  local timeout
  timeout="$(yaml_get_value "${CONFIG_DIR}/xcode.yaml" "xcode.extract_timeout_seconds")"
  timeout="${timeout:-3600}"

  if ! xip -x "$xip_path"; then
    die "Failed to extract Xcode archive: ${xip_path}"
  fi

  local extracted_app="${extract_dir}/Xcode.app"
  if [[ ! -d "$extracted_app" ]]; then
    die "Expected Xcode.app not found after extraction in ${extract_dir}"
  fi

  echo "$extracted_app"
}

install_xcode() {
  local xip_path="${1:-}"

  log_section "Installing Xcode from Archive"

  XCODE_INSTALL_DIR="$(yaml_get_value "${CONFIG_DIR}/xcode.yaml" "xcode.install_directory")"
  XCODE_INSTALL_DIR="${XCODE_INSTALL_DIR:-/Applications}"
  XCODE_NAMING_PATTERN="$(yaml_get_value "${CONFIG_DIR}/xcode.yaml" "xcode.naming_pattern")"
  XCODE_NAMING_PATTERN="${XCODE_NAMING_PATTERN:-Xcode_{version}.app}"

  local resolved_xip
  resolved_xip="$(find_xcode_xip "$xip_path")"
  log_info "Using Xcode archive: ${resolved_xip}"

  local version
  version="$(extract_version_from_xip "$resolved_xip")"
  version="${version//$'\n'/}"
  log_info "Detected Xcode version: ${version}"

  local target_name="Xcode_${version}.app"
  local install_dir="${XCODE_INSTALL_DIR//$'\n'/}"
  local target_path="${install_dir}/${target_name}"

  if [[ -d "$target_path" ]]; then
    log_info "Xcode ${version} already installed at ${target_path}"
    if ! confirm "Xcode ${version} already exists. Reconfigure active developer directory?"; then
      log_warn "Skipping Xcode installation"
      return 0
    fi
  else
    local extracted_app
    extracted_app="$(extract_xip "$resolved_xip")"

    if [[ "$DRY_RUN" != "true" ]]; then
      if [[ -d "$target_path" ]]; then
        if ! confirm "Overwrite existing ${target_name}?"; then
          die "Installation aborted by user"
        fi
        run_cmd rm -rf "$target_path"
      fi

      log_info "Moving Xcode to ${target_path}..."
      run_sudo mv "$extracted_app" "$target_path"
      run_sudo xattr -cr "$target_path" 2>/dev/null || true
      log_success "Xcode moved to ${target_path}"
    else
      log_dry_run "Would move ${extracted_app} to ${target_path}"
    fi
  fi

  configure_xcode "$target_path"
  install_command_line_tools "$target_path"
  verify_xcode_installation "$target_path" "$version"
}

command_line_tools_available() {
  xcode-select -p &>/dev/null
}

standalone_clt_installed() {
  pkgutil --pkg-info=com.apple.pkg.CLTools_Executables &>/dev/null
}

resolve_xcodebuild() {
  local app_path="${1:-}"
  if [[ -n "$app_path" ]] && [[ -x "${app_path}/Contents/Developer/usr/bin/xcodebuild" ]]; then
    echo "${app_path}/Contents/Developer/usr/bin/xcodebuild"
  elif command -v xcodebuild >/dev/null 2>&1; then
    command -v xcodebuild
  else
    echo ""
  fi
}

accept_xcode_licenses() {
  local app_path="${1:-}"
  local xcodebuild_cmd
  xcodebuild_cmd="$(resolve_xcodebuild "$app_path")"

  if [[ -z "$xcodebuild_cmd" ]]; then
    log_warn "xcodebuild not found; cannot accept license automatically"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run: sudo ${xcodebuild_cmd} -license accept"
    return 0
  fi

  log_info "Accepting Xcode / Command Line Tools license..."
  if run_sudo "$xcodebuild_cmd" -license accept; then
    log_success "License agreement accepted"
    return 0
  fi

  log_warn "Could not accept license with ${xcodebuild_cmd}; trying default xcodebuild"
  if run_sudo xcodebuild -license accept; then
    log_success "License agreement accepted"
    return 0
  fi

  log_warn "Automatic license acceptance failed. Run manually: sudo xcodebuild -license accept"
  return 1
}

wait_for_command_line_tools() {
  local timeout
  timeout="$(yaml_get_value "${CONFIG_DIR}/xcode.yaml" "xcode.command_line_tools_timeout_seconds")"
  timeout="${timeout:-1800}"

  local waited=0
  local interval=15

  while ! command_line_tools_available; do
    if [[ "$waited" -ge "$timeout" ]]; then
      log_error "Timed out after ${timeout}s waiting for Command Line Tools"
      return 1
    fi
    log_info "Waiting for Command Line Tools... (${waited}s / ${timeout}s)"
    sleep "$interval"
    waited=$((waited + interval))
  done

  log_success "Command Line Tools are available at: $(xcode-select -p)"
  return 0
}

install_clt_headless() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would install Command Line Tools via softwareupdate"
    return 0
  fi

  log_info "Attempting headless Command Line Tools installation..."

  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  local clt_label
  clt_label="$(softwareupdate -l 2>/dev/null | grep -E '\* .*Command Line Tools' | tail -1 | sed 's/^[[:space:]]*\*[[:space:]]*//' || true)"

  if [[ -z "$clt_label" ]]; then
    log_warn "Command Line Tools package not found via softwareupdate"
    return 1
  fi

  log_info "Installing package: ${clt_label}"
  if run_sudo softwareupdate -i "$clt_label" --verbose; then
    log_success "Command Line Tools installed via softwareupdate"
    return 0
  fi

  return 1
}

install_command_line_tools() {
  local app_path="${1:-}"

  log_section "Installing Xcode Command Line Tools"

  local install_clt
  install_clt="$(yaml_get_value "${CONFIG_DIR}/xcode.yaml" "xcode.install_command_line_tools")"
  if [[ "$install_clt" == "false" ]]; then
    log_info "Command Line Tools installation disabled in config"
    accept_xcode_licenses "$app_path" || true
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run: xcode-select --install"
    log_dry_run "Would wait for Command Line Tools to become available"
    accept_xcode_licenses "$app_path"
    return 0
  fi

  if command_line_tools_available; then
    log_info "Developer tools already available: $(xcode-select -p)"
  else
    local use_headless
    use_headless="$(yaml_get_value "${CONFIG_DIR}/xcode.yaml" "xcode.use_headless_clt_install")"

    if [[ "$NONINTERACTIVE" == "true" ]] || [[ "$use_headless" == "true" ]]; then
      install_clt_headless || log_warn "Headless install unavailable; falling back to xcode-select --install"
    fi

    if ! command_line_tools_available; then
      log_info "Running: xcode-select --install"
      log_warn "A system dialog may appear — confirm the installation if prompted"
      xcode-select --install 2>/dev/null || true
      wait_for_command_line_tools || {
        log_error "Command Line Tools installation failed or timed out"
        return 1
      }
    fi
  fi

  accept_xcode_licenses "$app_path" || true

  if [[ -n "$app_path" ]] && [[ -d "${app_path}/Contents/Developer" ]]; then
    log_info "Ensuring active developer directory points to installed Xcode..."
    run_sudo xcode-select -s "${app_path}/Contents/Developer"
    log_success "Active developer directory: ${app_path}/Contents/Developer"
  fi

  if standalone_clt_installed; then
    log_success "Standalone Command Line Tools package detected"
  fi
}

configure_xcode() {
  local app_path="$1"

  log_info "Configuring active developer directory..."

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run: sudo xcode-select -s ${app_path}/Contents/Developer"
    accept_xcode_licenses "$app_path"
    log_dry_run "Would run: sudo xcodebuild -runFirstLaunch"
    return 0
  fi

  run_sudo xcode-select -s "${app_path}/Contents/Developer"
  log_success "Active developer directory set to ${app_path}/Contents/Developer"

  accept_xcode_licenses "$app_path" || true

  log_info "Running Xcode first-launch tasks..."
  local xcodebuild_cmd
  xcodebuild_cmd="$(resolve_xcodebuild "$app_path")"
  if [[ -n "$xcodebuild_cmd" ]]; then
    run_sudo "$xcodebuild_cmd" -runFirstLaunch 2>/dev/null || true
  else
    run_sudo xcodebuild -runFirstLaunch 2>/dev/null || true
  fi
  log_success "Xcode first-launch tasks completed"
}

verify_xcode_installation() {
  local app_path="$1"
  local expected_version="$2"

  log_section "Xcode Validation Report"

  local status_ok=0

  if [[ -d "$app_path" ]]; then
    log_success "Application: ${app_path} exists"
  else
    log_error "Application: ${app_path} not found"
    status_ok=1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would verify xcodebuild -version"
    log_dry_run "Would verify xcode-select -p"
    return 0
  fi

  local installed_version
  installed_version="$(extract_version_from_app "$app_path")"
  if [[ "$installed_version" == "$expected_version" ]]; then
    log_success "Version: ${installed_version}"
  else
    log_warn "Version mismatch: expected ${expected_version}, found ${installed_version}"
  fi

  local dev_dir
  dev_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ "$dev_dir" == "${app_path}/Contents/Developer" ]]; then
    log_success "Active developer directory: ${dev_dir}"
  else
    log_warn "Active developer directory: ${dev_dir} (expected ${app_path}/Contents/Developer)"
    status_ok=1
  fi

  if command_line_tools_available; then
    log_success "Command Line Tools: available (${dev_dir})"
  else
    log_fail_msg="Command Line Tools not configured"
    log_error "$log_fail_msg"
    status_ok=1
  fi

  local xcodebuild_cmd
  xcodebuild_cmd="$(resolve_xcodebuild "$app_path")"
  if [[ -n "$xcodebuild_cmd" ]]; then
    if "$xcodebuild_cmd" -version &>/dev/null; then
      log_success "xcodebuild operational: $("$xcodebuild_cmd" -version 2>/dev/null | head -1)"
    else
      log_warn "xcodebuild found but not fully operational yet"
      status_ok=1
    fi
  fi

  log_info "Installed Xcode versions in ${XCODE_INSTALL_DIR}:"
  find "$XCODE_INSTALL_DIR" -maxdepth 1 -name 'Xcode_*.app' -type d 2>/dev/null | sort | while read -r xcode_app; do
    local ver
    ver="$(basename "$xcode_app" .app | sed 's/Xcode_//')"
    log_info "  - Xcode_${ver}.app"
  done

  return "$status_ok"
}

list_installed_xcode_versions() {
  find "${XCODE_INSTALL_DIR:-/Applications}" -maxdepth 1 -name 'Xcode_*.app' -type d 2>/dev/null | sort
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_xcode "${1:-}"
fi
