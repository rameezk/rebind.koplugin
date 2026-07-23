PLUGIN := rebind.koplugin
DIST := dist
STAGE := $(DIST)/$(PLUGIN)

RUNTIME := _meta.lua main.lua README.md LICENSE CHANGELOG.md

.DEFAULT_GOAL := help

.PHONY: help test package clean

help:
	@echo "Rebind — available targets:"
	@echo "  make test     Run the test suite"
	@echo "  make package  Build $(DIST)/$(PLUGIN).zip for distribution"
	@echo "  make clean    Remove build artifacts"

test:
	./tests/run.sh

package: test clean
	mkdir -p $(STAGE)
	cp $(RUNTIME) $(STAGE)/
	cp -R rebind $(STAGE)/
	cd $(DIST) && zip -r -X $(PLUGIN).zip $(PLUGIN) >/dev/null
	@echo "Built $(DIST)/$(PLUGIN).zip"

clean:
	rm -rf $(DIST)
