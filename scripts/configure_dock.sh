#!/usr/bin/env bash
# Configure Dock items via dockutil (config/dock.yaml)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

resolve_xcode_app_path() {
  if [[ -d "/Applications/Xcode.app" ]]; then
    echo "/Applications/Xcode.app"
    return 0
  fi

  local xcode_app
  xcode_app="$(find /Applications -maxdepth 1 -name 'Xcode_*.app' -type d 2>/dev/null | sort | tail -1)"
  if [[ -n "$xcode_app" ]]; then
    echo "$xcode_app"
    return 0
  fi

  return 1
}

resolve_dock_add_path() {
  local path="$1"
  local special="${2:-}"

  if [[ "$special" == "xcode" ]]; then
    resolve_xcode_app_path
    return $?
  fi

  echo "$path"
}

dock_item_present() {
  local label="$1"

  if ! command_exists dockutil; then
    return 1
  fi

  dockutil --find "$label" &>/dev/null
}

dock_app_in_dock() {
  local app_path="$1"

  if ! command_exists dockutil; then
    return 1
  fi

  dockutil --find "$app_path" &>/dev/null
}

remove_dock_item() {
  local label="$1"

  log_info "Removing from Dock: ${label}"

  if ! dock_item_present "$label"; then
    log_info "${label} not in Dock — skipping"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run: dockutil --remove '${label}' --no-restart"
    return 0
  fi

  dockutil --remove "$label" --no-restart
  log_success "Removed ${label} from Dock"
}

add_dock_app() {
  local app_path="$1"

  log_info "Adding to Dock: ${app_path}"

  if [[ ! -d "$app_path" ]]; then
    log_warn "Application not found — skipping Dock add: ${app_path}"
    return 0
  fi

  if dock_app_in_dock "$app_path"; then
    log_info "${app_path} already in Dock — skipping"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run: dockutil --add '${app_path}' --no-restart"
    return 0
  fi

  dockutil --add "$app_path" --no-restart
  log_success "Added ${app_path} to Dock"
}

restart_dock() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would restart Dock"
    return 0
  fi

  killall Dock 2>/dev/null || true
}

configure_dock() {
  log_section "Configuring Dock"

  if ! command_exists dockutil; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry_run "dockutil not installed — previewing Dock changes from config"
    else
      log_warn "dockutil not installed — enable the cli module and re-run bootstrap"
      return 1
    fi
  fi

  local remove_json add_json
  remove_json="$(yaml_get_list "${CONFIG_DIR}/dock.yaml" "dock_remove")"
  add_json="$(yaml_get_list "${CONFIG_DIR}/dock.yaml" "dock_add")"

  echo "$remove_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each { |label| puts label }
  ' | while IFS= read -r label; do
    [[ -n "$label" ]] || continue
    remove_dock_item "$label"
  done

  echo "$add_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |item|
      if item["special"]
        puts ["", item["special"]].join("|")
      else
        puts [item["path"], ""].join("|")
      end
    end
  ' | while IFS='|' read -r app_path special; do
    local resolved_path
    if ! resolved_path="$(resolve_dock_add_path "$app_path" "$special")"; then
      if [[ "$special" == "xcode" ]]; then
        log_warn "Xcode not found in /Applications — skipping Dock add"
      else
        log_warn "Could not resolve Dock add path — skipping"
      fi
      continue
    fi
    add_dock_app "$resolved_path"
  done

  restart_dock
  log_success "Dock configured"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  configure_dock
fi
