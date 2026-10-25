#!/bin/bash
# The macOS download: the app built by port/gui/build.sh with the original's
# files it reads (kaiser.exe for the resources, kaiser.mid) and the help
# (docs/manual.md, docs/help-map.txt) in its Resources, zipped.
# Usage: port/package-mac.sh EDITION VERSION   e.g. Classic 1.0
# Needs the original game in Kaiser/ (not in git). Output:
#   port/bin/release/Kaiser-EDITION-VERSION-macOS-arm64.zip
set -euo pipefail
cd "$(dirname "$0")/.."
ED=${1:?edition (Classic or Remastered)}
VER=${2:?version}
for F in Kaiser/kaiser.exe Kaiser/kaiser.mid port/bin/Kaiser.app/Contents/MacOS/Kaiser; do
  [ -f "$F" ] || { echo "missing $F" >&2; exit 1; }
done
OUT=port/bin/release
STAGE=$OUT/mac-$ED
APP="$STAGE/Kaiser $ED.app"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$OUT"
cp -R port/bin/Kaiser.app "$APP"
R="$APP/Contents/Resources"
mkdir -p "$R/Kaiser" "$R/docs"
cp Kaiser/kaiser.exe Kaiser/kaiser.mid "$R/Kaiser/"
cp docs/manual.md docs/help-map.txt "$R/docs/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Kaiser</string>
<key>CFBundleIdentifier</key><string>local.kaiser.$(echo "$ED" | tr 'A-Z' 'a-z')</string>
<key>CFBundleName</key><string>Kaiser $ED</string>
<key>CFBundleDisplayName</key><string>Kaiser $ED</string>
<key>CFBundleShortVersionString</key><string>$VER</string>
<key>CFBundleVersion</key><string>$VER</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# ad-hoc signature again (the bundle changed; arm64 runs only signed code)
codesign --force --deep --sign - "$APP"
ZIP="$OUT/Kaiser-$ED-$VER-macOS-arm64.zip"
rm -f "$ZIP"
(cd "$STAGE" && ditto -c -k --keepParent "Kaiser $ED.app" "../$(basename "$ZIP")")
ls -la "$ZIP"
