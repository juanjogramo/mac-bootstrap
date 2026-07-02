#!/usr/bin/env bash
# Uninstall mac-bootstrap tooling (keeps apps, Homebrew, and preferences)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

SHELL_RC_FILES=(
  "${HOME}/.zprofile"
  "${HOME}/.zshrc"
  "${HOME}/.bash_profile"
)

DEFAULT_INSTALL_HOME="${HOME}/.mac-bootstrap"

discover_install_homes() {
  local homes=()
  local rcfile line path home

  if [[ -n "${MAC_BOOTSTRAP_HOME:-}" ]] && [[ -d "${MAC_BOOTSTRAP_HOME}" ]]; then
    homes+=("${MAC_BOOTSTRAP_HOME}")
  fi

  if [[ -d "${DEFAULT_INSTALL_HOME}" ]]; then
    homes+=("${DEFAULT_INSTALL_HOME}")
  fi

  for rcfile in "${SHELL_RC_FILES[@]}"; do
    [[ -f "${rcfile}" ]] || continue
    while IFS= read -r line; do
      [[ "$line" == *mac-bootstrap/bin* ]] || continue
      path="$(echo "$line" | sed -E 's#.*"([^"]*mac-bootstrap)/bin.*#\1#; t; s#.*([^ "]+/mac-bootstrap)/bin.*#\1#')"
      if [[ -n "$path" ]] && [[ -d "$path" ]]; then
        homes+=("$path")
      fi
    done < <(grep 'mac-bootstrap/bin' "${rcfile}" 2>/dev/null || true)
  done

  if [[ ${#homes[@]} -eq 0 ]]; then
    return 0
  fi

  printf '%s\n' "${homes[@]}" | sort -u
}

remove_shell_config_entries() {
  local rcfile="$1"

  [[ -f "${rcfile}" ]] || return 0

  if [[ "$DRY_RUN" == "true" ]]; then
    if grep -q 'mac-bootstrap' "${rcfile}" 2>/dev/null; then
      log_dry_run "Would remove mac-bootstrap entries from ${rcfile}"
    fi
    return 0
  fi

  if ! grep -q 'mac-bootstrap' "${rcfile}" 2>/dev/null; then
    return 0
  fi

  ruby - "${rcfile}" <<'RUBY'
rcfile = ARGV[0]
lines = File.readlines(rcfile)
output = []
index = 0

while index < lines.length
  line = lines[index]

  if line.include?('mac-bootstrap')
    index += 1
    next
  end

  if line.strip.empty? && index + 1 < lines.length && lines[index + 1].include?('mac-bootstrap')
    index += 1
    next
  end

  output << line
  index += 1
end

while output.last&.strip&.empty?
  output.pop
end

File.write(rcfile, output.join)
RUBY

  log_success "Removed mac-bootstrap entries from ${rcfile}"
}

remove_install_directory() {
  local install_home="$1"

  [[ -d "${install_home}" ]] || return 0

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would remove directory: ${install_home}"
    return 0
  fi

  if [[ "${PWD}/" == "${install_home}/"* ]]; then
    cd "${HOME}" || cd /
  fi

  rm -rf "${install_home}"
  log_success "Removed ${install_home}"
}

print_uninstall_summary() {
  log_section "Uninstall Summary"

  cat <<EOF

mac-bootstrap tooling has been removed.

Kept on your Mac (not removed):
  - Homebrew and installed formulae/casks
  - Mac App Store applications
  - Oh My Zsh
  - macOS preference changes
  - Xcode installations

To reinstall mac-bootstrap later:
  git clone git@github.com:juanjogramo/mac-bootstrap.git ~/.mac-bootstrap && bash ~/.mac-bootstrap/install.sh

EOF
}

run_uninstall() {
  local install_home="${1:-}"
  local install_homes=()
  local home

  log_section "Uninstalling mac-bootstrap"

  log_info "This removes mac-bootstrap only. Installed apps and tools are kept."

  if [[ -n "${install_home}" ]]; then
    install_home="$(expand_path "${install_home}")"
    if [[ ! -d "${install_home}" ]]; then
      log_warn "Install directory not found: ${install_home}"
    else
      install_homes+=("${install_home}")
    fi
  else
    while IFS= read -r home; do
      [[ -n "$home" ]] || continue
      install_homes+=("$home")
    done < <(discover_install_homes)
  fi

  if [[ ${#install_homes[@]} -eq 0 ]]; then
    log_warn "No mac-bootstrap installation directories found"
  else
    log_info "Directories to remove:"
    for home in "${install_homes[@]}"; do
      log_info "  - ${home}"
    done
  fi

  if [[ "$DRY_RUN" != "true" ]] && [[ "$FORCE" != "true" ]] && [[ "$NONINTERACTIVE" != "true" ]]; then
    if ! confirm "Remove mac-bootstrap tooling (apps and tools will be kept)?"; then
      log_info "Uninstall cancelled"
      return 0
    fi
  fi

  for rcfile in "${SHELL_RC_FILES[@]}"; do
    remove_shell_config_entries "${rcfile}"
  done

  if [[ ${#install_homes[@]} -gt 0 ]]; then
    for home in "${install_homes[@]}"; do
      remove_install_directory "${home}"
    done
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "[DRY-RUN] Uninstall preview complete"
    return 0
  fi

  print_uninstall_summary
  log_success "mac-bootstrap uninstalled"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_uninstall "${1:-}"
fi
