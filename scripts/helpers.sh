#!/usr/bin/env bash
# Shared helper functions for mac-bootstrap

set -euo pipefail

# Resolve project root regardless of caller location
if [[ -z "${BOOTSTRAP_ROOT:-}" ]]; then
  BOOTSTRAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

export BOOTSTRAP_ROOT
export CONFIG_DIR="${BOOTSTRAP_ROOT}/config"
export PROFILES_DIR="${BOOTSTRAP_ROOT}/profiles"
export LOGS_DIR="${BOOTSTRAP_ROOT}/logs"
export CHANGELOG_FILE="${BOOTSTRAP_ROOT}/CHANGELOG.md"
export BREWFILE="${BOOTSTRAP_ROOT}/Brewfile"

DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
NONINTERACTIVE="${NONINTERACTIVE:-false}"
SUDO_KEEPALIVE_PID=""

# Source logging if not already loaded
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=logging.sh
  source "${BOOTSTRAP_ROOT}/scripts/logging.sh"
fi

die() {
  log_error "$@"
  exit 1
}

warn_and_continue() {
  log_warn "$@"
  return 1
}

stop_sudo_keepalive() {
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
    wait "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
    SUDO_KEEPALIVE_PID=""
  fi
}

start_sudo_keepalive() {
  if [[ "$DRY_RUN" == "true" ]] || [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    return 0
  fi

  (
    while true; do
      sleep 60
      sudo -n true 2>/dev/null || exit
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
}

ensure_sudo() {
  local max_attempts=3
  local attempt=1

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would request administrator privileges"
    return 0
  fi

  if sudo -n true 2>/dev/null; then
    start_sudo_keepalive
    return 0
  fi

  if [[ "$NONINTERACTIVE" == "true" ]]; then
    log_error "Administrator privileges are required but --noninteractive was specified."
    log_error "Run without --noninteractive or authorize sudo first: sudo -v"
    return 1
  fi

  log_warn "mac-bootstrap needs administrator privileges for some steps (Homebrew, system tools, Xcode)."
  log_info "Please enter your macOS password when prompted."

  while [[ "$attempt" -le "$max_attempts" ]]; do
    if sudo -v; then
      log_success "Administrator privileges granted"
      start_sudo_keepalive
      return 0
    fi

    log_warn "Administrator authorization failed (attempt ${attempt}/${max_attempts})"
    attempt=$((attempt + 1))
  done

  log_error "Could not obtain administrator privileges after ${max_attempts} attempts."
  return 1
}

run_bootstrap_step() {
  local step_name="$1"
  shift

  if "$@"; then
    return 0
  fi

  local exit_code=$?
  log_warn "Step '${step_name}' failed (exit ${exit_code}). Continuing with remaining steps..."
  BOOTSTRAP_FAILED_STEPS+=("${step_name}")
  return 0
}

confirm() {
  local prompt="$1"
  if [[ "$FORCE" == "true" ]] || [[ "$NONINTERACTIVE" == "true" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would prompt: $prompt"
    return 0
  fi
  read -r -p "$prompt [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run: $*"
    return 0
  fi
  log_debug "Running: $*"
  "$@"
}

run_sudo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry_run "Would run (sudo): $*"
    return 0
  fi

  local max_attempts=3
  local attempt=1

  while [[ "$attempt" -le "$max_attempts" ]]; do
    if sudo -n true 2>/dev/null || ensure_sudo; then
      log_debug "Running (sudo): $*"
      if sudo "$@"; then
        return 0
      fi
      log_warn "sudo command failed: $*"
    fi

    if [[ "$NONINTERACTIVE" == "true" ]]; then
      return 1
    fi

    log_warn "Retrying sudo command (attempt ${attempt}/${max_attempts})..."
    sudo -k 2>/dev/null || true
    attempt=$((attempt + 1))
  done

  log_error "sudo command failed after ${max_attempts} attempts: $*"
  return 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# YAML parsing via Ruby (available on macOS by default)
yaml_read() {
  local file="$1"
  local query="$2"
  ruby -ryaml -rjson -e "
    data = YAML.load_file('$file')
    keys = '$query'.split('.')
    result = keys.reduce(data) { |obj, key| obj.is_a?(Hash) ? obj[key] : obj }
    puts result.to_json
  " 2>/dev/null
}

yaml_get_list() {
  local file="$1"
  local key="$2"
  ruby -ryaml -rjson -e "
    data = YAML.load_file('$file')
    items = data['$key'] || []
    puts items.to_json
  " 2>/dev/null
}

yaml_get_value() {
  local file="$1"
  local key="$2"
  ruby -ryaml -e "
    data = YAML.load_file('$file')
    val = data.dig(*'$key'.split('.'))
    puts val.nil? ? '' : val
  " 2>/dev/null
}

# Check if item exists in YAML list by field
yaml_list_contains() {
  local file="$1"
  local list_key="$2"
  local field="$3"
  local value="$4"
  ruby -ryaml -e "
    data = YAML.load_file('$file')
    items = data['$list_key'] || []
    found = items.any? { |i| i['$field'].to_s == '$value' }
    exit(found ? 0 : 1)
  " 2>/dev/null
}

# Append item to YAML list preserving formatting
yaml_append_item() {
  local file="$1"
  local list_key="$2"
  local name="$3"
  local token="$4"
  local description="${5:-}"

  ruby -ryaml -e "
    data = YAML.load_file('$file')
    data['$list_key'] ||= []
    data['$list_key'] << {
      'name' => '$name',
      'token' => '$token',
      'description' => '$description'
    }
    File.write('$file', data.to_yaml)
  " 2>/dev/null
}

yaml_append_mas_item() {
  local file="$1"
  local name="$2"
  local id="$3"
  local description="${4:-}"

  ruby -ryaml -e "
    data = YAML.load_file('$file')
    data['mas_apps'] ||= []
    data['mas_apps'] << {
      'name' => '$name',
      'id' => $id,
      'description' => '$description'
    }
    File.write('$file', data.to_yaml)
  " 2>/dev/null
}

yaml_append_cli_item() {
  local file="$1"
  local name="$2"
  local formula="$3"
  local description="${4:-}"

  ruby -ryaml -e "
    data = YAML.load_file('$file')
    data['cli'] ||= []
    data['cli'] << {
      'name' => '$name',
      'formula' => '$formula',
      'description' => '$description',
      'special' => false
    }
    File.write('$file', data.to_yaml)
  " 2>/dev/null
}

append_changelog() {
  local entry="$1"
  local timestamp
  timestamp="$(date '+%Y-%m-%d')"

  if [[ ! -f "$CHANGELOG_FILE" ]]; then
    cat >"$CHANGELOG_FILE" <<'EOF'
# Changelog

All notable changes to mac-bootstrap configuration are documented here.

EOF
  fi

  {
    echo ""
    echo "## [$timestamp]"
    echo "- $entry"
  } >>"$CHANGELOG_FILE"
}

regenerate_brewfile() {
  log_info "Regenerating Brewfile from configuration..."

  local apps_json cli_json
  apps_json="$(yaml_get_list "${CONFIG_DIR}/apps.yaml" "apps")"
  cli_json="$(yaml_get_list "${CONFIG_DIR}/cli.yaml" "cli")"

  {
    echo "# Generated by mac-bootstrap — do not edit manually"
    echo "# Regenerate with: make brewfile"
    echo "# Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "# CLI tools"
  } >"$BREWFILE"

  echo "$cli_json" | ruby -rjson -e "
    JSON.parse(STDIN.read).each do |item|
      next if item['special']
      puts \"brew \\\"#{item['formula']}\\\"\"
    end
  " >>"$BREWFILE"

  {
    echo ""
    echo "# Applications (casks)"
  } >>"$BREWFILE"

  echo "$apps_json" | ruby -rjson -e "
    JSON.parse(STDIN.read).each do |item|
      puts \"cask \\\"#{item['token']}\\\"\"
    end
  " >>"$BREWFILE"

  log_success "Brewfile regenerated at ${BREWFILE}"
}

load_profile() {
  local profile="$1"
  local profile_file="${PROFILES_DIR}/${profile}.yaml"

  if [[ ! -f "$profile_file" ]]; then
    die "Profile not found: ${profile} (expected ${profile_file})"
  fi

  PROFILE_FILE="$profile_file"
  export PROFILE_FILE
  log_info "Loaded profile: ${profile}"
}

profile_module_enabled() {
  local module="$1"
  local value
  value="$(yaml_get_value "$PROFILE_FILE" "modules.${module}")"
  [[ "$value" == "true" ]]
}

app_installed_cask() {
  local token="$1"
  brew list --cask "$token" &>/dev/null
}

app_installed_mas() {
  local app_id="$1"
  mas list 2>/dev/null | grep -q " ${app_id} "
}

app_exists_in_applications() {
  local app_name="$1"
  [[ -d "/Applications/${app_name}" ]] || [[ -d "${HOME}/Applications/${app_name}" ]]
}

get_brew_prefix() {
  if command_exists brew; then
    brew --prefix
  else
    echo "/opt/homebrew"
  fi
}

expand_path() {
  local path="$1"
  # shellcheck disable=SC2086
  eval echo "$path"
}

validate_mas_id() {
  local id="$1"
  [[ "$id" =~ ^[0-9]+$ ]]
}

validate_token() {
  local token="$1"
  [[ "$token" =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$ ]]
}

sanitize_name() {
  local name="$1"
  echo "$name" | tr -cd '[:alnum:] ._-'
}
