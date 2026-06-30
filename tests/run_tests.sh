# mac-bootstrap test suite
# Run with: make test

set -euo pipefail

BOOTSTRAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/helpers.sh
source "${BOOTSTRAP_ROOT}/scripts/helpers.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: ${message}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${message}"
    echo "    Expected: ${expected}"
    echo "    Actual:   ${actual}"
  fi
}

assert_true() {
  local message="$1"
  shift
  TESTS_RUN=$((TESTS_RUN + 1))
  if "$@"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: ${message}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${message}"
  fi
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File exists: ${file}}"
  assert_true "$message" test -f "$file"
}

test_config_files_exist() {
  echo "Test: Configuration files exist"
  assert_file_exists "${CONFIG_DIR}/apps.yaml"
  assert_file_exists "${CONFIG_DIR}/cli.yaml"
  assert_file_exists "${CONFIG_DIR}/mas.yaml"
  assert_file_exists "${CONFIG_DIR}/macos.yaml"
  assert_file_exists "${CONFIG_DIR}/xcode.yaml"
  assert_file_exists "${PROFILES_DIR}/personal.yaml"
}

test_apps_yaml_parsing() {
  echo "Test: apps.yaml parsing"
  local count
  count="$(yaml_get_list "${CONFIG_DIR}/apps.yaml" "apps" | ruby -rjson -e 'puts JSON.parse(STDIN.read).length')"
  assert_equals "8" "$count" "apps.yaml contains 8 applications"
}

test_cli_yaml_parsing() {
  echo "Test: cli.yaml parsing"
  local count
  count="$(yaml_get_list "${CONFIG_DIR}/cli.yaml" "cli" | ruby -rjson -e 'puts JSON.parse(STDIN.read).length')"
  assert_equals "3" "$count" "cli.yaml contains 3 CLI tools"
}

test_mas_yaml_parsing() {
  echo "Test: mas.yaml parsing"
  local count
  count="$(yaml_get_list "${CONFIG_DIR}/mas.yaml" "mas_apps" | ruby -rjson -e 'puts JSON.parse(STDIN.read).length')"
  assert_equals "1" "$count" "mas.yaml contains 1 MAS app"
}

test_validate_token() {
  echo "Test: Token validation"
  assert_true "Valid token: google-chrome" validate_token google-chrome
  assert_true "Valid token: logi-options+" validate_token logi-options+
  assert_true "Invalid token rejected" bash -c "source '${BOOTSTRAP_ROOT}/scripts/helpers.sh' && ! validate_token 'invalid token!'"
}

test_validate_mas_id() {
  echo "Test: MAS ID validation"
  assert_true "Valid MAS ID" validate_mas_id 904280696
  assert_true "Invalid MAS ID rejected" bash -c "source '${BOOTSTRAP_ROOT}/scripts/helpers.sh' && ! validate_mas_id abc"
}

test_duplicate_detection() {
  echo "Test: Duplicate detection"
  assert_true "Google Chrome token exists" \
    yaml_list_contains "${CONFIG_DIR}/apps.yaml" apps token google-chrome
  assert_true "Non-existent token not found" \
    bash -c "source '${BOOTSTRAP_ROOT}/scripts/helpers.sh' && ! yaml_list_contains '${CONFIG_DIR}/apps.yaml' apps token nonexistent-app-xyz"
}

test_brewfile_exists() {
  echo "Test: Brewfile exists"
  assert_file_exists "${BREWFILE}"
}

test_bootstrap_help() {
  echo "Test: bootstrap.sh --help"
  TESTS_RUN=$((TESTS_RUN + 1))
  if "${BOOTSTRAP_ROOT}/bootstrap.sh" --help >/dev/null 2>&1; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: bootstrap.sh --help exits successfully"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: bootstrap.sh --help failed"
  fi
}

