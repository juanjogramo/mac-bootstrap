# AGENTS.md — Guide for AI Assistants

This document helps AI agents work efficiently on **mac-bootstrap**: a Bash-based, YAML-driven macOS bootstrap CLI.

For end-user documentation, see [README.md](README.md).

---

## What This Project Does

mac-bootstrap configures a fresh Mac from version-controlled YAML: Homebrew apps/formulae, Mac App Store apps, macOS defaults, and optional Xcode from a `.xip` archive. It is idempotent, profile-based, and supports dry-run mode.

**Entry points:**

| Script | Purpose |
|--------|---------|
| `bootstrap.sh` | Main CLI — bootstrap, validate, add items, install Xcode |
| `bin/mac-bootstrap` | PATH wrapper → `bootstrap.sh` |
| `install.sh` | One-line / curl installer; clones to `~/.mac-bootstrap` and runs bootstrap |

---

## Golden Rules

1. **Configuration lives in YAML** — never hardcode apps, tools, or preferences in shell scripts.
2. **Do not hand-edit `Brewfile`** — it is auto-generated from `config/apps.yaml` and `config/cli.yaml`. Run `make brewfile` after manual YAML edits to those files.
3. **Bash 3.2+ only** — macOS default shell. No bash 4+ features (`declare -A`, `mapfile`, `[[ =~ ]]`, etc.).
4. **Use existing helpers** — `log_*`, `run_cmd`, `run_sudo`, `yaml_*`, `run_bootstrap_step`. Do not duplicate.
5. **Prefer `--add-*` CLI** over manual YAML when adding apps, CLI tools, or MAS apps (validates, deduplicates, updates CHANGELOG).
6. **Run `make test && make lint`** before finishing any change.
7. **Never store credentials** — MAS and GitHub auth are user-managed at runtime.
8. **This project only runs on macOS** — do not assume Linux compatibility.

---

## Architecture

### Sourced modules (not subprocesses)

`bootstrap.sh` **sources** all `scripts/*.sh` into one shell session. Globals like `BOOTSTRAP_ROOT`, `DRY_RUN`, `PROFILE_FILE`, and `BOOTSTRAP_FAILED_STEPS` are shared.

**Implication:** Top-level code in install scripts runs at source time. New logic must live inside functions, guarded by:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

### Bootstrap flow (module order)

```
homebrew → cli/oh_my_zsh → apps → mas → macos_preferences → xcode (optional)
```

Each step runs via `run_bootstrap_step`, which records failures but **does not abort** the profile. After a real bootstrap, validation runs automatically.

### YAML parsing

YAML is parsed with **Ruby one-liners** in `scripts/helpers.sh` (`yaml_get_list`, `yaml_get_value`, `yaml_append_*`). Do not add `yq` or bash-native YAML parsers.

### Key paths

| Path | Role |
|------|------|
| `config/*.yaml` | Apps, CLI, MAS, macOS prefs, Xcode settings |
| `profiles/*.yaml` | Module toggles per machine/profile |
| `scripts/` | Install modules, helpers, validation, add-item logic |
| `tests/run_tests.sh` | Custom bash test harness |
| `logs/bootstrap.log` | Runtime log (gitignored content) |

---

## Profiles

Profiles gate which modules run. See `profiles/personal.yaml` and `profiles/_template.yaml`.

| Module key | Script function | Config file |
|------------|-----------------|-------------|
| `homebrew` | `install_homebrew` | — |
| `cli` | `install_cli` (includes Oh My Zsh) | `config/cli.yaml` |
| `oh_my_zsh` | `install_oh_my_zsh` (only if `cli: false`) | — |
| `apps` | `install_apps` | `config/apps.yaml` |
| `mas` | `install_mas` | `config/mas.yaml` |
| `macos_preferences` | `configure_macos_preferences` | `config/macos.yaml` |
| `xcode` / `install_xcode` | `install_xcode` | `config/xcode.yaml` |

**Note:** `validation.strict` and `validation.fail_on_warnings` in profile YAML are **not implemented yet**. Do not assume they affect `validate.sh`.

---

## Common Tasks

### Add a Homebrew cask (app)

```bash
./bootstrap.sh --add-app "Raycast" --token raycast
```

Or edit `config/apps.yaml`, then `make brewfile`.

### Add a CLI formula

```bash
./bootstrap.sh --add-cli "jq"
```

### Add a Mac App Store app

