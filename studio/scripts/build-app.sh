#!/bin/sh
set -eu
studio_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
xcrun swift build --package-path "$studio_dir" --scratch-path "$studio_dir/.build"
bin_dir=$(xcrun swift build --package-path "$studio_dir" --scratch-path "$studio_dir/.build" --show-bin-path)
app_dir="$studio_dir/.build/Macropad Studio.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/MacropadStudio" "$app_dir/Contents/MacOS/MacropadStudio"
cp -R "$bin_dir/MacropadStudio_StudioCore.bundle" "$app_dir/Contents/Resources/"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.macropad.studio</string>
<key>CFBundleName</key><string>Macropad Studio</string>
<key>CFBundleExecutable</key><string>MacropadStudio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
printf '%s\n' "$app_dir"
