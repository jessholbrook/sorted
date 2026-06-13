#!/bin/sh

set -eu

export HOME="$PWD/.local-home"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
mkdir -p "$HOME" "$CLANG_MODULE_CACHE_PATH"

if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
fi

exec swift run Sorted
