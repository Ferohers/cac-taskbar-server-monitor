#!/bin/bash

echo "🎨 Building transparent icon for macOS Tahoe..."

# Configuration
APP_NAME="Duman.app"
BINARY_NAME="Duman"
ICON_SOURCE_PNG="icon/logo.png"
ICONSET_DIR="icon/Duman.iconset"
ICNS_NAME="Duman.icns"

# Clean previous builds
rm -rf .build
rm -rf "${APP_NAME}"
rm -rf "${ICONSET_DIR}"

# Verify source PNG exists and has transparency
if [ ! -f "${ICON_SOURCE_PNG}" ]; then
    echo "❌ Source PNG not found: ${ICON_SOURCE_PNG}"
    exit 1
fi

# Check PNG properties
echo "🔍 Verifying source PNG transparency..."
png_info=$(file "${ICON_SOURCE_PNG}")
echo "📊 PNG info: $png_info"

if [[ $png_info == *"RGBA"* ]]; then
    echo "✅ Source PNG has transparency (RGBA)"
elif [[ $png_info == *"with transparency"* ]]; then
    echo "✅ Source PNG has transparency"
else
    echo "⚠️  Warning: PNG may not have proper transparency"
fi

# Function to resize PNG with transparency preservation
resize_png_with_transparency() {
    local size=$1
    local input_png=$2
    local output_png=$3
    
    echo "  → Generating ${size}x${size} PNG..."
    
    # Use sips (macOS native) to resize while preserving transparency
    sips -z $size $size \
         -s format png \
         --deleteColorManagementProperties \
         "$input_png" \
         --out "$output_png" >/dev/null 2>&1
    
    if [ -f "$output_png" ] && [ -s "$output_png" ]; then
        echo "    ✅ Generated ${size}x${size} PNG"
        return 0
    else
        echo "    ❌ Failed to generate ${size}x${size} PNG"
        return 1
    fi
}

# Build Swift package
echo "🔨 Building Swift package..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Swift build failed!"
    exit 1
fi

# Create .app bundle structure
echo "📁 Creating .app bundle structure..."
mkdir -p "${APP_NAME}/Contents/MacOS"
mkdir -p "${APP_NAME}/Contents/Resources"

# Copy binary
echo "📦 Copying binary..."
cp ".build/release/${BINARY_NAME}" "${APP_NAME}/Contents/MacOS/"
chmod +x "${APP_NAME}/Contents/MacOS/${BINARY_NAME}"

# Copy entitlements file
echo "📋 Copying entitlements..."
if [ -f "Duman.entitlements" ]; then
    cp "Duman.entitlements" "${APP_NAME}/Contents/"
    echo "✓ Copied entitlements file"
else
    echo "⚠️ Entitlements file not found"
fi

# Create complete iconset for macOS Tahoe
echo "🖼️  Creating complete iconset for macOS Tahoe..."
mkdir -p "${ICONSET_DIR}"

# Generate all required icon sizes
declare -a sizes=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

echo "📐 Generating all required icon sizes..."
for size_info in "${sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    resize_png_with_transparency $size "${ICON_SOURCE_PNG}" "${ICONSET_DIR}/${filename}"
done

# Verify iconset completeness
echo "🔍 Verifying iconset completeness..."
missing_icons=0
for size_info in "${sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    icon_path="${ICONSET_DIR}/${filename}"
    if [ ! -f "$icon_path" ] || [ ! -s "$icon_path" ]; then
        echo "❌ Missing or empty: $filename"
        missing_icons=$((missing_icons + 1))
    fi
done

if [ $missing_icons -gt 0 ]; then
    echo "❌ Error: $missing_icons icon(s) missing. Cannot proceed."
    exit 1
else
    echo "✅ All icons generated successfully"
fi

# Generate ICNS file
echo "✨ Generating ${ICNS_NAME} from iconset..."
iconutil -c icns "${ICONSET_DIR}" -o "${APP_NAME}/Contents/Resources/${ICNS_NAME}"

if [ $? -eq 0 ]; then
    echo "✅ Generated ${ICNS_NAME} successfully"
    
    # Verify ICNS file
    if [ -f "${APP_NAME}/Contents/Resources/${ICNS_NAME}" ] && [ -s "${APP_NAME}/Contents/Resources/${ICNS_NAME}" ]; then
        icns_size=$(du -h "${APP_NAME}/Contents/Resources/${ICNS_NAME}" | cut -f1)
        echo "✅ ICNS file size: $icns_size"
    else
        echo "❌ ICNS file is empty or missing!"
        exit 1
    fi
else
    echo "❌ iconutil failed to create ${ICNS_NAME}!"
    exit 1
fi

# Create Info.plist with proper icon reference
echo "📝 Creating Info.plist..."
TARGET_PLIST="${APP_NAME}/Contents/Info.plist"
cp "Info.plist" "${TARGET_PLIST}"

# Update Info.plist with proper settings
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string ${BINARY_NAME}" "${TARGET_PLIST}" 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile ${ICNS_NAME}" "${TARGET_PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${BINARY_NAME}" "${TARGET_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "${TARGET_PLIST}" 2>/dev/null
/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "${TARGET_PLIST}" 2>/dev/null

# Add macOS Tahoe specific settings
/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string ${BINARY_NAME}" "${TARGET_PLIST}" 2>/dev/null

# Code signing
echo "🔐 Code signing..."
if [ -f "Duman.entitlements" ]; then
    codesign --force --sign - --entitlements "Duman.entitlements" "${APP_NAME}/Contents/MacOS/${BINARY_NAME}" 2>/dev/null
    codesign --force --sign - --entitlements "Duman.entitlements" "${APP_NAME}" 2>/dev/null
else
    codesign --force --sign - "${APP_NAME}" 2>/dev/null
fi

echo ""
echo "✅ Build successful with transparent icon for macOS Tahoe!"
echo "🎉 Created ${APP_NAME}"
echo ""
echo "🔧 Transparent icon fixes applied:"
echo "   • Generated complete iconset from transparent PNG"
echo "   • Used macOS-native tools for transparency preservation"
echo "   • Applied macOS Tahoe compatibility settings"
echo "   • Verified iconset completeness and ICNS integrity"
echo ""
echo "🚀 To test: open ./${APP_NAME}"
echo ""
echo "🛠️  If you still see a gray box after installation:"
echo "   1. Clear icon cache: sudo rm -rf /Library/Caches/com.apple.iconservices.store"
echo "   2. Restart Finder: killall Finder"
echo "   3. Log out and back in to refresh the icon cache"
echo "   4. Restart your Mac if the issue persists"