#!/bin/bash
# Eureka one-shot installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Claire1217/Eureka/main/install.sh | bash
#
# Optional env vars (set before piping):
#   EUREKA_VAULT_PATH — Obsidian folder path, e.g. ~/Documents/vault/Eureka
#   EUREKA_BACKEND    — "obsidian" (default) or "notes"
#   EUREKA_API_KEY    — API key for / AI answers (DeepSeek by default)
# (The old TC_* names still work.)
set -euo pipefail

TC_VAULT_PATH="${EUREKA_VAULT_PATH:-${TC_VAULT_PATH:-}}"
TC_BACKEND="${EUREKA_BACKEND:-${TC_BACKEND:-}}"
TC_API_KEY="${EUREKA_API_KEY:-${TC_API_KEY:-}}"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

if [ "$(uname -s)" != "Darwin" ]; then
    fail "Eureka requires macOS 12 or later."
fi
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
case "$MACOS_MAJOR" in
    ''|*[!0-9]*) fail "Could not determine the macOS version." ;;
esac
if [ "$MACOS_MAJOR" -lt 12 ]; then
    fail "Eureka requires macOS 12 or later (found macOS $MACOS_VERSION)."
fi

WORK_DIR="$(mktemp -d)"
INSTALL_APP="/Applications/Eureka.app"
INCOMING_DIR=""
INCOMING_APP=""
BACKUP_APP=""
cleanup() {
    status=$?
    set +e
    if [ -n "$BACKUP_APP" ] && { [ -e "$BACKUP_APP" ] || [ -L "$BACKUP_APP" ]; }; then
        if [ ! -e "$INSTALL_APP" ] && [ ! -L "$INSTALL_APP" ]; then
            mv "$BACKUP_APP" "$INSTALL_APP"
        fi
    fi
    if [ -n "$BACKUP_APP" ] && { [ -e "$BACKUP_APP" ] || [ -L "$BACKUP_APP" ]; }; then
        echo "WARNING: Existing Eureka.app backup remains at $BACKUP_APP" >&2
    fi
    [ -n "$INCOMING_DIR" ] && rm -rf "$INCOMING_DIR"
    rm -rf "$WORK_DIR"
    exit "$status"
}
trap cleanup EXIT

RELEASE_JSON="$WORK_DIR/release.json"
RELEASE_API="https://api.github.com/repos/Claire1217/Eureka/releases/latest"
echo "[Eureka] Finding latest release..."
curl -fsSL "$RELEASE_API" -o "$RELEASE_JSON" \
    || fail "Could not fetch the latest release metadata."

# JXA is included with macOS and lets the installer parse GitHub's JSON without
# depending on jq, Python, or the ordering of fields in the API response.
RELEASE_PARSER="$WORK_DIR/release.js"
cat > "$RELEASE_PARSER" <<'JXA'
ObjC.import('Foundation');
function run(argv) {
    var data = $.NSData.dataWithContentsOfFile(argv[0]);
    if (!data) throw new Error('Could not read release metadata');
    var text = ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding));
    var release = JSON.parse(text);
    var tag = release.tag_name || '';
    var zipName = 'Eureka-' + tag + '.zip';
    var checksumName = zipName + '.sha256';
    var assets = release.assets || [];
    var zips = assets.filter(function (asset) { return asset.name === zipName; });
    var checksums = assets.filter(function (asset) { return asset.name === checksumName; });
    if (zips.length !== 1) throw new Error('Expected exactly one ' + zipName + ' release asset');
    if (checksums.length > 1) throw new Error('Found more than one ' + checksumName + ' release asset');
    return [
        tag || '-',
        zips[0].browser_download_url || '-',
        checksums.length === 1 ? (checksums[0].browser_download_url || '-') : '-',
        zips[0].digest || '-'
    ].join('\n');
}
JXA
RELEASE_INFO="$(/usr/bin/osascript -l JavaScript "$RELEASE_PARSER" "$RELEASE_JSON")" \
    || fail "Could not identify the expected Eureka release assets."
