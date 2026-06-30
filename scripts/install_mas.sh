#!/usr/bin/env bash
# Install Mac App Store applications via mas

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

install_mas() {
  log_section "Installing Mac App Store Applications"

  if ! command_exists mas; then
    log_warn "mas not found. Installing mas via Homebrew..."
    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry_run "Would install mas"
    elif command_exists brew; then
      brew install mas
    else
      die "Homebrew is required to install mas."
    fi
  fi

  local mas_json
  mas_json="$(yaml_get_list "${CONFIG_DIR}/mas.yaml" "mas_apps")"

  local count
  count="$(echo "$mas_json" | ruby -rjson -e 'puts JSON.parse(STDIN.read).length')"

  if [[ "$count" -eq 0 ]]; then
    log_warn "No Mac App Store apps configured in mas.yaml"
    return 0
  fi

  echo "$mas_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |app|
      puts [app["name"], app["id"]].join("|")
    end
  ' | while IFS='|' read -r name app_id; do
    install_single_mas "$name" "$app_id"
  done

  log_success "Mac App Store installation complete"
}

install_single_mas() {
  local name="$1"
  local app_id="$2"

  log_info "Processing MAS: ${name} (${app_id})"

  if app_installed_mas "$app_id"; then
    log_info "${name} already installed via Mac App Store"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would install MAS app: ${name} (id: ${app_id})"
    return 0
  fi

  log_warn "MAS apps require you to be signed into the Mac App Store"
  log_info "Installing ${name}..."

  if mas install "$app_id"; then
    log_success "Installed ${name}"
  else
    log_error "Failed to install ${name}. Ensure you are signed into the Mac App Store."
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_mas
fi
