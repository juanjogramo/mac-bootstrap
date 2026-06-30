#!/usr/bin/env bash
# mac-bootstrap installer — curl | bash friendly
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/juanjogramo/mac-bootstrap/main/install.sh)"

set -euo pipefail

# Repository settings (override with env vars)
MAC_BOOTSTRAP_REPO="${MAC_BOOTSTRAP_REPO:-juanjogramo/mac-bootstrap}"
MAC_BOOTSTRAP_BRANCH="${MAC_BOOTSTRAP_BRANCH:-main}"
MAC_BOOTSTRAP_HOME="${MAC_BOOTSTRAP_HOME:-${HOME}/.mac-bootstrap}"
MAC_BOOTSTRAP_PROFILE="${MAC_BOOTSTRAP_PROFILE:-personal}"
MAC_BOOTSTRAP_SKIP_RUN="${MAC_BOOTSTRAP_SKIP_RUN:-0}"
MAC_BOOTSTRAP_DRY_RUN="${MAC_BOOTSTRAP_DRY_RUN:-0}"
MAC_BOOTSTRAP_NONINTERACTIVE="${MAC_BOOTSTRAP_NONINTERACTIVE:-0}"

INSTALL_REPO_URL="${MAC_BOOTSTRAP_GIT_URL:-https://github.com/${MAC_BOOTSTRAP_REPO}.git}"
INSTALL_ARCHIVE_URL="https://github.com/${MAC_BOOTSTRAP_REPO}/archive/refs/heads/${MAC_BOOTSTRAP_BRANCH}.tar.gz"

detect_local_checkout() {
  local script_path=""

  if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "-" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_path}/bootstrap.sh" ]]; then
      MAC_BOOTSTRAP_HOME="${script_path}"
      export MAC_BOOTSTRAP_HOME
      info "Using local checkout at ${MAC_BOOTSTRAP_HOME}"
      return 0
    fi
  fi

  return 1
}

abort() {
  printf '\033[0;31mError:\033[0m %s\n' "$1" >&2
  exit 1
}

info() {
  printf '==> %s\n' "$1"
}

success() {
  printf '\033[0;32m==>\033[0m %s\n' "$1"
}

warn() {
  printf '\033[0;33mWarning:\033[0m %s\n' "$1"
}

check_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    abort "mac-bootstrap only supports macOS."
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_or_update_repo() {
  local tmp_dir archive_root

  if [[ -f "${MAC_BOOTSTRAP_HOME}/bootstrap.sh" ]]; then
    info "Updating existing installation at ${MAC_BOOTSTRAP_HOME}..."
    if [[ -d "${MAC_BOOTSTRAP_HOME}/.git" ]] && command_exists git; then
      git -C "${MAC_BOOTSTRAP_HOME}" fetch origin "${MAC_BOOTSTRAP_BRANCH}" --quiet
      git -C "${MAC_BOOTSTRAP_HOME}" reset --hard "origin/${MAC_BOOTSTRAP_BRANCH}" --quiet
      success "Updated via git"
      return 0
    fi
    warn "Existing install is not a git repo; re-downloading..."
    rm -rf "${MAC_BOOTSTRAP_HOME}"
  fi

  mkdir -p "$(dirname "${MAC_BOOTSTRAP_HOME}")"

  if command_exists git; then
    info "Cloning ${MAC_BOOTSTRAP_REPO} to ${MAC_BOOTSTRAP_HOME}..."
    git clone --depth 1 --branch "${MAC_BOOTSTRAP_BRANCH}" "${INSTALL_REPO_URL}" "${MAC_BOOTSTRAP_HOME}"
    success "Cloned repository"
    return 0
  fi

  info "Downloading ${MAC_BOOTSTRAP_REPO} (git not found)..."
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT

  curl -fsSL "${INSTALL_ARCHIVE_URL}" -o "${tmp_dir}/mac-bootstrap.tar.gz" || abort "$(cat <<EOF
Could not download ${MAC_BOOTSTRAP_REPO}.

The curl one-liner requires a public GitHub repository.
Your repo appears to be private (raw.githubusercontent.com returns 404).

Use one of these instead:

  git clone git@github.com:${MAC_BOOTSTRAP_REPO}.git ~/.mac-bootstrap && bash ~/.mac-bootstrap/install.sh

Or make the repository public:
  https://github.com/${MAC_BOOTSTRAP_REPO}/settings
EOF
)"
  tar -xzf "${tmp_dir}/mac-bootstrap.tar.gz" -C "${tmp_dir}"

  archive_root="${tmp_dir}/mac-bootstrap-${MAC_BOOTSTRAP_BRANCH}"
  if [[ ! -d "${archive_root}" ]]; then
    abort "Downloaded archive is missing expected directory: mac-bootstrap-${MAC_BOOTSTRAP_BRANCH}"
  fi

  mv "${archive_root}" "${MAC_BOOTSTRAP_HOME}"
  success "Downloaded and installed to ${MAC_BOOTSTRAP_HOME}"
}

