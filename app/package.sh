#!/bin/bash
# 构建 .app 并打包成带安装界面的 DMG
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="小旋风收音机"
SDK=$(xcrun --show-sdk-path)
BUNDLE="build/${APP_NAME}.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$BUNDLE/Contents/Info.plist" 2>/dev/null || echo "1.0")

STAGE="build/dmgroot"
TMP_DMG="build/.tmp-rw.dmg"
DMG="build/${APP_NAME}-${VERSION}.dmg"

# 1. 先构建 App
./build.sh

echo "preparing disk image…"
rm -rf "$STAGE" "$TMP_DMG" "$DMG"
mkdir -p "$STAGE/.background"
cp -R "$BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns" 2>/dev/null || true

# 2. 背景图
swiftc -O -sdk "$SDK" scripts/makedmgbg.swift -o build/mkdmgbg
build/mkdmgbg "$STAGE/.background/bg.png"

# 3. 生成可读写中间盘
hdiutil create -srcfolder "$STAGE" -volname "$APP_NAME" -fs HFS+ \
    -format UDRW -ov "$TMP_DMG" >/dev/null

MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse -readwrite | tail -1 | sed 's/.*\(\/Volumes\/.*\)/\1/')
if [ ! -d "$MOUNT_POINT" ]; then
    echo "挂载失败" >&2
    exit 1
fi
VOLNAME=$(basename "$MOUNT_POINT")

# 4. 用 Finder 摆好图标位置 / 背景，写入 .DS_Store
osascript <<EOF || echo "（提示）Finder 版面设置失败，将生成默认版面"
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 740, 520}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 108
        set text size of opts to 11
        set background picture of opts to file ".background:bg.png"
        set position of item "${APP_NAME}.app" of container window to {150, 186}
        set position of item "Applications" of container window to {490, 186}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# 5. 自定义磁盘图标。必须放在 Finder 之后：Finder 打开卷时会清掉 .VolumeIcon.icns
cp Resources/AppIcon.icns "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -a C "$MOUNT_POINT"

sleep 1
sync
hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || hdiutil detach "$MOUNT_POINT" -force >/dev/null

# 6. 压缩成只读 DMG
echo "compressing…"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null

rm -rf "$STAGE" "$TMP_DMG" build/mkdmgbg

echo "built: $DMG  ($(du -h "$DMG" | cut -f1))"
