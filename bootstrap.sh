#!/usr/bin/env bash
# mac-bootstrap — Infrastructure as Code for macOS
# Configure a fresh Mac with applications, tools, and preferences.
# Requires Bash 3.2+ (compatible with macOS default shell)

set -euo pipefail

BOOTSTRAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BOOTSTRAP_ROOT
export LOG_FILE="${BOOTSTRAP_ROOT}/logs/bootstrap.log"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"

# shellcheck source=scripts/logging.sh
source "${BOOTSTRAP_ROOT}/scripts/logging.sh"
# shellcheck source=scripts/helpers.sh
source "${BOOTSTRAP_ROOT}/scripts/helpers.sh"
# shellcheck source=scripts/install_homebrew.sh
source "${BOOTSTRAP_ROOT}/scripts/install_homebrew.sh"
# shellcheck source=scripts/install_apps.sh
source "${BOOTSTRAP_ROOT}/scripts/install_apps.sh"
# shellcheck source=scripts/install_cli.sh
source "${BOOTSTRAP_ROOT}/scripts/install_cli.sh"
# shellcheck source=scripts/install_mas.sh
source "${BOOTSTRAP_ROOT}/scripts/install_mas.sh"
# shellcheck source=scripts/install_xcode.sh
source "${BOOTSTRAP_ROOT}/scripts/install_xcode.sh"
# shellcheck source=scripts/macos_defaults.sh
source "${BOOTSTRAP_ROOT}/scripts/macos_defaults.sh"
# shellcheck source=scripts/validate.sh
source "${BOOTSTRAP_ROOT}/scripts/validate.sh"
# shellcheck source=scripts/add_item.sh
source "${BOOTSTRAP_ROOT}/scripts/add_item.sh"

VERSION="1.0.0"

usage() {
  cat <<EOF
mac-bootstrap v${VERSION} — Infrastructure as Code for macOS

USAGE:
  ./bootstrap.sh [OPTIONS]

OPTIONS:
  --profile NAME          Run bootstrap profile (e.g., personal)
  --dry-run               Show what would happen without making changes
  --validate              Validate current installation state
  --install-xcode         Install Xcode from .xip archive
  --xcode-path PATH       Path to Xcode .xip archive
  --add-app NAME          Add Homebrew cask application
    --token TOKEN         Cask token (required with --add-app)
  --add-cli NAME          Add CLI tool (formula name)
  --add-mas NAME          Add Mac App Store application
    --id ID               MAS app ID (required with --add-mas)
  --force                 Skip confirmation prompts
  --noninteractive        Non-interactive mode (implies --force)
  --log-level LEVEL       Set log level (DEBUG, INFO, WARN, ERROR)
  --version               Show version
  --help                  Show this help

EXAMPLES:
  ./bootstrap.sh --profile personal
  ./bootstrap.sh --profile personal --dry-run
  ./bootstrap.sh --validate
  ./bootstrap.sh --install-xcode
  ./bootstrap.sh --xcode-path ~/Downloads/Xcode_26.0.xip
  ./bootstrap.sh --add-app "Raycast" --token raycast
  ./bootstrap.sh --add-cli "wget"
  ./bootstrap.sh --add-mas "Things 3" --id 904280696

EOF
}

