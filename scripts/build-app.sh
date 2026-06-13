#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Sorted"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_VERSION="${BUILD_VERSION:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
APP_DIR="$ROOT/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
ICONSET_DIR="$ROOT/.build/AppIcon.iconset"
ICON_SOURCE="$ROOT/assets/sorted-icon-source.png"

export HOME="${HOME_OVERRIDE:-$ROOT/.local-home}"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
if [ -z "${SDKROOT:-}" ] && [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
fi

mkdir -p "$HOME" "$CLANG_MODULE_CACHE_PATH" "$ROOT/dist"
swift build -c release --product "$APP_NAME"

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources" "$ICONSET_DIR"

cp "$ROOT/.build/release/$APP_NAME" "$CONTENTS_DIR/MacOS/$APP_NAME"
sed \
    -e "s/__MARKETING_VERSION__/$MARKETING_VERSION/g" \
    -e "s/__BUILD_VERSION__/$BUILD_VERSION/g" \
    "$ROOT/Packaging/Info.plist" > "$CONTENTS_DIR/Info.plist"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$CONTENTS_DIR/Resources/AppIcon.icns"
xattr -cr "$APP_DIR"

if [ "$SIGNING_IDENTITY" = "-" ]; then
    codesign \
        --force \
        --entitlements "$ROOT/Packaging/Sorted.entitlements" \
        --sign - \
        "$APP_DIR"
else
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --entitlements "$ROOT/Packaging/Sorted.entitlements" \
        --sign "$SIGNING_IDENTITY" \
        "$APP_DIR"
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
printf 'Built %s\n' "$APP_DIR"
