---
name: new-bootstrap-module
description: Adds a new bootstrap install or configure module to mac-bootstrap. Use when creating scripts/install_*.sh, wiring bootstrap.sh, adding profile module toggles, or extending the bootstrap pipeline (dock, input_sources patterns).
---

# New bootstrap module

## Checklist

Copy and track progress:

```
- [ ] scripts/<module>.sh — function install_<module> or configure_<module>
- [ ] config/<module>.yaml — if module reads YAML (optional)
- [ ] profiles/_template.yaml + profiles/personal.yaml — modules.<key>: true/false
- [ ] bootstrap.sh — source script + run_bootstrap_step in run_bootstrap_profile
- [ ] tests/run_tests.sh — parsing/idempotency tests if logic is testable
- [ ] README.md + CHANGELOG.md — user-facing docs
- [ ] make test && make lint && make dry-run
```

## Script template

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

configure_<module>() {
  log_section "Configuring <module>"
  # guard prerequisites (brew, prior modules)
  # read config: yaml_get_list / yaml_get_value
  # idempotency check before each change
  # respect DRY_RUN via log_dry_run / run_cmd
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  configure_<module> "$@"
fi
```

**Critical:** No top-level side effects — `bootstrap.sh` sources all scripts.

## Wiring order in bootstrap.sh

Place after dependencies. Current order:

```
homebrew → cli/oh_my_zsh → apps → mas → dock → macos_preferences → input_sources → xcode
```

Example: a module needing `dockutil` must run after `cli`.

## Reference implementations

| Module | Script | Config |
|--------|--------|--------|
| dock | `scripts/configure_dock.sh` | `config/dock.yaml` |
| input_sources | `scripts/configure_input_sources.sh` | `config/input_sources.yaml` |
| apps | `scripts/install_apps.sh` | `config/apps.yaml` |

Use `run_bootstrap_step "<name>" <function>` — failures are recorded, bootstrap continues.
