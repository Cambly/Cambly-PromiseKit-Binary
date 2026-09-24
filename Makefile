# Builds PromiseKit products from upstream source as xcframeworks suitable for
# distribution via SwiftPM binaryTarget. Used by .github/workflows/build-and-release.yml
# but can also be invoked locally as a fallback.

VERSION ?=
# Allowlist VERSION (digits and dots only) before any recipe expands it. make
# splices $(VERSION) into recipes as text, and a command-line value is
# recursively expanded, so a crafted value (`$(shell …)`, `$$(…)`, a stray `"`)
# would execute; shell quoting can't prevent that. `$(value VERSION)` reads the
# raw text without expanding it, and stripping every allowed character must
# leave nothing behind.
VERSION_DISALLOWED := $(subst 0,,$(subst 1,,$(subst 2,,$(subst 3,,$(subst 4,,$(subst 5,,$(subst 6,,$(subst 7,,$(subst 8,,$(subst 9,,$(subst .,,$(value VERSION))))))))))))
ifneq ($(VERSION_DISALLOWED),)
$(error VERSION must contain only digits and dots, e.g. 6.22.1)
endif
# Default to SSH so local devs behind HTTPS proxies can clone. CI runners override
# to HTTPS via `make all UPSTREAM_REPO=https://github.com/mxcl/PromiseKit.git`.
UPSTREAM_REPO ?= git@github.com:mxcl/PromiseKit.git
PRODUCTS := PromiseKit
BUILD_DIR := build
# Lazy `=` so `make clean` doesn't require VERSION at parse time.
WORK_DIR = $(BUILD_DIR)/PromiseKit-$(VERSION)
ARTIFACTS_DIR := $(BUILD_DIR)/artifacts

.PHONY: all clean clone build-xcframeworks zip checksums release

all: build-xcframeworks zip checksums

clean:
	rm -rf $(BUILD_DIR)

clone:
	@test -n "$(VERSION)" || { echo "❌ VERSION is required, e.g. make all VERSION=6.22.1"; exit 1; }
	mkdir -p $(BUILD_DIR)
	test -d "$(WORK_DIR)" || git clone --depth 1 --branch "$(VERSION)" "$(UPSTREAM_REPO)" "$(WORK_DIR)"

build-xcframeworks: clone
	mkdir -p $(ARTIFACTS_DIR)
	@for product in $(PRODUCTS); do \
	  echo "🔨 Building $$product for iOS device + simulator..."; \
	  xcodebuild archive \
	    -project "$(WORK_DIR)/PromiseKit.xcodeproj" \
	    -scheme $$product \
	    -destination "generic/platform=iOS" \
	    -archivePath $(BUILD_DIR)/$$product-iOS-device.xcarchive \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    -quiet || exit 1; \
	  xcodebuild archive \
	    -project "$(WORK_DIR)/PromiseKit.xcodeproj" \
	    -scheme $$product \
	    -destination "generic/platform=iOS Simulator" \
	    -archivePath $(BUILD_DIR)/$$product-iOS-sim.xcarchive \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    -quiet || exit 1; \
	  echo "📦 Creating $$product.xcframework..."; \
	  rm -rf $(ARTIFACTS_DIR)/$$product.xcframework; \
	  xcodebuild -create-xcframework \
	    -framework $(BUILD_DIR)/$$product-iOS-device.xcarchive/Products/Library/Frameworks/$$product.framework \
	    -framework $(BUILD_DIR)/$$product-iOS-sim.xcarchive/Products/Library/Frameworks/$$product.framework \
	    -output $(ARTIFACTS_DIR)/$$product.xcframework || exit 1; \
	done

zip: build-xcframeworks
	@cd $(ARTIFACTS_DIR) && for product in $(PRODUCTS); do \
	  echo "🗜  Zipping $$product.xcframework..."; \
	  rm -f $$product.xcframework.zip; \
	  zip -qry $$product.xcframework.zip $$product.xcframework; \
	done

checksums: zip
	@echo ""
	@echo "=== sha256 checksums ==="
	@cd $(ARTIFACTS_DIR) && for product in $(PRODUCTS); do \
	  sha=$$(swift package compute-checksum $$product.xcframework.zip); \
	  echo "$$product: $$sha"; \
	done

# Convenience target for manual release. CI uses build-and-release.yml directly.
release: clean all
	@echo "Now upload $(ARTIFACTS_DIR)/*.xcframework.zip to GitHub release $(VERSION)"
	@echo "and update Package.swift checksums by hand, then commit + tag."
