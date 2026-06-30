#!/usr/bin/env bash
# Install Homebrew Cask applications from config/apps.yaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

install_apps() {
  log_section "Installing Applications"

  if ! command_exists brew; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry_run "Homebrew not installed — would install applications after Homebrew setup"
    else
      die "Homebrew is required. Run install_homebrew first."
    fi
  fi

  local apps_json
  apps_json="$(yaml_get_list "${CONFIG_DIR}/apps.yaml" "apps")"

  local count
  count="$(echo "$apps_json" | ruby -rjson -e 'puts JSON.parse(STDIN.read).length')"

  if [[ "$count" -eq 0 ]]; then
    log_warn "No applications configured in apps.yaml"
    return 0
  fi

  echo "$apps_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |app|
      puts [app["name"], app["token"]].join("|")
    end
  ' | while IFS='|' read -r name token; do
    install_single_app "$name" "$token"
  done

  log_success "Application installation complete"
}

install_single_app() {
  local name="$1"
  local token="$2"

  log_info "Processing: ${name} (${token})"

  if command_exists brew && app_installed_cask "$token"; then
    log_info "${name} already installed via Homebrew cask"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would install cask: ${token}"
    return 0
  fi

  if ! command_exists brew; then
    log_error "Homebrew required to install ${name}"
    return 1
  fi

  if brew install --cask "$token"; then
    log_success "Installed ${name}"
  else
    log_error "Failed to install ${name} (${token})"
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_apps
fi