run_bootstrap_profile() {
  local profile="$1"
  BOOTSTRAP_FAILED_STEPS=()

  load_profile "$profile"
  log_section "Starting mac-bootstrap (profile: ${profile})"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "DRY-RUN MODE — no changes will be made"
  elif [[ "$NONINTERACTIVE" != "true" ]]; then
    ensure_sudo || log_warn "Continuing without cached administrator privileges"
  fi

  mkdir -p "${LOGS_DIR}"

  if profile_module_enabled "homebrew"; then
    run_bootstrap_step "homebrew" install_homebrew
  fi

  if profile_module_enabled "oh_my_zsh" || profile_module_enabled "cli"; then
    if profile_module_enabled "cli"; then
      run_bootstrap_step "cli" install_cli
    elif profile_module_enabled "oh_my_zsh"; then
      run_bootstrap_step "oh-my-zsh" install_oh_my_zsh
    fi
  fi

  if profile_module_enabled "apps"; then
    run_bootstrap_step "apps" install_apps
  fi

  if profile_module_enabled "mas"; then
    run_bootstrap_step "mas" install_mas
  fi

  if profile_module_enabled "macos_preferences"; then
    run_bootstrap_step "macos-preferences" configure_macos_preferences
  fi

  local profile_xcode
  profile_xcode="$(yaml_get_value "$PROFILE_FILE" "install_xcode")"
  if [[ "$profile_xcode" == "true" ]] || profile_module_enabled "xcode"; then
    local xcode_path_override
    xcode_path_override="$(yaml_get_value "$PROFILE_FILE" "xcode_path")"
    if [[ "$xcode_path_override" != "null" ]] && [[ -n "$xcode_path_override" ]]; then
      run_bootstrap_step "xcode" install_xcode "$xcode_path_override"
    else
      run_bootstrap_step "xcode" install_xcode ""
    fi
  fi

  log_section "Bootstrap Complete"

  if [[ "${#BOOTSTRAP_FAILED_STEPS[@]}" -gt 0 ]]; then
    log_warn "Completed with failed steps: ${BOOTSTRAP_FAILED_STEPS[*]}"
    log_warn "Fix the issues above and re-run: mac-bootstrap --profile ${profile}"
  else
    log_success "Profile '${profile}' finished successfully."
  fi

  log_info "Run 'mac-bootstrap --validate' to verify your installation."

  if [[ "$DRY_RUN" != "true" ]]; then
    run_validation || true
  fi
}

parse_args() {
  local profile=""
  local action="bootstrap"
  local xcode_path=""
  local add_app_name=""
  local add_app_token=""
  local add_cli_name=""
  local add_mas_name=""
  local add_mas_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        profile="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        export DRY_RUN
        shift
        ;;
      --validate)
        action="validate"
        shift
        ;;
      --install-xcode)
        action="install-xcode"
        shift
        ;;
      --xcode-path)
        xcode_path="$2"
        action="install-xcode"
        shift 2
        ;;
      --add-app)
        add_app_name="$2"
        action="add-app"
        shift 2
        ;;
      --token)
        add_app_token="$2"
        shift 2
        ;;
      --add-cli)
        add_cli_name="$2"
        action="add-cli"
        shift 2
        ;;
      --add-mas)
        add_mas_name="$2"
        action="add-mas"
        shift 2
        ;;
      --id)
        add_mas_id="$2"
        shift 2
        ;;
      --force)
        FORCE=true
        export FORCE
        shift
        ;;
      --noninteractive)
        NONINTERACTIVE=true
        FORCE=true
        export NONINTERACTIVE FORCE
        shift
        ;;
      --log-level)
        LOG_LEVEL="$2"
        export LOG_LEVEL
        shift 2
        ;;
      --version)
        echo "mac-bootstrap v${VERSION}"
        exit 0
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1 (use --help for usage)"
        ;;
    esac
  done

  mkdir -p "${LOGS_DIR}"

  case "$action" in
    bootstrap)
      if [[ -z "$profile" ]]; then
        die "Profile required. Usage: ./bootstrap.sh --profile personal"
      fi
      run_bootstrap_profile "$profile"
      ;;
    validate)
      run_validation
      ;;
    install-xcode)
      install_xcode "$xcode_path"
      ;;
    add-app)
      if [[ -z "$add_app_token" ]]; then
        die "--token is required with --add-app"
      fi
      add_app "$add_app_name" "$add_app_token"
      ;;
    add-cli)
      add_cli "$add_cli_name"
      ;;
    add-mas)
      if [[ -z "$add_mas_id" ]]; then
        die "--id is required with --add-mas"
      fi
      add_mas "$add_mas_name" "$add_mas_id"
      ;;
  esac
}

main() {
  trap 'stop_sudo_keepalive' EXIT

  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  parse_args "$@"
}

main "$@"
