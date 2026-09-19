#!/bin/bash
# Build and install Eureka to /Applications
set -e
cd "$(dirname "$0")"
source ./common.sh

DEV_CERT="Eureka Dev"

echo "=== Building ==="
swiftc Sources/*.swift -o Eureka "${FRAMEWORKS[@]}"

echo "=== Stopping old instances ==="
killall Eureka 2>/dev/null || true
killall ThoughtCapture 2>/dev/null || true
sleep 0.5

echo "=== Deploying ==="
rm -rf /Applications/ThoughtCapture.app
write_plist /Applications/Eureka.app "$VERSION_DEFAULT"
cp Eureka /Applications/Eureka.app/Contents/MacOS/Eureka

echo "=== Signing ==="
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$DEV_CERT"; then
    codesign --force --sign "$DEV_CERT" /Applications/Eureka.app
    echo "Signed with '$DEV_CERT' (dev certificate)"
else
    codesign --force --sign - /Applications/Eureka.app
    echo "Signed with ad-hoc signature"
fi

echo "=== Launching ==="
open /Applications/Eureka.app
sleep 1

echo ""
echo "✓ Installed to /Applications/Eureka.app"
echo ""
echo "Next step: grant Accessibility permission"
echo "  System Settings → Privacy & Security → Accessibility"
echo "  → enable Eureka"
