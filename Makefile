PLUGIN := rebind.koplugin
DIST := dist
STAGE := $(DIST)/$(PLUGIN)

RUNTIME := _meta.lua main.lua README.md LICENSE CHANGELOG.md

.DEFAULT_GOAL := help

.PHONY: help test emulator emulator-update emulator-token package clean

help:
	@echo "Rebind — available targets:"
	@echo "  make test             Run the test suite"
	@echo "  make emulator         Launch the KOReader macOS emulator with Rebind loaded"
	@echo "  make emulator-update  Re-download the latest KOReader macOS build, then launch"
	@echo "  make emulator-token   Save a Hardcover API token for live lookups (prompted)"
	@echo "  make package          Build $(DIST)/$(PLUGIN).zip for distribution"
	@echo "  make clean            Remove build artifacts"

test:
	./tests/run.sh

emulator:
	./tools/emulator.sh

emulator-update:
	./tools/emulator.sh --update

emulator-token:
	./tools/emulator.sh --set-token

package: test clean
	mkdir -p $(STAGE)
	cp $(RUNTIME) $(STAGE)/
	cp -R rebind $(STAGE)/
	cd $(DIST) && zip -r -X $(PLUGIN).zip $(PLUGIN) >/dev/null
	@echo "Built $(DIST)/$(PLUGIN).zip"

clean:
	rm -rf $(DIST)
