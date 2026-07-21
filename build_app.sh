#!/bin/bash
set -e

APP_NAME="WindowTiler"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app/Contents/MacOS"

echo "Building release..."
swift build -c release

echo "Creating .app bundle..."
mkdir -p "$APP_DIR"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/"

# Info.plist
cat > "$APP_NAME.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>WindowTiler</string>
    <key>CFBundleIdentifier</key>
    <string>com.opensource.windowtiler</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>WindowTiler</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>WindowTiler 需要辅助功能权限来移动和调整窗口大小。</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF

echo "Done! App bundle created: $APP_NAME.app"
echo ""
echo "To run: open $APP_NAME.app"
echo "To install: cp -r $APP_NAME.app /Applications/"
