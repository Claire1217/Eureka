#!/bin/bash
# Shared by build.sh / deploy.sh / release.sh — single source for the version,
# Info.plist and compiler flags. Source it; don't run it.

VERSION_DEFAULT="$(tr -d '[:space:]' < "$(dirname "${BASH_SOURCE[0]}")/VERSION")"
MIN_MACOS="12.0"
FRAMEWORKS=(-framework Cocoa -framework Carbon -framework ApplicationServices
            -framework CoreGraphics -framework WebKit)

# write_plist <App.app> <version>
write_plist() {
    local app="$1" version="$2"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cat > "$app/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.eureka.app</string>
    <key>CFBundleName</key>
    <string>Eureka</string>
    <key>CFBundleExecutable</key>
    <string>Eureka</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Eureka reads the current page URL from your browser and, if you choose Apple Notes, saves thoughts there.</string>
</dict>
</plist>
PLIST
}
