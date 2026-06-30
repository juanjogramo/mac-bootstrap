#!/usr/bin/env bash
# Install Homebrew package manager

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

run_homebrew_installer() {
  local installer_cmd=()

  if [[ "$NONINTERACTIVE" == "true" ]]; then
    installer_cmd=(env NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "${HOMEBREW_INSTALL_URL}")")
  else
    installer_cmd=(/bin/bash -c "$(curl -fsSL "${HOMEBREW_INSTALL_URL}")")
  fi

  "${installer_cmd[@]}"
}

configure_homebrew_path() {
  local brew_shellenv=""

  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_shellenv='eval "$(/opt/homebrew/bin/brew shellenv)"'
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_shellenv='eval "$(/usr/local/bin/brew shellenv)"'
  else
    return 1
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

  # shellcheck disable=SC1090
  eval "$brew_shellenv"
  return 0
}

install_homebrew() {
  log_section "Installing Homebrew"

  if command_exists brew; then
    log_info "Homebrew already installed at $(command -v brew)"
    if [[ "$DRY_RUN" != "true" ]]; then
      log_info "Updating Homebrew..."
      run_cmd brew update || log_warn "Homebrew update failed; continuing"
    fi
    return 0
  fi

  log_info "Homebrew not found. Installing..."
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would install Homebrew from ${HOMEBREW_INSTALL_URL}"
    return 0
  fi

  ensure_sudo || log_warn "Administrator access not pre-authorized; Homebrew installer will prompt if needed"

  local attempt=1
  local max_attempts=3
  local install_ok=false

  while [[ "$attempt" -le "$max_attempts" ]]; do
    log_info "Running Homebrew installer (attempt ${attempt}/${max_attempts})..."

    if run_homebrew_installer; then
      install_ok=true
      break
    fi

    log_warn "Homebrew installation failed on attempt ${attempt}/${max_attempts}"

    if [[ "$attempt" -lt "$max_attempts" ]]; then
      log_info "Re-authenticating and retrying..."
      sudo -k 2>/dev/null || true
      ensure_sudo || log_warn "Could not refresh administrator privileges"
    fi

    attempt=$((attempt + 1))
  done

  if [[ "$install_ok" != "true" ]]; then
    log_error "Homebrew installation failed after ${max_attempts} attempts."
    log_warn "Install Homebrew manually: /bin/bash -c \"\$(curl -fsSL ${HOMEBREW_INSTALL_URL})\""
    log_warn "Then re-run: mac-bootstrap --profile personal"
    return 1
  fi

  if ! configure_homebrew_path; then
    log_error "Homebrew installation completed but brew binary not found"
    return 1
  fi

  log_success "Homebrew installed successfully"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_homebrew
fi
