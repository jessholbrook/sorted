#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v xcodegen >/dev/null
xcodegen generate
printf 'Generated %s\n' "$ROOT/Sorted.xcodeproj"
