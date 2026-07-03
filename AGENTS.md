# AGENTS.md — AI guide for mac-bootstrap

Bash + YAML macOS bootstrap CLI. End-user docs: [README.md](README.md).

**AI assets in this repo:**

| Asset | Path | When to use |
|-------|------|-------------|
| Skills | `.cursor/skills/` | Repeatable workflows (add items, new module, prefs) |
| Subagents | `.cursor/agents/` | Verification and shell review (readonly) |
| Rules | `.cursor/rules/` | Always-on + file-scoped constraints |

---

## Task routing

| Task | Primary action | Skill / agent |
|------|----------------|---------------|
| Add Homebrew app | `./bootstrap.sh --add-app "Name" --token token` | `add-config-item` |
| Add CLI tool | `./bootstrap.sh --add-cli "formula"` | `add-config-item` |
| Add MAS app | `./bootstrap.sh --add-mas "Name" --id 123` | `add-config-item` |
| Add macOS preference | Edit `config/macos.yaml` | `macos-preference` |
| Customize Dock / keyboard | Edit `config/dock.yaml` / `config/input_sources.yaml` | — |
| New install module | Script + profile + `bootstrap.sh` wiring | `new-bootstrap-module` |
| New profile | Copy `profiles/_template.yaml` | — |
| Before finishing any change | `make test && make lint` | `bootstrap-verifier` subagent |
| Review shell edits | — | `shell-reviewer` subagent |

**Safe preview:** `make dry-run` or `./bootstrap.sh --profile personal --dry-run`

---

## Golden rules

1. **Config in YAML** — never hardcode apps, tools, or prefs in scripts
2. **`Brewfile` is generated** — `make brewfile` after editing `apps.yaml` or `cli.yaml`
3. **Bash 3.2+ only** — no `declare -A`, `mapfile`, `[[ =~ ]]`
4. **Use helpers** — `log_*`, `run_cmd`, `run_sudo`, `yaml_*`, `run_bootstrap_step`, `die`
5. **Prefer `--add-*`** over manual YAML (validates, dedupes, updates CHANGELOG)
6. **`make test && make lint`** before finishing
7. **No credentials** in repo — MAS/GitHub auth is runtime-only
8. **macOS only** — do not assume Linux

---

## Architecture

### Sourced modules

`bootstrap.sh` **sources** all `scripts/*.sh`. Globals (`BOOTSTRAP_ROOT`, `DRY_RUN`, `PROFILE_FILE`, `BOOTSTRAP_FAILED_STEPS`) are shared.

New logic must live in functions, with optional standalone guard:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

### Bootstrap order

```
homebrew → cli/oh_my_zsh → apps → mas → dock → macos_preferences → input_sources → xcode (optional)
```

`run_bootstrap_step` records failures but **does not abort** the profile. Validation runs automatically after a real bootstrap (not dry-run).

### YAML parsing

Ruby one-liners in `scripts/helpers.sh` — **no `yq`**. Key functions:

| Function | Purpose |
|----------|---------|
| `yaml_get_list FILE KEY` | JSON array of list items |
| `yaml_get_value FILE KEY` | Scalar value |
| `yaml_list_contains FILE LIST FIELD VALUE` | Duplicate check |
| `yaml_append_item` / `yaml_append_cli_item` / `yaml_append_mas_item` | Append config entries |
| `regenerate_brewfile` | Rebuild Brewfile from apps + cli |
| `load_profile` / `profile_module_enabled` | Profile module toggles |

---

## Modules reference

| Module key | Function | Config |
|------------|----------|--------|
| `homebrew` | `install_homebrew` | — |
| `cli` | `install_cli` (includes Oh My Zsh) | `config/cli.yaml` |
| `oh_my_zsh` | `install_oh_my_zsh` (only if `cli: false`) | — |
| `apps` | `install_apps` | `config/apps.yaml` |
| `mas` | `install_mas` | `config/mas.yaml` |
| `dock` | `configure_dock` | `config/dock.yaml` |
| `macos_preferences` | `configure_macos_preferences` | `config/macos.yaml` |
| `input_sources` | `configure_input_sources` | `config/input_sources.yaml` |
| `xcode` / `install_xcode` | `install_xcode` | `config/xcode.yaml` |

