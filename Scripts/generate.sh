#!/usr/bin/env bash
# Regenerates Sources/OpenRouterAPI/Generated from openapi/openapi.json.
#
#   Scripts/generate.sh           # regenerate from the committed spec
#   Scripts/generate.sh --fetch   # download the latest spec first
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$ROOT/openapi/openapi.json"
SPEC_URL="https://openrouter.ai/openapi.json"
OUT="$ROOT/Sources/OpenRouterAPI/Generated"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ "${1:-}" == "--fetch" ]]; then
    echo "→ Fetching $SPEC_URL"
    curl --fail --silent --show-error --location "$SPEC_URL" --output "$WORK/openapi.json"
    # Upstream examples contain full-length sample API keys. They aren't real,
    # but GitHub push protection rejects them, so mask them the way the spec
    # masks keys elsewhere (sk-or-v1-0e6...1c96).
    python3 -I -c 'import re, sys; print(re.sub(r"sk-or-v1-([0-9a-f]{3})[0-9a-f]{57}([0-9a-f]{4})", r"sk-or-v1-\1...\2", sys.stdin.read()), end="")' \
        < "$WORK/openapi.json" > "$WORK/masked.json"
    python3 -I -m json.tool --sort-keys "$WORK/masked.json" > "$SPEC"
fi

echo "→ Patching spec for swift-openapi-generator"
python3 -I "$ROOT/Scripts/patch_openapi.py" "$SPEC" "$WORK/openapi.json"

echo "→ Generating Swift sources"
mkdir -p "$OUT"
find "$OUT" -name '*.swift' -delete  # drop files from a previous, wider filter
swift run --quiet --package-path "$ROOT/Tools" swift-openapi-generator generate \
    "$WORK/openapi.json" \
    --config "$ROOT/openapi/generator-config.yaml" \
    --output-directory "$OUT" > "$WORK/generator.log" 2>&1 || {
        cat "$WORK/generator.log" >&2
        exit 1
    }

# The upstream spec produces a handful of known, harmless warnings
# (unsupported `null` schemas, a typo in one `required` list).
warnings=$(grep -c "warning:" "$WORK/generator.log" || true)
lines=$(cat "$OUT"/*.swift | wc -l | tr -d ' ')
echo "✓ Generated $lines lines into ${OUT#"$ROOT"/} ($warnings known generator warnings)"
