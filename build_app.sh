#!/bin/bash

# Build xInsight as a proper macOS .app bundle
# This enables notifications without code signing

set -e

APP_NAME="xInsight"
BUNDLE_ID="com.xdev.xInsight"
VERSION="1.0.0"

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="$PROJECT_DIR/.build/arm64-apple-macosx/release"
APP_DIR="$PROJECT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building xInsight.app..."

# Clean previous build
rm -rf "$PROJECT_DIR/build"
mkdir -p "$PROJECT_DIR/build"

# Build release version
echo "📦 Compiling Swift (release mode)..."
swift build -c release

# Create app bundle structure
echo "📁 Creating app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Copy resources
if [ -d "$PROJECT_DIR/Resources" ]; then
    cp -r "$PROJECT_DIR/Resources/"* "$RESOURCES_DIR/" 2>/dev/null || true
fi

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Create a simple app icon (using system icon)
echo "🎨 Setting up app icon..."

# Remove quarantine attribute if present
echo "🔓 Removing quarantine attributes..."
xattr -cr "$APP_DIR" 2>/dev/null || true

echo ""
echo "✅ Build complete!"
echo "📍 Location: $APP_DIR"
echo ""
echo "🚀 To run the app:"
echo "   open \"$APP_DIR\""
echo ""
echo "⚠️  First time running:"
echo "   1. Right-click the app → Open"
echo "   2. Click 'Open' in the security dialog"
echo "   3. Go to System Settings → Notifications → xInsight"
echo "   4. Enable notifications"
echo ""
