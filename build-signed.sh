#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Tobisk Tag Editor"
EXECUTABLE="TagEditor"
BUNDLE_ID="${BUNDLE_ID:-de.tobisk.apps.tag-editor}"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_OS="${MIN_OS:-13.0}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_DIR="${OUTPUT_DIR:-}"
INSTALL_APP="${INSTALL_APP:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_ICNS="$SCRIPT_DIR/AppIcon.icns"
DEFAULT_OUTPUT_DIR="$SCRIPT_DIR/dist"

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
fi

APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.zip"

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Builds, packages, signs, verifies, and archives $APP_NAME.app using the Xcode Swift toolchain.

Options:
  --identity NAME        Codesigning identity. Defaults to CODE_SIGN_IDENTITY,
                         then the first Developer ID/Application Development identity found.
  --bundle-id ID        Bundle identifier. Default: $BUNDLE_ID
  --version VERSION     CFBundleShortVersionString. Default: $VERSION
  --build NUMBER        CFBundleVersion. Default: $BUILD_NUMBER
  --output DIR          Output directory. Default: $OUTPUT_DIR
  --install             Copy the signed app to /Applications after building.
  -h, --help            Show this help.

Environment:
  CODE_SIGN_IDENTITY    Signing identity, for example "Developer ID Application: Name (TEAMID)".
  CONFIGURATION         Xcode build configuration. Default: Release.
  DEVELOPER_DIR         Optional Xcode developer directory for this build.

For local ad-hoc signing, pass --identity -.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity)
            CODE_SIGN_IDENTITY="${2:?Missing value for --identity}"
            shift 2
            ;;
        --bundle-id)
            BUNDLE_ID="${2:?Missing value for --bundle-id}"
            shift 2
            ;;
        --version)
            VERSION="${2:?Missing value for --version}"
            ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.zip"
            shift 2
            ;;
        --build)
            BUILD_NUMBER="${2:?Missing value for --build}"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="${2:?Missing value for --output}"
            APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
            ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.zip"
            shift 2
            ;;
        --install)
            INSTALL_APP="1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: '$1' is required but was not found in PATH." >&2
        exit 69
    fi
}

require_tool xcrun
require_tool codesign
require_tool ditto

DEVELOPER_DIR_PATH="$(xcode-select -p)"
if [[ "$DEVELOPER_DIR_PATH" == *"/CommandLineTools" ]]; then
    echo "error: xcodebuild is currently using Command Line Tools, not full Xcode." >&2
    echo "Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    exit 69
fi

detect_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
        | head -n 1
}

CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
    CODE_SIGN_IDENTITY="$(detect_identity || true)"
fi

if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
    echo "error: no signing identity found." >&2
    echo "Pass --identity '-' for ad-hoc signing or --identity 'Developer ID Application: ...' for distribution." >&2
    exit 65
fi

echo "==> Building $APP_NAME"
echo "    Bundle id: $BUNDLE_ID"
echo "    Identity:  $CODE_SIGN_IDENTITY"

mkdir -p "$OUTPUT_DIR"

SWIFT_CONFIGURATION="$(printf '%s' "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')"

xcrun swift build -c "$SWIFT_CONFIGURATION"

BUILT_PRODUCTS_DIR="$(xcrun swift build -c "$SWIFT_CONFIGURATION" --show-bin-path)"
BUILT_EXECUTABLE="$BUILT_PRODUCTS_DIR/$EXECUTABLE"

if [[ -z "$BUILT_EXECUTABLE" || ! -x "$BUILT_EXECUTABLE" ]]; then
    echo "error: could not find built executable named $EXECUTABLE under $BUILT_PRODUCTS_DIR." >&2
    exit 66
fi

echo "==> Packaging $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILT_EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE"

if [[ -f "$ICON_ICNS" ]]; then
    cp "$ICON_ICNS" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_OS</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null

echo "==> Signing"
SIGNING_ARGS=(
    --force
    --deep
    --options runtime
    --sign "$CODE_SIGN_IDENTITY"
)

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
    SIGNING_ARGS+=(--timestamp)
fi

codesign "${SIGNING_ARGS[@]}" "$APP_BUNDLE"

echo "==> Verifying signature"
codesign --verify --strict --deep --verbose=2 "$APP_BUNDLE"

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
    spctl --assess --type execute --verbose=4 "$APP_BUNDLE" || {
        echo "warning: spctl assessment failed. The app may need notarization for distribution outside this Mac." >&2
    }
fi

if [[ "$INSTALL_APP" == "1" ]]; then
    echo "==> Installing to /Applications"
    ditto "$APP_BUNDLE" "/Applications/$APP_NAME.app"
fi

echo "==> Archiving"
rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

echo "==> Done"
echo "$APP_BUNDLE"
echo "$ARCHIVE_PATH"
