SHELL := /bin/bash

# Nothing here is worth running in parallel: package reads what plugin writes,
# and install and archive both read what package writes.
.NOTPARALLEL:

ROOT_DIR := $(CURDIR)
BUILD_DIR ?= $(ROOT_DIR)/build-plugin
DIST_DIR ?= $(ROOT_DIR)/dist
RELEASE_DIR := $(DIST_DIR)/zoal-charts
XPLANE_DIR ?= $(HOME)/X-Plane 12
LOCAL_PLUGIN_DIR ?= $(XPLANE_DIR)/Resources/plugins/zoal-charts
BUILD_TYPE ?= Release
VERSION ?= 0.0.0-dev

SKYSCRIPT_VERSION := $(shell tr -d '[:space:]' < $(ROOT_DIR)/scripts/skyscript-version.txt)

.PHONY: help deps plugin package install archive check lint clean distclean
.DEFAULT_GOAL := help

help:
	@echo "zoal-charts - the in-sim Navigraph panel for X-Plane 12"
	@echo
	@echo "  deps        fetch the X-Plane SDK and SkyScript $(SKYSCRIPT_VERSION)"
	@echo "  plugin      build zoal-charts.xpl for this platform"
	@echo "  package     assemble dist/zoal-charts"
	@echo "  install     package, then install into $(LOCAL_PLUGIN_DIR)"
	@echo "  archive     package, then zip it for a release"
	@echo "  check       validate every apps/*/manifest.yaml"
	@echo "  lint        shellcheck the scripts and ruff the Python"
	@echo "  clean       remove build-plugin/ and dist/"
	@echo "  distclean   also remove the downloaded dependency cache"
	@echo
	@echo "One platform can only be built on itself, so a local package covers"
	@echo "this machine only. CI builds all three."

deps:
	@scripts/ensure-deps.sh

plugin: deps
	@cmake -S "$(ROOT_DIR)" -B "$(BUILD_DIR)" \
		-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
		-DZOAL_CHARTS_VERSION="$(VERSION)"
	@cmake --build "$(BUILD_DIR)" --config $(BUILD_TYPE)

package: plugin
	@scripts/build-release.sh

# X-Plane reads the plugin folder once at startup, so this cannot be applied to
# a running sim. Restart it, or use Plugins -> zoal-charts -> Reload
# configuration for manifest-only edits.
install: package
	@if [ ! -d "$(XPLANE_DIR)" ]; then \
		echo "X-Plane not found at $(XPLANE_DIR)." >&2; \
		echo "Set XPLANE_DIR=/path/to/X-Plane\\ 12 and run again." >&2; \
		exit 1; \
	fi
	@rm -rf "$(LOCAL_PLUGIN_DIR)"
	@mkdir -p "$(dir $(LOCAL_PLUGIN_DIR))"
	@cp -R "$(RELEASE_DIR)" "$(LOCAL_PLUGIN_DIR)"
	@echo "Installed to $(LOCAL_PLUGIN_DIR)"
	@echo "In X-Plane: Plugins -> zoal-charts -> Navigraph Charts"

archive: package
	@cd "$(DIST_DIR)" && zip -qr "zoal-charts-$(VERSION).zip" zoal-charts
	@echo "Wrote $(DIST_DIR)/zoal-charts-$(VERSION).zip"

check:
	@scripts/check-manifests.py

# Neither tool is a dependency worth installing globally to run twice a month,
# so uvx runs them from a cache when they are not already on PATH.
RUFF := $(shell command -v ruff 2>/dev/null || echo "uvx ruff")
SHELLCHECK := $(shell command -v shellcheck 2>/dev/null || echo "uvx --from shellcheck-py shellcheck")

lint:
	@$(SHELLCHECK) scripts/*.sh
	@$(RUFF) check scripts/
	@$(RUFF) format --check scripts/
	@echo "Lint clean."

clean:
	@rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"

distclean: clean
	@rm -rf "$(ROOT_DIR)/.cache"
