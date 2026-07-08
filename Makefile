# Porto iOS — build/test orchestration.
# Requires full Xcode. If xcode-select points at CommandLineTools, DEVELOPER_DIR overrides it.

export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

SCHEME       = Porto
DESTINATION ?= platform=iOS Simulator,name=iPhone 17
PROJECT      = Porto.xcodeproj

.PHONY: generate build test test-packages fixtures clean

## Regenerate the Xcode project from project.yml.
generate:
	xcodegen generate

## Build the app for the simulator (signing disabled for CI/headless).
build: generate
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		CODE_SIGNING_ALLOWED=NO \
		-quiet

## Run app-target tests on the simulator.
test: generate
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		CODE_SIGNING_ALLOWED=NO

## Fast per-package unit tests via SwiftPM (no simulator needed).
test-packages:
	cd Packages/PortoKit && swift test
	cd Packages/PortoDesign && swift test

## Capture live GET responses from the local backend as test fixtures.
fixtures:
	./Scripts/make-fixtures.sh

clean:
	rm -rf $(PROJECT) DerivedData .build
	find Packages -name .build -type d -prune -exec rm -rf {} +
