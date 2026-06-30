#!/usr/bin/env bash
# Install CLI tools from config/cli.yaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

install_cli() {
  log_section "Installing CLI Tools"

  if ! command_exists brew; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_dry_run "Homebrew not installed — would install Homebrew first"
    else
      log_warn "Homebrew is not available. Skipping CLI tool installation."
      log_warn "Re-run mac-bootstrap after Homebrew is installed."
      return 1
    fi
  fi

  install_oh_my_zsh

  local cli_json
  cli_json="$(yaml_get_list "${CONFIG_DIR}/cli.yaml" "cli")"

  echo "$cli_json" | ruby -rjson -e '
    JSON.parse(STDIN.read).each do |tool|
      puts [tool["name"], tool["formula"]].join("|")
    end
  ' | while IFS='|' read -r name formula; do
    install_single_cli "$name" "$formula"
  done

  log_success "CLI tool installation complete"
}

install_single_cli() {
  local name="$1"
  local formula="$2"

  log_info "Processing CLI: ${name} (${formula})"

  if command_exists brew && brew list "$formula" &>/dev/null; then
    log_info "${name} already installed"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would install formula: ${formula}"
    return 0
  fi

  if ! command_exists brew; then
    log_error "Homebrew required to install ${name}"
    return 1
  fi

  if brew install "$formula"; then
    log_success "Installed ${name}"
  else
    log_error "Failed to install ${name} (${formula})"
    return 1
  fi
}

install_oh_my_zsh() {
  log_info "Processing: Oh My Zsh"

  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    log_info "Oh My Zsh already installed"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would install Oh My Zsh"
    return 0
  fi

  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  log_success "Oh My Zsh installed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_cli
fi
