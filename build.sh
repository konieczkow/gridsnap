#!/bin/sh -e
# ponytail: no Xcode project. The .app wrapper exists only so the Accessibility list shows "GridSnap".
cd "$(dirname "$0")"
APP=/Applications/GridSnap.app
mkdir -p $APP/Contents/MacOS
swiftc -O main.swift -o $APP/Contents/MacOS/GridSnap
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GridSnap</string>
<key>CFBundleIdentifier</key><string>local.gridsnap</string>
<key>CFBundleName</key><string>GridSnap</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
tccutil reset Accessibility local.gridsnap >/dev/null 2>&1 || true  # ad-hoc signature changes per build; re-prompt instead of silently failing
echo "built $APP — run: open $APP (re-grant Accessibility when prompted)"
