.PHONY: help bootstrap dry-run validate brewfile lint test install chmod

BOOTSTRAP := ./bootstrap.sh
PROFILE ?= personal

help:
	@echo "mac-bootstrap — available targets:"
	@echo ""
	@echo "  make bootstrap    Run full bootstrap (PROFILE=personal)"
	@echo "  make dry-run      Preview bootstrap without changes"
	@echo "  make validate     Validate installation state"
	@echo "  make brewfile     Regenerate Brewfile from config"
	@echo "  make lint         Run ShellCheck on all scripts"
	@echo "  make test         Run test suite"
	@echo "  make chmod        Make scripts executable"
	@echo "  make install      Alias for bootstrap"

chmod:
	chmod +x bootstrap.sh scripts/*.sh

bootstrap: chmod
	$(BOOTSTRAP) --profile $(PROFILE)

dry-run: chmod
	$(BOOTSTRAP) --profile $(PROFILE) --dry-run

validate: chmod
	$(BOOTSTRAP) --validate

brewfile: chmod
	@source scripts/helpers.sh && regenerate_brewfile

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Install shellcheck: brew install shellcheck"; exit 1; }
	shellcheck bootstrap.sh scripts/*.sh

test: chmod
	./tests/run_tests.sh

install: bootstrap
