#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xattr -cr "$ROOT/Sources" "$ROOT/Xcode" "$ROOT/assets" "$ROOT/Packaging" 2>/dev/null || true

command -v xcodegen >/dev/null
xcodegen generate
printf 'Generated %s\n' "$ROOT/Sorted.xcodeproj"
