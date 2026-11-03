#!/bin/bash
# 用法: scripts/make_app.sh <執行檔路徑> <輸出目錄>
set -euo pipefail
BIN="$1"; OUT="$2"
APP="$OUT/ClaudeGuide.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ClaudeGuide"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Claude 小精靈</string>
<key>CFBundleIdentifier</key><string>com.example.ClaudeGuide</string>
<key>CFBundleExecutable</key><string>ClaudeGuide</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>小精靈需要看到你的螢幕才能一步步教你操作。</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
