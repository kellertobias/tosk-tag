#!/bin/bash
set -euo pipefail

APP_NAME="Tobisk Tag Editor"
BUNDLE_ID="com.keller.TobiskTagEditor"
EXECUTABLE="TagEditor"
VERSION="1.0"
MIN_OS="13.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
ICON_ICNS="$SCRIPT_DIR/AppIcon.icns"

echo "══════════════════════════════════════════════"
echo "  Building $APP_NAME"
echo "══════════════════════════════════════════════"

# ── Build release ────────────────────────────────
echo "→ Building in release mode..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1 | tail -5
echo "✓ Build succeeded"

# ── Create .app bundle ───────────────────────────
echo "→ Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE"

# Copy icon
if [ -f "$ICON_ICNS" ]; then
    cp "$ICON_ICNS" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "✓ Icon copied"
fi

# ── Write Info.plist ─────────────────────────────
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_OS</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# ── Install to /Applications ─────────────────────
echo "→ Installing to /Applications..."
if [ -d "/Applications/$APP_NAME.app" ]; then
    rm -rf "/Applications/$APP_NAME.app"
fi
cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"

# Clean up local bundle
rm -rf "$APP_BUNDLE"

echo "✓ Installed to /Applications/$APP_NAME.app"
echo ""
echo "══════════════════════════════════════════════"
echo "  Done! Launch from Applications or Spotlight."
echo "══════════════════════════════════════════════"