TAG="$(printf '%s\n' "$RELEASE_INFO" | sed -n '1p')"
DOWNLOAD_URL="$(printf '%s\n' "$RELEASE_INFO" | sed -n '2p')"
CHECKSUM_URL="$(printf '%s\n' "$RELEASE_INFO" | sed -n '3p')"
ASSET_DIGEST="$(printf '%s\n' "$RELEASE_INFO" | sed -n '4p')"

case "$TAG" in
    v[0-9]*) ;;
    *) fail "Latest release has an invalid tag: $TAG" ;;
esac
VERSION="${TAG#v}"
case "$VERSION" in
    *[!0-9A-Za-z._-]*|'') fail "Latest release has an invalid version: $VERSION" ;;
esac
ASSET_NAME="Eureka-$TAG.zip"
[ "$DOWNLOAD_URL" != "-" ] || fail "Release $TAG is missing $ASSET_NAME."

ZIP_PATH="$WORK_DIR/$ASSET_NAME"
echo "[Eureka] Downloading $ASSET_NAME..."
curl -fsSL "$DOWNLOAD_URL" -o "$ZIP_PATH" \
    || fail "Could not download $ASSET_NAME."

EXPECTED_SHA=""
if [ "$CHECKSUM_URL" != "-" ]; then
    CHECKSUM_PATH="$WORK_DIR/$ASSET_NAME.sha256"
    curl -fsSL "$CHECKSUM_URL" -o "$CHECKSUM_PATH" \
        || fail "Could not download the SHA-256 checksum for $ASSET_NAME."
    read -r EXPECTED_SHA CHECKSUM_NAME CHECKSUM_EXTRA < "$CHECKSUM_PATH" || true
    CHECKSUM_NAME="${CHECKSUM_NAME#\*}"
    [ -z "${CHECKSUM_EXTRA:-}" ] && [ "$CHECKSUM_NAME" = "$ASSET_NAME" ] \
        || fail "The checksum file does not name $ASSET_NAME."
else
    # Compatibility: legacy releases, including v2.0.0, predate checksum
    # assets. Accept only GitHub's SHA-256 digest for the exact ZIP asset.
    case "$ASSET_DIGEST" in
        sha256:*) EXPECTED_SHA="${ASSET_DIGEST#sha256:}" ;;
        *) fail "Release $TAG has neither a .sha256 asset nor a GitHub SHA-256 digest." ;;
    esac
fi
EXPECTED_SHA="$(printf '%s' "$EXPECTED_SHA" | tr '[:upper:]' '[:lower:]')"
case "$EXPECTED_SHA" in
    *[!0-9a-f]*|'') fail "Release $TAG has an invalid SHA-256 checksum." ;;
esac
[ "${#EXPECTED_SHA}" -eq 64 ] || fail "Release $TAG has an invalid SHA-256 checksum."
ACTUAL_SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
[ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] \
    || fail "SHA-256 verification failed for $ASSET_NAME."
echo "[Eureka] SHA-256 verified."

STAGING_DIR="$WORK_DIR/staging"
mkdir "$STAGING_DIR"
ditto -x -k "$ZIP_PATH" "$STAGING_DIR" \
    || fail "Could not extract $ASSET_NAME."
STAGED_APP="$STAGING_DIR/Eureka.app"
PLIST="$STAGED_APP/Contents/Info.plist"
[ -d "$STAGED_APP" ] && [ ! -L "$STAGED_APP" ] \
    || fail "The release does not contain the expected Eureka.app bundle."
[ -f "$PLIST" ] && [ ! -L "$PLIST" ] \
    || fail "Eureka.app has no valid Info.plist."

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null || true
}
BUNDLE_ID="$(plist_value CFBundleIdentifier)"
SHORT_VERSION="$(plist_value CFBundleShortVersionString)"
BUNDLE_VERSION="$(plist_value CFBundleVersion)"
EXECUTABLE_NAME="$(plist_value CFBundleExecutable)"
[ "$BUNDLE_ID" = "com.eureka.app" ] \
    || fail "Eureka.app has an unexpected bundle identifier: $BUNDLE_ID"
[ "$SHORT_VERSION" = "$VERSION" ] && [ "$BUNDLE_VERSION" = "$VERSION" ] \
    || fail "Eureka.app version does not match release $TAG."
