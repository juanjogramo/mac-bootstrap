#!/usr/bin/env bash
# Install Homebrew package manager

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

install_homebrew() {
  log_section "Installing Homebrew"

  if command_exists brew; then
    log_info "Homebrew already installed at $(command -v brew)"
    if [[ "$DRY_RUN" != "true" ]]; then
      log_info "Updating Homebrew..."
      run_cmd brew update
    fi
    return 0
  fi

  log_info "Homebrew not found. Installing..."
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would install Homebrew from https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    return 0
  fi

  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon and Intel
  local brew_shellenv
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_shellenv='eval "$(/opt/homebrew/bin/brew shellenv)"'
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_shellenv='eval "$(/usr/local/bin/brew shellenv)"'
  else
    die "Homebrew installation completed but brew binary not found"
  fi

  for rcfile in "${HOME}/.zprofile" "${HOME}/.zshrc" "${HOME}/.bash_profile"; do
    if [[ -f "$rcfile" ]] && ! grep -q 'brew shellenv' "$rcfile" 2>/dev/null; then
      {
        echo ""
        echo "# Homebrew"
        echo "$brew_shellenv"
      } >>"$rcfile"
      log_info "Added Homebrew to ${rcfile}"
    fi
  done

  eval "$brew_shellenv"
  log_success "Homebrew installed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_homebrew
fi