make_executable() {
  chmod +x "${MAC_BOOTSTRAP_HOME}/bootstrap.sh" \
    "${MAC_BOOTSTRAP_HOME}/install.sh" \
    "${MAC_BOOTSTRAP_HOME}/bin/mac-bootstrap" \
    "${MAC_BOOTSTRAP_HOME}/scripts/"*.sh \
    "${MAC_BOOTSTRAP_HOME}/tests/run_tests.sh" 2>/dev/null || true
}

add_to_path() {
  local line='export PATH="${HOME}/.mac-bootstrap/bin:${PATH}"'
  local marker="# mac-bootstrap"
  local updated=false

  if [[ "${MAC_BOOTSTRAP_HOME}" != "${HOME}/.mac-bootstrap" ]]; then
    line="export PATH=\"${MAC_BOOTSTRAP_HOME}/bin:\${PATH}\""
  fi

  for rcfile in "${HOME}/.zprofile" "${HOME}/.zshrc" "${HOME}/.bash_profile"; do
    if [[ -f "${rcfile}" ]] && grep -q 'mac-bootstrap/bin' "${rcfile}" 2>/dev/null; then
      continue
    fi
    if [[ -f "${rcfile}" ]] || [[ "${rcfile}" == "${HOME}/.zprofile" ]]; then
      {
        echo ""
        echo "${marker}"
        echo "${line}"
      } >>"${rcfile}"
      info "Added mac-bootstrap to PATH in ${rcfile}"
      updated=true
    fi
  done

  if [[ "$updated" == "false" ]]; then
    {
      echo ""
      echo "${marker}"
      echo "${line}"
    } >>"${HOME}/.zprofile"
    info "Added mac-bootstrap to PATH in ${HOME}/.zprofile"
  fi

  export PATH="${MAC_BOOTSTRAP_HOME}/bin:${PATH}"
}

run_bootstrap() {
  if [[ "${MAC_BOOTSTRAP_SKIP_RUN}" == "1" ]]; then
    info "Skipping bootstrap run (MAC_BOOTSTRAP_SKIP_RUN=1)"
    return 0
  fi

  local args=(--profile "${MAC_BOOTSTRAP_PROFILE}")

  if [[ "${MAC_BOOTSTRAP_DRY_RUN}" == "1" ]]; then
    args+=(--dry-run)
  fi

  if [[ "${MAC_BOOTSTRAP_NONINTERACTIVE}" == "1" ]]; then
    args+=(--noninteractive)
  fi

  info "Running mac-bootstrap ${args[*]}..."
  "${MAC_BOOTSTRAP_HOME}/bootstrap.sh" "${args[@]}"
}

print_next_steps() {
  cat <<EOF

mac-bootstrap is installed at: ${MAC_BOOTSTRAP_HOME}

Run from anywhere (after restarting your terminal):

  mac-bootstrap --profile personal
  mac-bootstrap --dry-run --profile personal
  mac-bootstrap --validate

Or use the full path:

  ${MAC_BOOTSTRAP_HOME}/bootstrap.sh --profile personal

Environment variables:
  MAC_BOOTSTRAP_HOME          Install location (default: ~/.mac-bootstrap)
  MAC_BOOTSTRAP_PROFILE       Profile name (default: personal)
  MAC_BOOTSTRAP_SKIP_RUN=1    Install only, do not run bootstrap
  MAC_BOOTSTRAP_DRY_RUN=1     Preview changes during install
  MAC_BOOTSTRAP_NONINTERACTIVE=1  Non-interactive mode

EOF
}

main() {
  check_macos

  printf '\n'
  printf '  \033[1mmac-bootstrap\033[0m — Infrastructure as Code for macOS\n'
  printf '\n'

  if detect_local_checkout; then
    :
  else
    install_or_update_repo
  fi

  make_executable
  add_to_path
  run_bootstrap
  print_next_steps

  success "Installation complete!"
}

main "$@"
