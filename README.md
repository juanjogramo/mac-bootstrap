# mac-bootstrap

**Infrastructure as Code for macOS** — a reusable, idempotent bootstrap CLI that configures a fresh Mac with applications, development tools, system preferences, and optional Xcode installation.

After a clean macOS installation, run:

```bash
./bootstrap.sh --profile personal
```

Your Mac is configured the way you normally set it up — safely, repeatably, and from version-controlled configuration.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Installation Guide](#installation-guide)
- [CLI Reference](#cli-reference)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Profiles](#profiles)
- [What Gets Installed](#what-gets-installed)
- [macOS Preferences](#macos-preferences-configured)
- [Xcode Installation](#xcode-installation)
- [Validation](#validation)
- [Logging](#logging)
- [Safety](#safety)
- [Makefile Targets](#makefile-targets)
- [Troubleshooting](#troubleshooting)
- [Future Extension Guide](#future-extension-guide)
- [Development](#development)
- [License](#license)

---

## Features

- **Configuration-driven** — apps, CLI tools, MAS apps, and preferences live in YAML
- **Idempotent** — safe to rerun; skips already-installed components
- **Dry-run mode** — preview all changes before applying
- **Validation** — verify installation state with a structured report
- **Extensible** — add apps/tools via CLI without editing multiple files
- **Xcode support** — install from `.xip` archives with versioned naming (`Xcode_26.0.app`)
- **Structured logging** — all operations logged to `logs/bootstrap.log`
- **Profile-based** — support multiple machine configurations
- **Bash 3.2+ compatible** — works with the default macOS shell

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS | Apple Silicon or Intel |
| Bash 3.2+ | Default on macOS |
| Ruby | Pre-installed on macOS; used for YAML parsing |
| Internet | Required for Homebrew, casks, and installers |
| Mac App Store sign-in | Required for `mas` apps (credentials are **not** stored) |
| Xcode `.xip` archive | Optional; download from [Apple Developer](https://developer.apple.com/download/all/) |

---

## Quick Start

```bash
git clone <your-repo-url> mac-bootstrap
cd mac-bootstrap
chmod +x bootstrap.sh scripts/*.sh

./bootstrap.sh --profile personal --dry-run   # 1. Preview
./bootstrap.sh --profile personal             # 2. Execute
./bootstrap.sh --validate                     # 3. Verify
```

---

## Installation Guide

### First-Time Setup on a New Mac

1. **Open Terminal** and clone the repository:

   ```bash
   cd ~/Developer
   git clone <your-repo-url> mac-bootstrap
   cd mac-bootstrap
   chmod +x bootstrap.sh scripts/*.sh
   ```

2. **Preview** what will be installed and configured:

   ```bash
   ./bootstrap.sh --profile personal --dry-run
   ```

3. **Run bootstrap** (installs Homebrew, apps, CLI tools, MAS apps, and applies preferences):

   ```bash
   ./bootstrap.sh --profile personal
   ```

   If prompted during Homebrew installation, accept the **Xcode Command Line Tools** dialog.

4. **Install Xcode** (optional, separate step — not from the Mac App Store):

   ```bash
   ./bootstrap.sh --xcode-path ~/Downloads/Xcode_26.0.xip
   # or auto-discover the latest .xip in ~/Downloads or ~/Desktop:
   ./bootstrap.sh --install-xcode
   ```

5. **Validate** the result:

   ```bash
   ./bootstrap.sh --validate
   ```

### Installing Individual Components

Bootstrap is modular. You can also run scripts directly:

```bash
./scripts/install_homebrew.sh
./scripts/install_apps.sh
./scripts/install_cli.sh
./scripts/install_mas.sh
./scripts/macos_defaults.sh
./scripts/install_xcode.sh ~/Downloads/Xcode_26.0.xip
./scripts/validate.sh
```

---

## CLI Reference

```
mac-bootstrap v1.0.0 — Infrastructure as Code for macOS

USAGE:
  ./bootstrap.sh [OPTIONS]
```

| Option | Description |
|---|---|
| `--profile NAME` | Run a bootstrap profile (e.g. `personal`) |
| `--dry-run` | Show what would happen without making changes |
| `--validate` | Validate current installation and configuration state |
| `--install-xcode` | Install Xcode from a `.xip` archive (auto-discover) |
| `--xcode-path PATH` | Install Xcode from a specific `.xip` file |
| `--add-app NAME` | Add a Homebrew cask application to config |
| `--token TOKEN` | Cask token (required with `--add-app`) |
| `--add-cli NAME` | Add a Homebrew formula to config |
| `--add-mas NAME` | Add a Mac App Store application to config |
| `--id ID` | MAS app ID (required with `--add-mas`) |
| `--force` | Skip confirmation prompts |
| `--noninteractive` | Non-interactive mode (implies `--force`) |
| `--log-level LEVEL` | Set log level: `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `--version` | Print version and exit |
| `--help` | Show help and exit |

### Examples

```bash
# Full bootstrap
./bootstrap.sh --profile personal

# Preview without changes
./bootstrap.sh --profile personal --dry-run

# Validate installation
./bootstrap.sh --validate

# Xcode from archive
./bootstrap.sh --xcode-path ~/Downloads/Xcode_26.0.xip
./bootstrap.sh --install-xcode

# Add new items to configuration
./bootstrap.sh --add-app "Raycast" --token raycast
./bootstrap.sh --add-app "Cursor" --token cursor
./bootstrap.sh --add-cli "jq"
./bootstrap.sh --add-mas "Things 3" --id 904280696

# Unattended run
./bootstrap.sh --profile personal --noninteractive
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `LOG_LEVEL` | `INFO` | Minimum log level to print |
| `LOG_FILE` | `logs/bootstrap.log` | Path to log file |
| `DRY_RUN` | `false` | Set to `true` to enable dry-run mode |
| `FORCE` | `false` | Skip confirmation prompts |
| `NONINTERACTIVE` | `false` | Non-interactive mode |

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Error (missing args, install failure, validation failure) |

---

## Project Structure

```
mac-bootstrap/
├── bootstrap.sh              # Main CLI entry point
├── Brewfile                  # Auto-generated Homebrew bundle
├── Makefile                  # Convenience targets
├── README.md
├── LICENSE                   # MIT License
├── CHANGELOG.md
├── .gitignore
├── config/
│   ├── apps.yaml             # Homebrew cask applications
│   ├── cli.yaml              # CLI tools (Homebrew formulae)
│   ├── mas.yaml              # Mac App Store applications
│   ├── macos.yaml            # System preferences
│   └── xcode.yaml            # Xcode installation settings
├── profiles/
│   └── personal.yaml         # Personal machine profile
├── scripts/
│   ├── install_homebrew.sh   # Homebrew installer
│   ├── install_apps.sh       # Cask application installer
│   ├── install_cli.sh        # CLI tools + Oh My Zsh
│   ├── install_mas.sh        # Mac App Store installer (mas)
│   ├── install_xcode.sh      # Xcode .xip installer
│   ├── macos_defaults.sh     # System preferences
│   ├── validate.sh           # Validation report
│   ├── add_item.sh           # Add app/cli/mas to config
│   ├── logging.sh            # Structured logging
│   └── helpers.sh            # Shared utilities
├── logs/
│   └── bootstrap.log         # Generated at runtime
└── tests/
    └── run_tests.sh          # Test suite
```

---

## Configuration

All install targets are defined in `config/` and consumed by the installer scripts. **Do not hardcode applications in scripts** — edit YAML or use `--add-*` commands.

### `config/apps.yaml`

Homebrew cask applications:

```yaml
apps:
  - name: Google Chrome
    token: google-chrome
    description: Web browser
```

### `config/cli.yaml`

Homebrew formulae and special installers:

```yaml
cli:
  - name: GitHub CLI
    formula: gh
    description: GitHub command-line interface
    special: false

special:
  - name: Homebrew
    id: homebrew
  - name: Oh My Zsh
    id: oh-my-zsh
```

### `config/mas.yaml`

Mac App Store applications (installed via `mas`):

```yaml
mas_apps:
  - name: Things 3
    id: 904280696
    description: Task management application
```

### `config/macos.yaml`

System preferences applied via `defaults write`:

```yaml
preferences:
  dock_size:
    domain: com.apple.dock
    key: tilesize
    value: 48
    type: int
    handler: defaults
```

### `config/xcode.yaml`

Xcode installation behavior (archive path, naming, license acceptance):

```yaml
xcode:
  install_directory: /Applications
  naming_pattern: "Xcode_{version}.app"
  default_xip_search_paths:
    - ~/Downloads
    - ~/Desktop
```

### Regenerating `Brewfile`

The `Brewfile` is auto-generated from `apps.yaml` and `cli.yaml`:

```bash
make brewfile
# or
./bootstrap.sh --add-app "Name" --token token   # regenerates automatically
```

---

## Profiles

Profiles control which modules run during bootstrap. Defined in `profiles/<name>.yaml`.

### `personal` profile

```yaml
profile: personal
description: Personal development and productivity Mac configuration

modules:
  homebrew: true
  oh_my_zsh: true
  cli: true
  apps: true
  mas: true
  macos_preferences: true
  xcode: false

install_xcode: false
xcode_path: null
```

| Module | What it does |
|---|---|
| `homebrew` | Installs or updates Homebrew |
| `oh_my_zsh` | Installs Oh My Zsh (also runs when `cli` is enabled) |
| `cli` | Installs formulae from `cli.yaml` |
| `apps` | Installs casks from `apps.yaml` |
| `mas` | Installs Mac App Store apps from `mas.yaml` |
| `macos_preferences` | Applies settings from `macos.yaml` |
| `xcode` | Installs Xcode from `.xip` during bootstrap |

To enable Xcode during a full bootstrap, set `install_xcode: true` or `modules.xcode: true` in the profile.

### Creating a new profile

```bash
cp profiles/personal.yaml profiles/work.yaml
# Edit modules and options
./bootstrap.sh --profile work
```

---

## What Gets Installed

### Applications (Homebrew Cask)

| Application | Cask Token |
|---|---|
| Google Chrome | `google-chrome` |
| ChatGPT for macOS | `chatgpt` |
| Visual Studio Code | `visual-studio-code` |
| iTerm2 | `iterm2` |
| WhatsApp | `whatsapp` |
| Telegram | `telegram` |
| Logi Options+ | `logi-options+` |
| 1Password | `1password` |

### Mac App Store

| Application | MAS ID |
|---|---|
| Things 3 | `904280696` |

> MAS installation requires you to be signed into the Mac App Store. This tool never stores your Apple ID or password.

### CLI Tools

| Tool | Method | Formula / Source |
|---|---|---|
| Homebrew | Official installer | [brew.sh](https://brew.sh) |
| Oh My Zsh | Official installer | [ohmyz.sh](https://ohmyz.sh) |
| mas | Homebrew | `mas` |
| CocoaPods | Homebrew | `cocoapods` |
| GitHub CLI | Homebrew | `gh` |

---

## macOS Preferences Configured

| Preference | Setting | Config Key |
|---|---|---|
| Clock format | AM/PM | `time_format` |
| Menu bar | Show username | `menu_bar_username` |
| Dock size | ~30% (48px) | `dock_size` |
| Dock magnification | ~40% (64px) | `dock_magnification` |
| Stage Manager | Disable recent apps | `stage_manager_recent_apps` |
| Battery | Show percentage | `battery_percentage` |
| Sound | Always show icon in menu bar | `sound_icon_always` |
| Safari | Open with all windows from last session | `safari_restore_windows` |

Preferences are defined in `config/macos.yaml` and applied via `defaults write`. Dock and SystemUIServer are restarted automatically after changes.

> Some menu bar items (username, sound icon) may still require confirmation in **System Settings → Control Center** on newer macOS versions.

---

## Xcode Installation

Xcode is **not** installed from the Mac App Store. Use a `.xip` archive from Apple Developer.

### Workflow

1. Verify the `.xip` archive exists
2. Extract with `xip -x`
3. Detect version from filename (e.g. `Xcode_26.0.xip` → `26.0`)
4. Rename to `Xcode_<version>.app` (e.g. `Xcode_26.0.app`)
5. Move to `/Applications`
6. Run `sudo xcode-select -s` to select the installed Xcode
7. Accept the license with `sudo xcodebuild -license accept`
8. Run `sudo xcodebuild -runFirstLaunch`
9. Run `xcode-select --install` to ensure Command Line Tools are installed
10. Accept any remaining license agreements automatically
11. Re-select the full Xcode developer directory
12. Verify installation and print report

### Multiple versions

Several Xcode versions can coexist:

```
/Applications/Xcode_26.0.app
/Applications/Xcode_26.1.app
```

Switch the active developer directory:

```bash
sudo xcode-select -s /Applications/Xcode_26.0.app/Contents/Developer
```

### Commands

```bash
./bootstrap.sh --xcode-path ~/Downloads/Xcode_26.0.xip
./bootstrap.sh --install-xcode
```

Existing installations are never overwritten without confirmation (use `--force` to skip prompts).

### Command Line Tools and license acceptance

After Xcode is installed, the tool automatically:

- Runs `xcode-select --install` if developer tools are not yet available
- Waits for installation to complete (a system dialog may appear on first run)
- Accepts the license via `sudo xcodebuild -license accept`
- Re-selects the full Xcode app as the active developer directory

In non-interactive mode (`--noninteractive`), a headless install via `softwareupdate` is attempted first.

Configure behavior in `config/xcode.yaml`:

```yaml
xcode:
  install_command_line_tools: true
  command_line_tools_timeout_seconds: 1800
  use_headless_clt_install: true
```

---

## Validation

```bash
./bootstrap.sh --validate
```

Checks:

- **Applications** — installed via Homebrew cask or present in `/Applications`
- **MAS apps** — installed via `mas` or present in `/Applications`
- **CLI tools** — installed with version detection where available
- **macOS preferences** — applied via `defaults read`
- **Xcode** — installed versions and active developer directory

### Example output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validating Applications
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Google Chrome installed (cask: google-chrome)
  ✓ 1Password installed (cask: 1password)
  ✗ Telegram not installed (cask: telegram)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validation Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ Installed/Configured: 14
  ⚠ Warnings:              2
  ⚠ Manual action:         2
  ✗ Failed:                  1
```

| Symbol | Meaning |
|---|---|
| ✓ | Installed or configured correctly |
| ⚠ | Warning or requires manual action |
| ✗ | Failed / not installed |

---

## Logging

All operations are written to `logs/bootstrap.log` (gitignored) with structured levels:

| Level | Description |
|---|---|
| `[INFO]` | General progress |
| `[WARN]` | Non-fatal issues, dry-run notices |
| `[ERROR]` | Failures |
| `[SUCCESS]` | Completed operations |

Increase verbosity:

```bash
./bootstrap.sh --profile personal --log-level DEBUG
```

---

## Safety

| Guarantee | Details |
|---|---|
| Idempotent | Detects existing installs and skips them |
| No credentials | Never stores Apple ID, passwords, or certificates |
| Confirmation | Prompts before overwriting existing Xcode installations |
| Dry-run | `--dry-run` previews every operation |
| Force mode | `--force` / `--noninteractive` for automation |
| Changelog | `--add-*` commands append to `CHANGELOG.md` |
| Duplicate prevention | `--add-*` commands reject duplicate entries |

---

## Makefile Targets

```bash
make help         # Show available targets
make chmod        # Make scripts executable
make bootstrap    # Run bootstrap (PROFILE=personal)
make dry-run      # Preview bootstrap
make validate     # Run validation
make brewfile     # Regenerate Brewfile from config
make lint         # Run ShellCheck (requires: brew install shellcheck)
make test         # Run test suite
make install      # Alias for bootstrap
```

Override the profile:

```bash
make bootstrap PROFILE=personal
```

---

## Troubleshooting

### Homebrew not found after installation

Restart your terminal or run:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"        # Intel
```

### MAS app installation fails

- Ensure you are signed into the Mac App Store
- Run `mas signin` manually if needed (credentials are not stored by mac-bootstrap)
- Some apps require a purchase before `mas install` works

### GitHub CLI (`gh`) not authenticated

Bootstrap installs `gh` but does not configure authentication:

```bash
gh auth login
```

### 1Password not unlocking

Bootstrap installs the app only. Sign in and configure 1Password separately after install.

### Xcode extraction is slow

`.xip` extraction can take 30–60+ minutes. Monitor progress in `logs/bootstrap.log`.

### Xcode version not detected from filename

Use a filename matching `Xcode_<version>.xip`, e.g. `Xcode_26.0.xip`.

### Dock / preferences not applied

The bootstrap script restarts Dock and SystemUIServer automatically. For menu bar items, verify in **System Settings → Control Center**. A logout may be required for some settings.

### Cask installation fails

```bash
brew update
brew doctor
brew install --cask <token>
```

### ShellCheck warnings

```bash
brew install shellcheck
make lint
```

### Tests failing

```bash
make test
bash tests/run_tests.sh
```

---

## Future Extension Guide

### Phase 2: Developer Profile

Create `profiles/developer.yaml` for a full development environment:

```yaml
profile: developer
description: Full development environment

modules:
  homebrew: true
  oh_my_zsh: true
  cli: true
  apps: true
  mas: true
  macos_preferences: true
  xcode: true

install_xcode: true
```

Suggested additions (GitHub CLI is already included):

```bash
./bootstrap.sh --add-cli "jq"
./bootstrap.sh --add-cli "ripgrep"
./bootstrap.sh --add-cli "fzf"
./bootstrap.sh --add-app "Cursor" --token cursor
./bootstrap.sh --add-app "Docker" --token docker
```

Phase 2 ideas:

- Node.js (via `mise` or `nvm`)
- GitHub Copilot CLI
- Ollama
- Ruby + Bundler + Fastlane
- Android Studio
- `bat`, `eza`, `yq`
- SSH / Git configuration module
- Team-specific tooling

### Adding a new preference

Edit `config/macos.yaml`:

```yaml
preferences:
  my_preference:
    description: Description of the preference
    domain: com.apple.example
    key: SomeKey
    value: true
    type: bool
    handler: defaults
```

### Adding a custom install module

1. Create `scripts/install_<module>.sh`
2. Source `helpers.sh` for logging and utilities
3. Add a module toggle to the profile YAML
4. Wire the module into `bootstrap.sh`

### Extending via CLI (recommended)

```bash
./bootstrap.sh --add-app "App Name" --token cask-token
./bootstrap.sh --add-cli "formula-name"
./bootstrap.sh --add-mas "App Name" --id 123456789
```

Each command validates input, prevents duplicates, updates YAML, regenerates `Brewfile` (apps/CLI), and appends to `CHANGELOG.md`.

---

## Development

### Run tests

```bash
make test
```

The test suite covers config parsing, token validation, duplicate detection, dry-run mode, and Xcode version extraction.

### Lint scripts

```bash
make lint
```

Requires [ShellCheck](https://www.shellcheck.net/):

```bash
brew install shellcheck
```

### Contributing

1. Prefer `--add-*` commands or YAML edits in `config/`
2. Run `make test` and `make lint` before committing
3. Update `CHANGELOG.md` for configuration changes
4. Keep scripts compatible with Bash 3.2 (macOS default)

---

## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Juanjo Gramo
