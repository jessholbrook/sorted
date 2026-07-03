#!/bin/sh

set -eu

# SORTED_BUILD_WORKAROUNDS=1 opts into fixes for a machine whose Command Line
# Tools SDK does not match the installed compiler: a pinned SDK plus a
# repo-local home and module cache. Normal machines should not need this.
if [ "${SORTED_BUILD_WORKAROUNDS:-0}" = "1" ]; then
    export HOME="$PWD/.local-home"
    export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
    mkdir -p "$HOME" "$CLANG_MODULE_CACHE_PATH"

    if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]; then
        export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
    fi
fi

exec swift run Sorted
