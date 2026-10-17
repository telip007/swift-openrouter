#!/usr/bin/env bash
# Cuts a release: Scripts/release.sh 0.2.0
#
# Moves the CHANGELOG's Unreleased section under the new version, bumps the
# version in the User-Agent and README, runs `make check`, commits, tags and
# pushes. The Release workflow then publishes the GitHub release.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

version="${1:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: $0 MAJOR.MINOR.PATCH" >&2; exit 1; }
[[ "$(git branch --show-current)" == "main" ]] || { echo "release from main" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree is not clean" >&2; exit 1; }
git fetch --quiet origin main --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "main is not in sync with origin/main" >&2; exit 1; }
! git rev-parse -q --verify "refs/tags/$version" >/dev/null || { echo "tag $version exists" >&2; exit 1; }

python3 -I - "$version" <<'PY'
import datetime, re, sys
version = sys.argv[1]
today = datetime.date.today().isoformat()

changelog = open("CHANGELOG.md").read()
unreleased = re.search(r"## \[Unreleased\]\n(.*?)(?=\n## \[|\Z)", changelog, re.S)
if not unreleased or not unreleased.group(1).strip():
    sys.exit("CHANGELOG.md: the Unreleased section is empty")
changelog = changelog.replace("## [Unreleased]\n", f"## [Unreleased]\n\n## [{version}] - {today}\n", 1)
open("CHANGELOG.md", "w").write(changelog)

path = "Sources/OpenRouter/Middleware/HeadersMiddleware.swift"
source = open(path).read()
source, count = re.subn(r'"swift-openrouter/[0-9.]+"', f'"swift-openrouter/{version}"', source)
assert count == 1, "User-Agent version not found"
open(path, "w").write(source)

readme = open("README.md").read()
readme = re.sub(r'(swift-openrouter", )(branch: "main"|from: "[0-9.]+")', rf'\1from: "{version}"', readme)
open("README.md", "w").write(readme)
PY

make check
git add CHANGELOG.md README.md Sources/OpenRouter/Middleware/HeadersMiddleware.swift
git commit --quiet -m "Release $version"
git tag --annotate "$version" --message "swift-openrouter $version"
git push --quiet origin main "$version"
echo "Pushed $version. The Release workflow publishes the GitHub release."
