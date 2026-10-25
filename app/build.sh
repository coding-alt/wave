#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="小旋风收音机"
BUNDLE="build/${APP_NAME}.app"
SDK=$(xcrun --show-sdk-path)

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>Radio</string>
    <key>CFBundleIdentifier</key><string>com.local.radio.xiaoxuanfeng</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key><true/>
    </dict>
</dict>
</plist>
PLIST

# icon
mkdir -p build
if [ ! -f Resources/AppIcon.icns ]; then
    mkdir -p Resources
    swiftc -O -sdk "$SDK" scripts/makeicon.swift -o build/mkicon
    rm -rf build/AppIcon.iconset
    build/mkicon build/AppIcon.iconset >/dev/null
    iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

echo "compiling…"
swiftc -O -swift-version 5 -parse-as-library \
    -target arm64-apple-macosx13.0 \
    -sdk "$SDK" \
    Sources/*.swift \
    -o "$BUNDLE/Contents/MacOS/Radio"

codesign --force --deep --sign - "$BUNDLE" 2>/dev/null || true
echo "built: $BUNDLE"
