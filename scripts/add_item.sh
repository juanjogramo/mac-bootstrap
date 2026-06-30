#!/usr/bin/env bash
# Add applications, CLI tools, or MAS apps to configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

add_app() {
  local name="$1"
  local token="$2"
  local description="${3:-}"

  if [[ -z "$name" ]] || [[ -z "$token" ]]; then
    die "Usage: --add-app \"Name\" --token cask-token"
  fi

  if ! validate_token "$token"; then
    die "Invalid cask token: ${token}"
  fi

  local config_file="${CONFIG_DIR}/apps.yaml"

  if yaml_list_contains "$config_file" "apps" "token" "$token"; then
    die "Application with token '${token}' already exists in apps.yaml"
  fi

  if yaml_list_contains "$config_file" "apps" "name" "$name"; then
    die "Application '${name}' already exists in apps.yaml"
  fi

  log_info "Adding application: ${name} (${token})"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would append to apps.yaml and regenerate Brewfile"
    return 0
  fi

  yaml_append_item "$config_file" "apps" "$name" "$token" "$description"
  regenerate_brewfile
  append_changelog "Added application: ${name} (token: ${token})"
  log_success "Added ${name} to apps.yaml"
}

add_cli() {
  local name="$1"
  local formula="${2:-$1}"
  local description="${3:-}"

  if [[ -z "$name" ]]; then
    die "Usage: --add-cli \"formula-name\""
  fi

  if ! validate_token "$formula"; then
    die "Invalid formula name: ${formula}"
  fi

  local config_file="${CONFIG_DIR}/cli.yaml"

  if yaml_list_contains "$config_file" "cli" "formula" "$formula"; then
    die "CLI tool '${formula}' already exists in cli.yaml"
  fi

  log_info "Adding CLI tool: ${name} (${formula})"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would append to cli.yaml and regenerate Brewfile"
    return 0
  fi

  yaml_append_cli_item "$config_file" "$name" "$formula" "$description"
  regenerate_brewfile
  append_changelog "Added CLI tool: ${name} (formula: ${formula})"
  log_success "Added ${name} to cli.yaml"
}

add_mas() {
  local name="$1"
  local app_id="$2"
  local description="${3:-}"

  if [[ -z "$name" ]] || [[ -z "$app_id" ]]; then
    die "Usage: --add-mas \"App Name\" --id 123456789"
  fi

  if ! validate_mas_id "$app_id"; then
    die "Invalid MAS app ID: ${app_id} (must be numeric)"
  fi

  local config_file="${CONFIG_DIR}/mas.yaml"

  if yaml_list_contains "$config_file" "mas_apps" "id" "$app_id"; then
    die "MAS app with ID '${app_id}' already exists in mas.yaml"
  fi

  if yaml_list_contains "$config_file" "mas_apps" "name" "$name"; then
    die "MAS app '${name}' already exists in mas.yaml"
  fi

  log_info "Adding MAS app: ${name} (id: ${app_id})"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would append to mas.yaml"
    return 0
  fi

  yaml_append_mas_item "$config_file" "$name" "$app_id" "$description"
  append_changelog "Added MAS app: ${name} (id: ${app_id})"
  log_success "Added ${name} to mas.yaml"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    app) add_app "${2:-}" "${3:-}" "${4:-}" ;;
    cli) add_cli "${2:-}" "${3:-}" "${4:-}" ;;
    mas) add_mas "${2:-}" "${3:-}" "${4:-}" ;;
    *) die "Usage: add_item.sh {app|cli|mas} ..." ;;
  esac
fi
