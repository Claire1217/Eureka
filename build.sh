#!/bin/bash
# Developer build: uses persistent "Eureka Dev" certificate
# so Accessibility permission survives across rebuilds.
# Run setup_cert.sh first to create the certificate.
set -e
cd "$(dirname "$0")"
source ./common.sh

APP="Eureka.app"
BINARY="$APP/Contents/MacOS/Eureka"
SIGNING_ID="Eureka Dev"

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGNING_ID"; then
    echo "ERROR: Signing identity '$SIGNING_ID' not found."
    echo "Run ./setup_cert.sh first to create the code signing certificate."
    exit 1
fi

write_plist "$APP" "$VERSION_DEFAULT"

echo "Compiling..."
swift build -c debug
cp .build/debug/Eureka "$BINARY"

echo "Signing with '$SIGNING_ID'..."
codesign --force --sign "$SIGNING_ID" "$APP"

echo ""
echo "✓ Built $APP (signed with $SIGNING_ID)"
echo "  Accessibility permission will persist across rebuilds."
echo ""
echo "To install: ./deploy.sh"
