#!/bin/bash
# Build DisplayRanger.app — a proper, ad-hoc-signed macOS app bundle wrapping the
# SwiftPM release binary. Pass --install to also copy it into /Applications.
#
#   ./Scripts/package-app.sh            # builds build/DisplayRanger.app
#   ./Scripts/package-app.sh --install  # …and installs to /Applications
#
# App Sandbox is intentionally OFF: display reconfiguration uses public CoreGraphics
# APIs that need no entitlement, but the process must not be sandboxed.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP_NAME="DisplayRanger"
BUNDLE_ID="com.anupaglawe.displayranger"
VERSION="1.0"
APP="$ROOT/build/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "▸ Building release binary…"
swift build -c release
BIN="$ROOT/.build/release/$APP_NAME"
[ -x "$BIN" ] || { echo "release binary not found at $BIN"; exit 1; }

echo "▸ Assembling bundle…"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/$APP_NAME"

echo "▸ Rendering app icon…"
ICONSET="$(mktemp -d)/AppIcon.iconset"
swift "$ROOT/Scripts/MakeAppIcon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"

echo "▸ Writing Info.plist…"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>LSUIElement</key>             <false/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "▸ Ad-hoc signing…"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP" 2>&1 | sed 's/^/  /'

echo "✓ Built $APP"

if [ "${1:-}" = "--install" ]; then
    DEST="/Applications/$APP_NAME.app"
    echo "▸ Installing to ${DEST} ..."
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    echo "✓ Installed. Launch with: open -a $APP_NAME"
fi
