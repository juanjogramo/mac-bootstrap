#!/usr/bin/env bash
# Apply macOS system preferences from config/macos.yaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

apply_defaults_entry() {
  local key="$1"
  local domain="$2"
  local pref_key="$3"
  local value="$4"
  local type="$5"
  local handler="${6:-defaults}"

  log_info "Setting ${key}: ${domain} -> ${pref_key}"

  case "$handler" in
    sound_menu)
      apply_sound_menu "$domain" "$pref_key"
      ;;
    defaults)
      apply_standard_default "$domain" "$pref_key" "$value" "$type"
      ;;
    *)
      log_warn "Unknown handler '${handler}' for ${key}"
      ;;
  esac
}

apply_standard_default() {
  local domain="$1"
  local pref_key="$2"
  local value="$3"
  local type="$4"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run: defaults write ${domain} ${pref_key} -${type} ${value}"
    return 0
  fi

  case "$type" in
    string)
      defaults write "$domain" "$pref_key" -string "$value"
      ;;
    bool)
      if [[ "$value" == "true" ]]; then
        defaults write "$domain" "$pref_key" -bool true
      else
        defaults write "$domain" "$pref_key" -bool false
      fi
      ;;
    int)
      defaults write "$domain" "$pref_key" -int "$value"
      ;;
    float)
      defaults write "$domain" "$pref_key" -float "$value"
      ;;
    *)
      defaults write "$domain" "$pref_key" "$value"
      ;;
  esac
}

apply_sound_menu() {
  local domain="$1"
  local pref_key="$2"

  # Enable volume menu extra in Control Center / menu bar
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would enable sound icon in menu bar"
    return 0
  fi

  # Modern macOS uses Control Center; enable sound in menu bar via defaults
  defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool true 2>/dev/null || true
  defaults write com.apple.systemuiserver menuExtras -array-add "/System/Library/CoreServices/Menu Extras/Volume.menu" 2>/dev/null || true
}

apply_menu_bar_username() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would enable username in menu bar via System Settings"
    return 0
  fi

  # Enable fast user switching / show username in menu bar
  defaults write /Library/Preferences/.GlobalPreferences MultipleSessionEnabled -bool true 2>/dev/null || true
  log_info "Username display may require enabling in System Settings > Control Center > Fast User Switching"
}

restart_affected_services() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would restart Dock and SystemUIServer"
    return 0
  fi

  log_info "Restarting affected services..."
  killall Dock 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true
  killall ControlCenter 2>/dev/null || true
}

configure_macos_preferences() {
  log_section "Configuring macOS Preferences"

  local prefs_json
  prefs_json="$(ruby -ryaml -rjson -e "
    data = YAML.load_file('${CONFIG_DIR}/macos.yaml')
    puts (data['preferences'] || {}).to_json
  ")"

  echo "$prefs_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |key, pref|
      puts [key, pref["domain"], pref["key"], pref["value"], pref["type"], pref["handler"] || "defaults"].join("|")
    end
  ' | while IFS='|' read -r key domain pref_key value type handler; do
    apply_defaults_entry "$key" "$domain" "$pref_key" "$value" "$type" "$handler"
  done

  apply_menu_bar_username
  restart_affected_services

  log_success "macOS preferences configured"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  configure_macos_preferences
fi