[ "$EXECUTABLE_NAME" = "Eureka" ] \
    || fail "Eureka.app has an unexpected executable: $EXECUTABLE_NAME"
EXECUTABLE="$STAGED_APP/Contents/MacOS/$EXECUTABLE_NAME"
[ -f "$EXECUTABLE" ] && [ ! -L "$EXECUTABLE" ] && [ -x "$EXECUTABLE" ] \
    || fail "Eureka.app does not contain an executable Eureka binary."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGED_APP" \
    || fail "Eureka.app code-signature verification failed."
echo "[Eureka] App bundle validated."

# Nothing under /Applications is changed until the download, checksum, bundle,
# executable, version, and signature have all been validated above. Copy the
# validated app to the destination filesystem before replacing the bundle.
echo "[Eureka] Installing to /Applications..."
INCOMING_DIR="$(mktemp -d /Applications/.Eureka.install.XXXXXX)" \
    || fail "Could not reserve a temporary install path in /Applications."
INCOMING_APP="$INCOMING_DIR/Eureka.app"
ditto "$STAGED_APP" "$INCOMING_APP" \
    || fail "Could not prepare Eureka.app for installation."
killall Eureka 2>/dev/null || true
if [ -e "$INSTALL_APP" ] || [ -L "$INSTALL_APP" ]; then
    BACKUP_NAME=".Eureka.app.backup.$(basename "$INCOMING_DIR")"
    BACKUP_APP="/Applications/$BACKUP_NAME"
    REPLACE_SCRIPT="$WORK_DIR/replace.js"
    cat > "$REPLACE_SCRIPT" <<'JXA'
ObjC.import('Foundation');
function run(argv) {
    var result = Ref();
    var error = Ref();
    var ok = $.NSFileManager.defaultManager
        .replaceItemAtURLWithItemAtURLBackupItemNameOptionsResultingItemURLError(
            $.NSURL.fileURLWithPath(argv[0]),
            $.NSURL.fileURLWithPath(argv[1]),
            argv[2],
            $.NSFileManagerItemReplacementWithoutDeletingBackupItem,
            result,
            error);
    if (!ok) {
        var detail = error[0] ? ObjC.unwrap(error[0].localizedDescription) : 'unknown error';
        throw new Error(detail);
    }
}
JXA
    /usr/bin/osascript -l JavaScript "$REPLACE_SCRIPT" \
        "$INSTALL_APP" "$INCOMING_APP" "$BACKUP_NAME" \
        || fail "Could not replace the existing Eureka.app."
    rm -rf "$BACKUP_APP" || fail "Eureka.app was installed, but its backup could not be removed: $BACKUP_APP"
    BACKUP_APP=""
else
    mv "$INCOMING_APP" "$INSTALL_APP" \
        || fail "Could not install Eureka.app."
fi

echo "[Eureka] Removing quarantine flag..."
xattr -dr com.apple.quarantine "$INSTALL_APP" 2>/dev/null || true

if [ -n "$TC_VAULT_PATH" ]; then
    echo "[Eureka] Setting vault path: $TC_VAULT_PATH"
    defaults write com.eureka.app vaultPath "$TC_VAULT_PATH"
fi
if [ -n "$TC_BACKEND" ]; then
    defaults write com.eureka.app storageBackend "$TC_BACKEND"
fi
if [ -n "$TC_API_KEY" ]; then
    echo "[Eureka] Setting API key"
    defaults write com.eureka.app llmApiKey "$TC_API_KEY"
fi

# Finder and Launchpad cache icons per app; make them look again
touch /Applications/Eureka.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Eureka.app >/dev/null 2>&1 || true

echo "[Eureka] Launching..."
open "$INSTALL_APP"

echo ""
echo "✓ Eureka installed."
echo ""
echo "MANUAL STEP REQUIRED:"
echo "  System Settings → Privacy & Security → Accessibility → enable Eureka"
echo ""
if [ -z "$TC_VAULT_PATH" ]; then
    echo "Then: click the E! menu bar icon → Settings → choose save folder"
fi
