#!/bin/bash

echo "Building AltanMon..."

# --- Configuration ---
APP_NAME="AltanMon.app"
BINARY_NAME="AltanMon"
ICON_SOURCE_SVG="icon/logo.svg"
ICON_LARGE_PNG="icon/logo.svg.png" # Generated from SVG using qlmanage
ICONSET_DIR="icon/AltanMon.iconset"
ICNS_NAME="AltanMon.icns"
INFO_PLIST_NAME="Info.plist"

# --- Clean previous builds ---
rm -rf .build
rm -rf "${APP_NAME}"
rm -rf "${ICONSET_DIR}"
rm -f "Sources/MenuBarIcon_16.png" # Remove old PNG reference

# --- Build the Swift package ---
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Swift build failed!"
    exit 1
fi

# --- Create .app bundle structure ---
echo "📁 Creating .app bundle structure..."
mkdir -p "${APP_NAME}/Contents/MacOS"
mkdir -p "${APP_NAME}/Contents/Resources"

# --- Copy binary to the .app bundle ---
echo "📦 Copying binary..."
cp ".build/release/${BINARY_NAME}" "${APP_NAME}/Contents/MacOS/"
if [ $? -ne 0 ]; then
    echo "❌ Failed to copy binary!"
    exit 1
fi
chmod +x "${APP_NAME}/Contents/MacOS/${BINARY_NAME}"

# --- Generate PNG from SVG and create menu bar icons ---
echo "🎨 Generating PNG from SVG..."
qlmanage -t -s 1024 -o icon/ "${ICON_SOURCE_SVG}"

# --- Generate menu bar icons ---
echo "📱 Generating menu bar icons..."
mkdir -p icon/generated
sips -z 16 16 "${ICON_LARGE_PNG}" --out "icon/generated/MenuBarIcon_16.png"
sips -z 32 32 "${ICON_LARGE_PNG}" --out "icon/generated/MenuBarIcon_16@2x.png"
sips -z 22 22 "${ICON_LARGE_PNG}" --out "icon/generated/MenuBarIcon_22.png"
sips -z 44 44 "${ICON_LARGE_PNG}" --out "icon/generated/MenuBarIcon_22@2x.png"
sips -z 32 32 "${ICON_LARGE_PNG}" --out "icon/generated/MenuBarIcon_32.png"
sips -z 64 64 "${ICON_LARGE_PNG}" --out "icon/generated/MenuBarIcon_32@2x.png"

# --- Copy existing ICNS file for menu bar icon ---
echo "📋 Copying existing AltanMon.icns for menu bar use..."
if [ -f "icon/AltanMon.icns" ]; then
    # The ICNS will be copied later in the main icon generation step
    echo "✓ AltanMon.icns found and will be used for menu bar icon"
else
    echo "⚠️ AltanMon.icns not found in icon/ folder"
fi

# --- Copy existing .icns file ---
echo "🎨 Using existing AltanMon.icns file..."
if [ -f "icon/${ICNS_NAME}" ]; then
    cp "icon/${ICNS_NAME}" "${APP_NAME}/Contents/Resources/"
    echo "✓ Copied existing ${ICNS_NAME} to app bundle"
else
    echo "❌ AltanMon.icns not found in icon/ folder!"
    exit 1
fi

# --- Create Info.plist ---
echo "📝 Creating Info.plist..."
cat > "${APP_NAME}/Contents/${INFO_PLIST_NAME}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${BINARY_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>${ICNS_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.altan.AltanMon</string>
    <key>CFBundleName</key>
    <string>${BINARY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>AltanMon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>com.apple.developer.usernotifications.communication</key>
    <true/>
</dict>
</plist>
EOF

if [ $? -ne 0 ]; then
    echo "❌ Failed to create Info.plist!"
    exit 1
fi

echo ""
echo "✅ Build successful!"
echo "🎉 Created ${APP_NAME}"
echo "🚀 To run, open the app from Finder or use: open ./${APP_NAME}"
echo ""
