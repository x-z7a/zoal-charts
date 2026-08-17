SHELL := /bin/bash

# Nothing here is worth running in parallel: package writes the tree that
# install and archive both read.
.NOTPARALLEL:

ROOT_DIR := $(CURDIR)
DIST_DIR ?= $(ROOT_DIR)/dist
RELEASE_DIR := $(DIST_DIR)/zoal-charts
XPLANE_DIR ?= $(HOME)/X-Plane 12
LOCAL_PLUGIN_DIR ?= $(XPLANE_DIR)/Resources/plugins/zoal-charts

SKYSCRIPT_VERSION := $(shell tr -d '[:space:]' < $(ROOT_DIR)/scripts/skyscript-version.txt)

.PHONY: help package install archive check clean distclean
.DEFAULT_GOAL := help

help:
	@echo "zoal-charts - the in-sim Navigraph panel for X-Plane 12"
	@echo
	@echo "  package     assemble dist/zoal-charts from SkyScript $(SKYSCRIPT_VERSION)"
	@echo "  install     package, then install into $(LOCAL_PLUGIN_DIR)"
	@echo "  archive     package, then zip it for a release"
	@echo "  check       validate every apps/*/manifest.yaml"
	@echo "  clean       remove dist/"
	@echo "  distclean   remove dist/ and the downloaded SkyScript cache"

package:
	@scripts/build-release.sh

# X-Plane reads the plugin folder once at startup, so this cannot be applied to
# a running sim. Restart it, or use Plugins -> SkyScript -> Reload configuration
# for manifest-only edits.
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
	@echo "In X-Plane: Plugins -> SkyScript -> Apps -> Navigraph Charts"

archive: package
	@cd "$(DIST_DIR)" && zip -qr "zoal-charts-$(SKYSCRIPT_VERSION).zip" zoal-charts
	@echo "Wrote $(DIST_DIR)/zoal-charts-$(SKYSCRIPT_VERSION).zip"

check:
	@scripts/check-manifests.py

clean:
	@rm -rf "$(DIST_DIR)"

distclean: clean
	@rm -rf "$(ROOT_DIR)/.cache"
