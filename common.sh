#!/bin/bash
# Shared by build.sh / deploy.sh / release.sh — single source for the version,
# Info.plist and compiler flags. Source it; don't run it.

VERSION_DEFAULT="$(tr -d '[:space:]' < "$(dirname "${BASH_SOURCE[0]}")/VERSION")"
MIN_MACOS="12.0"
FRAMEWORKS=(-framework Cocoa -framework Carbon -framework ApplicationServices
            -framework CoreGraphics -framework WebKit)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# make_icon <Resources dir> — builds AppIcon.icns with Apple's own tools (every size macOS asks
# for, including 16 and 32 pt), and falls back to the committed .icns if they are missing.
make_icon() {
    local dest="$1" src="$ROOT_DIR/Resources/AppIcon.png" iconset
    if command -v iconutil >/dev/null && command -v sips >/dev/null; then
        iconset="$(mktemp -d)/AppIcon.iconset"
        mkdir -p "$iconset"
        if (
            for s in 16 32 128 256 512; do
                sips -z "$s" "$s" "$src" --out "$iconset/icon_${s}x${s}.png" >/dev/null
                sips -z "$((s * 2))" "$((s * 2))" "$src" --out "$iconset/icon_${s}x${s}@2x.png" >/dev/null
            done
            iconutil -c icns "$iconset" -o "$dest/AppIcon.icns"
        ); then
            rm -rf "$(dirname "$iconset")"
            return 0
        fi
        rm -rf "$(dirname "$iconset")"
    fi
    cp -f "$ROOT_DIR/Resources/AppIcon.icns" "$dest/AppIcon.icns"
}

# refresh_icon <App.app> — Finder, Launchpad and the Dock cache icons per app; without this an
# updated app can keep showing the generic placeholder.
refresh_icon() {
    local lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    touch "$1"
    [ -x "$lsregister" ] && "$lsregister" -f "$1" >/dev/null 2>&1 || true
}

# write_plist <App.app> <version>
write_plist() {
    local app="$1" version="$2"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    make_icon "$app/Contents/Resources"
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <key>NSAppleEventsUsageDescription</key>
    <string>Eureka reads the current page URL from your browser and, if you choose Apple Notes, saves thoughts there.</string>
</dict>
</plist>
PLIST
}