```bash
./bootstrap.sh --add-mas "Things 3" --id 904280696
```

### Add a macOS preference

Edit `config/macos.yaml` — follow existing `preferences:` entries (domain, key, value, type, handler).

### Add a new profile

1. Copy `profiles/_template.yaml` → `profiles/<name>.yaml`
2. Set module toggles
3. Run `./bootstrap.sh --profile <name> --dry-run`

### Add a new install module

1. Create `scripts/install_<module>.sh` following existing install scripts (function + optional standalone guard)
2. Add `modules.<module>: true/false` to profile YAML
3. Source the script in `bootstrap.sh`
4. Wire a `run_bootstrap_step` call in `run_bootstrap_profile`
5. Add tests if the module has testable logic

### Preview changes safely

```bash
make dry-run                    # full profile dry-run
./bootstrap.sh --validate       # check current install state
LOG_LEVEL=DEBUG make dry-run    # verbose dry-run
```

---

## Script Conventions

Every shell script should:

- Use `#!/usr/bin/env bash` and `set -euo pipefail`
- Source `helpers.sh` (and `logging.sh` if needed)
- Use `log_section` / `log_info` / `log_warn` / `log_error` for output
- Check idempotency before installing (`brew list`, `mas list`, `/Applications`, etc.)
- Respect `DRY_RUN` — log `[DRY-RUN]` actions without side effects
- Pass ShellCheck (`make lint`)

Install script shape:

```bash
install_<module>() {
  log_section "Installing <module>"
  # guard prerequisites
  # read config via yaml_get_list / yaml_get_value
  # loop items with idempotency checks
  # return 0 on success, 1 on failure
}
```

---

## Testing

```bash
make test    # run test suite
make lint    # ShellCheck (requires: brew install shellcheck)
```

**Brittle test counts:** `tests/run_tests.sh` hardcodes expected item counts for `apps.yaml` (8), `cli.yaml` (3), and `mas.yaml` (1). **Update these assertions** when adding or removing config items.

Tests run without installing anything — they use dry-run mode and parsing checks.

---

## Environment Variables

| Variable | Used by | Purpose |
|----------|---------|---------|
| `DRY_RUN=true` | `bootstrap.sh` | Preview without changes |
| `LOG_LEVEL` | logging | DEBUG, INFO, WARN, ERROR |
| `MAC_BOOTSTRAP_HOME` | `install.sh` | Install location (default `~/.mac-bootstrap`) |
| `MAC_BOOTSTRAP_PROFILE` | `install.sh` | Profile to run (default `personal`) |
| `MAC_BOOTSTRAP_DRY_RUN=1` | `install.sh` | Dry-run via installer |
| `MAC_BOOTSTRAP_SKIP_RUN=1` | `install.sh` | Install files only, skip bootstrap |
| `MAC_BOOTSTRAP_NONINTERACTIVE=1` | `install.sh` | Non-interactive install |

---

## Change Checklist

Before marking work complete:

- [ ] Config changes use YAML or `--add-*` (not hardcoded in scripts)
- [ ] `Brewfile` regenerated if `apps.yaml` or `cli.yaml` changed (`make brewfile`)
- [ ] Test counts updated if config list sizes changed
- [ ] `CHANGELOG.md` updated for user-facing config changes (auto-done by `--add-*`)
- [ ] `make test` passes
- [ ] `make lint` passes
- [ ] Dry-run tested for bootstrap-affecting changes

---

## What Not to Do

- Do not edit `Brewfile` manually
- Do not use bash 4+ syntax
- Do not add subprocess calls where sourcing + function calls are the pattern
- Do not implement `validation.strict` without wiring it through `validate.sh` and tests
- Do not commit secrets, `.env` files, or user-specific paths
- Do not run destructive bootstrap on the user's machine without explicit request — use `--dry-run` for verification

---

## File Map (quick reference)

```
bootstrap.sh          Orchestrator — source this pattern for wiring
install.sh            Remote/local installer
config/               YAML configuration (source of truth)
profiles/             Per-machine module toggles
scripts/
  helpers.sh          YAML, sudo, Brewfile, profile helpers
  logging.sh          Structured logging
  install_*.sh        One module per file
  validate.sh         Post-bootstrap validation
  add_item.sh         --add-app/cli/mas implementation
tests/run_tests.sh    Test harness
Makefile              test, lint, dry-run, brewfile targets
```