`validation.strict` and `validation.fail_on_warnings` in profile YAML are **not implemented** — do not wire behavior to them without implementing `validate.sh` + tests.

---

## Finish checklist

- [ ] Config via YAML or `--add-*` (not hardcoded in scripts)
- [ ] `make brewfile` if `apps.yaml` or `cli.yaml` changed
- [ ] Test counts in `tests/run_tests.sh` updated if list sizes changed
- [ ] `CHANGELOG.md` for user-facing config changes (`--add-*` does this automatically)
- [ ] `make test` passes
- [ ] `make lint` passes
- [ ] `make dry-run` for bootstrap-affecting script changes

---

## What not to do

- Hand-edit `Brewfile`
- Bash 4+ syntax
- Subprocess pattern where sourcing + function call is the convention
- Run destructive bootstrap without explicit user request — use `--dry-run`
- Commit secrets, `.env`, or user-specific paths
- Implement `validation.strict` half-way

---

## Entry points

| Script | Purpose |
|--------|---------|
| `bootstrap.sh` | Main CLI — bootstrap, validate, add items, Xcode |
| `bin/mac-bootstrap` | PATH wrapper |
| `install.sh` | Curl installer → `~/.mac-bootstrap` |

---

## File map

```
bootstrap.sh          Orchestrator
install.sh            Remote/local installer
config/               YAML source of truth
profiles/             Module toggles per machine
scripts/
  helpers.sh          YAML, sudo, Brewfile, profiles
  logging.sh          Structured logging
  install_*.sh        Install modules
  configure_*.sh      Dock, input sources, macOS defaults
  validate.sh         Post-bootstrap validation
  add_item.sh         --add-app/cli/mas
tests/run_tests.sh    Test harness (hardcoded list counts)
Makefile              test, lint, dry-run, brewfile
.cursor/
  skills/             Workflow skills for agents
  agents/             Readonly verification subagents
  rules/              Always-on + glob-scoped rules
```

---

## Skills & subagents

### Skills (workflows)

Load automatically when the task matches the skill description.

| Skill | Triggers |
|-------|----------|
| `add-config-item` | Adding/removing apps, CLI, MAS; editing apps/cli/mas YAML |
| `new-bootstrap-module` | New `scripts/install_*.sh`, wiring `bootstrap.sh`, profile toggles |
| `macos-preference` | Editing `config/macos.yaml` or defaults behavior |

### Subagents (delegation)

| Subagent | Role | Mode |
|----------|------|------|
| `bootstrap-verifier` | Run test/lint, check checklist against diff | readonly |
| `shell-reviewer` | Bash 3.2, sourced-module, helper conventions | readonly |

Built-in Cursor subagents (`Explore`, `Bash`, `Bugbot`, `security-review`) still apply for exploration and generic review — project subagents add mac-bootstrap-specific checks.

**When skill vs subagent:** Use a **skill** for step-by-step workflows the main agent executes. Delegate to a **subagent** for independent verification or focused review in an isolated context.

---

## Environment variables

| Variable | Purpose |
|----------|---------|
| `DRY_RUN=true` | Preview without changes |
| `LOG_LEVEL` | DEBUG, INFO, WARN, ERROR |
| `MAC_BOOTSTRAP_HOME` | Install location (default `~/.mac-bootstrap`) |
| `MAC_BOOTSTRAP_PROFILE` | Profile for `install.sh` (default `personal`) |
| `MAC_BOOTSTRAP_DRY_RUN=1` | Dry-run via installer |
| `MAC_BOOTSTRAP_SKIP_RUN=1` | Install files only |
| `MAC_BOOTSTRAP_NONINTERACTIVE=1` | Unattended install |

---

## Testing note

`tests/run_tests.sh` hardcodes expected list counts — grep `assert_equals` in that file and update when config list sizes change. Tests use dry-run and parsing only; nothing is installed.
