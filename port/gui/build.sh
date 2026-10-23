#!/bin/bash
# Build the GUI (port/gui) with Free Pascal and the LCL (Cocoa) built in
# tools/lazarus (see docs/phase3.md, milestone 7). Output: port/bin/Kaiser.app
# GUI_FPC_OPTS: extra compiler options (e.g. "-gl -gw" for line info in lldb)
set -euo pipefail
cd "$(dirname "$0")"
L=../../tools/lazarus
A=aarch64-darwin
mkdir -p ../obj/gui ../bin
fpc -Mobjfpc -Sa -O2 ${GUI_FPC_OPTS:-} -dLCL -dLCLcocoa \
  -Fu../src -Fu"$L/lcl/units/$A/cocoa" -Fu"$L/lcl/units/$A" \
  -Fu"$L/components/lazutils/lib/$A" -Fu"$L/packager/units/$A" \
  -FU../obj/gui -FE../bin \
  -k-ld_classic -k-framework -kCocoa -k-framework -kUserNotifications \
  kaisergui.lpr
APP=../bin/Kaiser.app/Contents
mkdir -p "$APP/MacOS"
cp ../bin/kaisergui "$APP/MacOS/Kaiser"
cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Kaiser</string>
<key>CFBundleIdentifier</key><string>local.kaiser.port</string>
<key>CFBundleName</key><string>Kaiser</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
