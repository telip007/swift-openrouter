#!/usr/bin/env python3
"""Normalise OpenRouter's Speakeasy-flavoured OpenAPI document so that
apple/swift-openapi-generator can consume it and the output compiles.

Usage: patch_openapi.py <in.json> <out.json>
"""

import json
import sys

REF_PREFIX = "#/components/schemas/"

# Component schemas that accept `null`, collected before patching so that
# `$ref`s to them can be recognised as nullable too.
NULLABLE_COMPONENTS = set()


def is_null_schema(schema):
    return isinstance(schema, dict) and schema.get("type") == "null" and len(schema) <= 2


def is_nullable(schema):
    if not isinstance(schema, dict):
        return False
    ref = schema.get("$ref", "")
    if ref.startswith(REF_PREFIX) and ref[len(REF_PREFIX):] in NULLABLE_COMPONENTS:
        return True
    if schema.get("nullable") is True or None in schema.get("enum", []):
        return True
    if isinstance(schema.get("type"), list) and "null" in schema["type"]:
        return True
    return any(
        is_null_schema(b) for key in ("anyOf", "oneOf") for b in schema.get(key, [])
    )


def patch(node):
    if isinstance(node, list):
        return [patch(item) for item in node]
    if not isinstance(node, dict):
        return node

    # 0. Steps 3 and 4 below erase `null` from schemas. A property that is
    #    required *and* nullable must therefore become optional, otherwise
    #    decoding `"field": null` fails.
    if isinstance(node.get("properties"), dict) and isinstance(node.get("required"), list):
        nullable = {k for k, v in node["properties"].items() if is_nullable(v)}
        node["required"] = [r for r in node["required"] if r not in nullable]
        if not node["required"]:
            del node["required"]

    # 1a. Speakeasy "open" enums: the server may add values at any time, so
    #     a closed Swift enum would fail to decode tomorrow's responses.
    if node.get("x-speakeasy-unknown-values") == "allow" and "enum" in node:
        del node["enum"]

    # 1b. Vendor extensions are meaningless to us and occasionally land in
    #    places that break strict parsers (e.g. discriminator.mapping).
    node = {k: v for k, v in node.items() if not k.startswith("x-speakeasy-")}

    # 2. OpenAPI 3.0 boolean exclusive bounds inside a 3.1 document.
    for flag, bound in (("exclusiveMinimum", "minimum"), ("exclusiveMaximum", "maximum")):
        if node.get(flag) is True and bound in node:
            node[flag] = node.pop(bound)
        elif node.get(flag) is False:
            node.pop(flag)

    # 3. `{type: null}` branches in anyOf/oneOf are skipped by the generator
    #    but still referenced, which produces code that doesn't compile.
    #    Nullability is expressed through Swift optionals anyway.
    for key in ("anyOf", "oneOf"):
        if isinstance(node.get(key), list):
            branches = [b for b in node[key] if not is_null_schema(b)]
            # Drop duplicate branches (the spec has a few).
            unique = []
            for branch in branches:
                if branch not in unique:
                    unique.append(branch)
            if len(unique) == 1 and len(node) == 1:
                node = dict(unique[0])
            else:
                node[key] = unique

    # 4. `type: [X, "null"]` -> `type: X` for the same reason, plus the
    #    OpenAPI 3.0 `nullable` keyword, which 3.1 parsers reject.
    if isinstance(node.get("type"), list):
        types = [t for t in node["type"] if t != "null"]
        node["type"] = types[0] if len(types) == 1 else types
    if isinstance(node.get("enum"), list) and None in node["enum"]:
        node["enum"] = [e for e in node["enum"] if e is not None]
    if isinstance(node.get("nullable"), bool):  # not a property named "nullable"
        del node["nullable"]

    return {k: patch(v) for k, v in node.items()}


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src) as f:
        doc = json.load(f)
    NULLABLE_COMPONENTS.update(
        name for name, schema in doc["components"]["schemas"].items() if is_nullable(schema)
    )
    doc = patch(doc)
    with open(dst, "w") as f:
        json.dump(doc, f, indent=2, sort_keys=True)
        f.write("\n")


if __name__ == "__main__":
    main()
