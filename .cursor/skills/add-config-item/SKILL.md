---
name: add-config-item
description: Adds Homebrew casks, CLI formulae, or Mac App Store apps to mac-bootstrap config. Use when adding/removing apps, CLI tools, MAS apps, updating Brewfile, or editing config/apps.yaml, config/cli.yaml, or config/mas.yaml.
---

# Add config item (app / CLI / MAS)

## Prefer CLI over manual YAML

```bash
./bootstrap.sh --add-app "Raycast" --token raycast
./bootstrap.sh --add-cli "jq"
./bootstrap.sh --add-mas "Things 3" --id 904280696
```

These validate tokens/IDs, dedupe, regenerate `Brewfile` (app/cli), and append `CHANGELOG.md`.

## Manual YAML fallback

Only when `--add-*` is insufficient. After editing:

1. `make brewfile` if `apps.yaml` or `cli.yaml` changed
2. Update hardcoded counts in `tests/run_tests.sh` (`assert_equals` for apps/cli/mas)
3. Append `CHANGELOG.md` if user-facing

## Config shapes

**apps.yaml** — `name`, `token`, optional `description`

**cli.yaml** — `name`, `formula`, `special: false` (use `special:` block only for Homebrew/Oh My Zsh)

**mas.yaml** — `name`, `id` (numeric), optional `description`

## Remove an item

1. Delete the YAML entry
2. `make brewfile` if app/cli
3. Update test counts in `tests/run_tests.sh`
4. Update `CHANGELOG.md`

## Verify

```bash
make test && make lint
```
