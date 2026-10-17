# Backpressure for humans and agents: `make check` must pass before every push.
#
#   make bootstrap       install tools and enable git hooks
#   make fix             auto-format
#   make check           lint + build (warnings are errors) + tests + coverage gate
#   make test-linux      run the tests in a Linux container (needs Docker)
#   make generate        regenerate Sources/OpenRouterAPI from openapi/openapi.json
#   make generate-fetch  download the latest spec first, then regenerate
#   make release VERSION=x.y.z  cut a release (see wiki/concepts/releasing.md)

SOURCES := Sources/OpenRouter Tests Package.swift
MIN_COVERAGE ?= 90
SWIFT_IMAGE ?= swift:6.2-noble

.PHONY: bootstrap fix format lint wiki-lint build test coverage check test-linux generate generate-fetch release clean

bootstrap:
	@command -v swiftlint >/dev/null || brew install swiftlint
	git config core.hooksPath .githooks

fix format:
	swift format format --in-place --recursive --parallel $(SOURCES)
	swiftlint lint --fix --quiet

lint: wiki-lint
	swift format lint --strict --recursive --parallel $(SOURCES)
	swiftlint lint --strict --quiet

wiki-lint:
	python3 -I Scripts/wiki-lint.py

build:
	swift build

test:
	swift test --parallel --enable-code-coverage

coverage: test
	python3 -I Scripts/check-coverage.py "$$(swift test --show-codecov-path)" $(MIN_COVERAGE) Sources/OpenRouter

check: lint build coverage

# Build artefacts live in a named volume, so only the first run is slow.
# Needs ~6 GB of Docker memory to compile the generated target.
test-linux:
	docker run --rm -v "$(CURDIR)":/src -v swift-openrouter-linux-build:/build -w /src $(SWIFT_IMAGE) \
		swift test --parallel --scratch-path /build

generate:
	Scripts/generate.sh

generate-fetch:
	Scripts/generate.sh --fetch

release:
	@test -n "$(VERSION)" || { echo "usage: make release VERSION=x.y.z"; exit 1; }
	Scripts/release.sh $(VERSION)

clean:
	swift package clean
