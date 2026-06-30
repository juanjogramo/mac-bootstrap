#!/usr/bin/env bash
# Structured logging for mac-bootstrap

set -euo pipefail

LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"

_log_level_rank() {
  case "$1" in
    DEBUG)   echo 0 ;;
    INFO)    echo 1 ;;
    WARN)    echo 2 ;;
    ERROR)   echo 3 ;;
    SUCCESS) echo 1 ;;
    *)       echo 1 ;;
  esac
}

_log_should_print() {
  local level="$1"
  local current
  local target
  current="$(_log_level_rank "$LOG_LEVEL")"
  target="$(_log_level_rank "$level")"
  [[ "$target" -ge "$current" ]]
}

_ensure_log_dir() {
  if [[ -n "$LOG_FILE" ]]; then
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"
    mkdir -p "$log_dir"
  fi
}

log_message() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  _ensure_log_dir

  if _log_should_print "$level"; then
    case "$level" in
      SUCCESS) printf '\033[0;32m[%s]\033[0m %s\n' "$level" "$message" ;;
      WARN)    printf '\033[0;33m[%s]\033[0m %s\n' "$level" "$message" ;;
      ERROR)   printf '\033[0;31m[%s]\033[0m %s\n' "$level" "$message" >&2 ;;
      *)       printf '[%s] %s\n' "$level" "$message" ;;
    esac
  fi

  if [[ -n "$LOG_FILE" ]]; then
    printf '%s [%s] %s\n' "$timestamp" "$level" "$message" >>"$LOG_FILE"
  fi
}

log_debug()   { log_message "DEBUG" "$@"; }
log_info()    { log_message "INFO" "$@"; }
log_warn()    { log_message "WARN" "$@"; }
log_error()   { log_message "ERROR" "$@"; }
log_success() { log_message "SUCCESS" "$@"; }

log_section() {
  local title="$1"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "$title"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_dry_run() {
  log_warn "[DRY-RUN] $*"
}

# Use when logging from functions whose stdout is captured via $()
log_dry_run_stderr() {
  { log_dry_run "$@"; } >&2
}

log_info_stderr() {
  { log_info "$@"; } >&2
}
