# Backpressure for humans and agents: `make check` must pass before every push.
#
#   make bootstrap       install tools and enable git hooks
#   make fix             auto-format
#   make check           lint + build (warnings are errors) + tests + coverage gate
#   make test-linux      run the tests in a Linux container (needs Docker)
#   make generate        regenerate Sources/OpenRouterAPI from openapi/openapi.json
#   make generate-fetch  download the latest spec first, then regenerate

SOURCES := Sources/OpenRouter Tests Package.swift
MIN_COVERAGE ?= 90
SWIFT_IMAGE ?= swift:6.2-noble

.PHONY: bootstrap fix format lint wiki-lint build test coverage check test-linux generate generate-fetch clean

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

test-linux:
	docker run --rm -v "$(CURDIR)":/src:ro -w /src $(SWIFT_IMAGE) \
		swift test --parallel --scratch-path /tmp/build

generate:
	Scripts/generate.sh

generate-fetch:
	Scripts/generate.sh --fetch

clean:
	swift package clean
