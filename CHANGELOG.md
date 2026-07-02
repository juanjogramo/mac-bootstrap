# Changelog

All notable changes to mac-bootstrap configuration are documented here.

## [2026-06-30]

- Add --uninstall to remove mac-bootstrap while keeping installed apps and tools
- Configure Homebrew PATH using official post-install shellenv commands
- Added Dock configuration module (dockutil) with default remove/add lists in `config/dock.yaml`
- Added keyboard input source module for Spanish - ISO (87) and ABC (252) layouts
- Added CLI tool: dockutil (formula: dockutil)
- Prompt for sudo with retries; continue bootstrap when individual steps fail
- Added Homebrew-style one-line installer (`install.sh`) and `mac-bootstrap` CLI wrapper
- Added application: 1Password (token: 1password)
- Added CLI tool: GitHub CLI (formula: gh)
- Initial mac-bootstrap project setup
