#!/usr/bin/env bash
# Ensure keyboard input sources from config/input_sources.yaml are enabled

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

keyboard_layout_enabled() {
  local layout_id="$1"

  ruby -e "
    id = ARGV[0].to_i
    out = \`defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null\`
    exit 1 if out.nil? || out.strip.empty?
    ids = out.scan(/\"KeyboardLayout ID\"\\s*=\\s*(\\d+);/).flatten
    ids += out.scan(/KeyboardLayout ID\\s*=\\s*(\\d+);/).flatten
    exit(ids.map(&:to_i).include?(id) ? 0 : 1)
  " "$layout_id"
}

add_keyboard_layout() {
  local layout_id="$1"
  local layout_name="$2"

  local plist_entry
  plist_entry="<dict><key>InputSourceKind</key><string>Keyboard Layout</string><key>KeyboardLayout ID</key><integer>${layout_id}</integer><key>KeyboardLayout Name</key><string>${layout_name}</string></dict>"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run: defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add '${plist_entry}'"
    return 0
  fi

  defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add "$plist_entry"
}

ensure_keyboard_layout() {
  local layout_id="$1"
  local layout_name="$2"

  log_info "Checking keyboard layout: ${layout_name} (ID ${layout_id})"

  if keyboard_layout_enabled "$layout_id"; then
    log_info "${layout_name} (ID ${layout_id}) already enabled"
    return 0
  fi

  log_info "Adding keyboard layout: ${layout_name} (ID ${layout_id})"
  add_keyboard_layout "$layout_id" "$layout_name"
  log_success "Added keyboard layout: ${layout_name} (ID ${layout_id})"
}

configure_input_sources() {
  log_section "Configuring Keyboard Input Sources"

  local sources_json
  sources_json="$(yaml_get_list "${CONFIG_DIR}/input_sources.yaml" "input_sources")"

  local count
  count="$(echo "$sources_json" | ruby -rjson -e 'puts JSON.parse(STDIN.read).length')"

  if [[ "$count" -eq 0 ]]; then
    log_warn "No input sources configured in input_sources.yaml"
    return 0
  fi

  echo "$sources_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |source|
      puts [source["id"], source["name"]].join("|")
    end
  ' | while IFS='|' read -r layout_id layout_name; do
    ensure_keyboard_layout "$layout_id" "$layout_name"
  done

  if [[ "$DRY_RUN" != "true" ]]; then
    log_info "Keyboard layout changes may require logout/login to appear in System Settings"
  fi

  log_success "Keyboard input sources configured"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  configure_input_sources
fi
