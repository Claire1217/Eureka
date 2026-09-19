#!/bin/bash
# Build Eureka.app and package as .zip for GitHub release
set -e
cd "$(dirname "$0")"
source ./common.sh

VERSION="${1:-$VERSION_DEFAULT}"
APP="Eureka.app"
BINARY="$APP/Contents/MacOS/Eureka"

echo "=== Building Eureka v$VERSION ==="

rm -rf "$APP"
write_plist "$APP" "$VERSION"

# Universal binary with an explicit deployment target. Without -target, swiftc
# builds for the host arch and host OS version only, so a release built on an
# Apple Silicon Mac would not launch on Intel Macs or older macOS versions.
echo "Compiling (arm64 + x86_64, macOS $MIN_MACOS+)..."
BUILD_TMP="$(mktemp -d)"
trap 'rm -rf "$BUILD_TMP"' EXIT
for ARCH in arm64 x86_64; do
    swiftc Sources/*.swift -O \
        -target "$ARCH-apple-macos$MIN_MACOS" \
        -o "$BUILD_TMP/Eureka.$ARCH" "${FRAMEWORKS[@]}"
done
lipo -create -output "$BINARY" "$BUILD_TMP/Eureka.arm64" "$BUILD_TMP/Eureka.x86_64"
lipo -info "$BINARY"

echo "Signing..."
codesign --force --sign - "$APP"

echo "Packaging..."
rm -f "Eureka-v${VERSION}.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "Eureka-v${VERSION}.zip"

SIZE=$(du -h "Eureka-v${VERSION}.zip" | cut -f1)
echo ""
echo "=== Done ==="
echo "  Eureka-v${VERSION}.zip ($SIZE)"