test_dry_run() {
  echo "Test: Dry run mode"
  TESTS_RUN=$((TESTS_RUN + 1))
  if DRY_RUN=true "${BOOTSTRAP_ROOT}/bootstrap.sh" --profile personal --dry-run >/dev/null 2>&1; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: Dry run completes without errors"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: Dry run failed"
  fi
}

test_xcode_dry_run_includes_clt() {
  echo "Test: Xcode dry-run includes Command Line Tools step"
  TESTS_RUN=$((TESTS_RUN + 1))
  local output
  output="$(DRY_RUN=true bash "${BOOTSTRAP_ROOT}/bootstrap.sh" --xcode-path /tmp/Xcode_26.0.xip --dry-run 2>&1 || true)"
  if echo "$output" | grep -q "xcode-select --install"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: Dry-run mentions xcode-select --install"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: Dry-run missing xcode-select --install step"
  fi
}

test_install_script_syntax() {
  echo "Test: install.sh syntax"
  TESTS_RUN=$((TESTS_RUN + 1))
  if bash -n "${BOOTSTRAP_ROOT}/install.sh" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: install.sh syntax valid"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: install.sh syntax invalid"
  fi
}

test_mac_bootstrap_wrapper_syntax() {
  echo "Test: bin/mac-bootstrap syntax"
  TESTS_RUN=$((TESTS_RUN + 1))
  if bash -n "${BOOTSTRAP_ROOT}/bin/mac-bootstrap" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: bin/mac-bootstrap syntax valid"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: bin/mac-bootstrap syntax invalid"
  fi
}

test_ensure_sudo_dry_run() {
  echo "Test: ensure_sudo dry-run"
  TESTS_RUN=$((TESTS_RUN + 1))
  if DRY_RUN=true bash -c 'source scripts/helpers.sh && ensure_sudo'; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: ensure_sudo succeeds in dry-run mode"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ensure_sudo failed in dry-run mode"
  fi
}

test_run_bootstrap_step_continues() {
  echo "Test: run_bootstrap_step continues on failure"
  TESTS_RUN=$((TESTS_RUN + 1))
  if bash -c '
    source scripts/helpers.sh
    BOOTSTRAP_FAILED_STEPS=()
    failing() { return 1; }
    run_bootstrap_step "test-step" failing
    [[ "${#BOOTSTRAP_FAILED_STEPS[@]}" -eq 1 ]]
  '; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: run_bootstrap_step records failure without exiting"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: run_bootstrap_step did not handle failure correctly"
  fi
}

test_xcode_version_extraction() {
  echo "Test: Xcode version extraction"
  # shellcheck source=../scripts/install_xcode.sh
  source "${BOOTSTRAP_ROOT}/scripts/install_xcode.sh"
  local version
  version="$(extract_version_from_xip "/tmp/Xcode_26.0.xip")"
  assert_equals "26.0" "$version" "Extract version from Xcode_26.0.xip"
  version="$(extract_version_from_xip "/tmp/Xcode_26.1.xip")"
  assert_equals "26.1" "$version" "Extract version from Xcode_26.1.xip"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "mac-bootstrap test suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_config_files_exist
echo ""
test_apps_yaml_parsing
echo ""
test_cli_yaml_parsing
echo ""
test_mas_yaml_parsing
echo ""
test_validate_token
echo ""
test_validate_mas_id
echo ""
test_duplicate_detection
echo ""
test_brewfile_exists
echo ""
test_bootstrap_help
echo ""
test_dry_run
echo ""
test_install_script_syntax
echo ""
test_mac_bootstrap_wrapper_syntax
echo ""
test_ensure_sudo_dry_run
echo ""
test_run_bootstrap_step_continues
echo ""
test_xcode_dry_run_includes_clt
echo ""
test_xcode_version_extraction
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: ${TESTS_PASSED}/${TESTS_RUN} passed, ${TESTS_FAILED} failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$TESTS_FAILED" -gt 0 ]]; then
  exit 1
fi

exit 0
