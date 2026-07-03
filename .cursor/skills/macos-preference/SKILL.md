---
name: macos-preference
description: Adds or edits macOS system preferences in mac-bootstrap. Use when editing config/macos.yaml, defaults write settings, Dock/UI prefs, or scripts/macos_defaults.sh behavior.
---

# macOS preference

## Add to config/macos.yaml

Follow existing `preferences:` entries:

```yaml
preferences:
  my_key:
    description: Human-readable purpose
    domain: com.apple.example
    key: SomeKey
    value: true          # string, bool, int, or float
    type: bool           # string | bool | int | float
    handler: defaults
    note: "Optional — manual steps on newer macOS"
```

Copy field names and structure from neighboring entries in `config/macos.yaml`.

## Rules

- Never hardcode preference values in shell scripts — YAML only
- Handler is `defaults` for standard `defaults write` prefs
- Dock/SystemUIServer restart is handled by `scripts/macos_defaults.sh` — do not duplicate
- Some menu bar prefs still need **System Settings → Control Center** on newer macOS — document in `note:`

## Verify

```bash
make dry-run                    # preview preference step
./scripts/macos_defaults.sh     # run step alone
defaults read <domain> <key>    # spot-check applied value
make test && make lint
```

## Profile toggle

Preferences run when `modules.macos_preferences: true` in the active profile.
