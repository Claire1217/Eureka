#!/bin/bash
# Developer build: uses persistent "ThoughtCapture Dev" certificate
# so Accessibility permission survives across rebuilds.
# Run setup_cert.sh first to create the certificate.
set -e
cd "$(dirname "$0")"

APP="ThoughtCapture.app"
BINARY="$APP/Contents/MacOS/ThoughtCapture"
SIGNING_ID="ThoughtCapture Dev"

# Verify signing identity exists
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGNING_ID"; then
    echo "ERROR: Signing identity '$SIGNING_ID' not found."
    echo "Run ./setup_cert.sh first to create the code signing certificate."
    exit 1
fi

# Create app bundle structure
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.thoughtcapture.app</string>
    <key>CFBundleName</key>
    <string>ThoughtCapture</string>
    <key>CFBundleExecutable</key>
    <string>ThoughtCapture</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>ThoughtCapture needs Automation access to save thoughts to Apple Notes.</string>
</dict>
</plist>
EOF

cp -f bubbleicon.png "$APP/Contents/Resources/" 2>/dev/null || true

echo "Compiling..."
swiftc Sources/*.swift \
    -o "$BINARY" \
    -framework Cocoa \
    -framework Carbon \
    -framework ApplicationServices \
    -framework CoreGraphics \
    -framework WebKit

echo "Signing with '$SIGNING_ID'..."
codesign --force --sign "$SIGNING_ID" "$APP"

echo ""
echo "✓ Built $APP (signed with $SIGNING_ID)"
echo "  Accessibility permission will persist across rebuilds."
echo ""
echo "To install: ./deploy.sh"
