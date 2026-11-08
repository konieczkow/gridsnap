#!/bin/sh -e
# Builds build/GridSnap.app (universal, macOS 14+). `./build.sh install` also copies it to /Applications,
# `./build.sh release` zips it for a GitHub release.
# No Xcode project: swiftc compiles every file in Sources/. Needs Command Line Tools with the macOS 26 SDK.
# Signing: CODESIGN_IDENTITY, else a "Developer ID Application" certificate, else "GridSnap Dev", else ad-hoc.
# Ad-hoc signatures change every build, which makes macOS forget the Accessibility grant (see README).
# A Developer ID build gets the hardened runtime, and `release` notarizes and staples it.
# Notary credentials come from the keychain profile NOTARY_PROFILE (default gridsnap-notary).
cd "$(dirname "$0")"
APP=build/GridSnap.app
VERSION=0.1.8
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
for ARCH in arm64 x86_64; do swiftc -O -target "$ARCH-apple-macos14.0" Sources/*.swift -o "build/GridSnap-$ARCH"; done
lipo -create build/GridSnap-arm64 build/GridSnap-x86_64 -output "$APP/Contents/MacOS/GridSnap"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GridSnap</string>
<key>CFBundleIdentifier</key><string>com.zerodivisionerror.gridsnap</string>
<key>CFBundleName</key><string>GridSnap</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -oE '"(Developer ID Application[^"]*|GridSnap Dev)"' | sort | head -1 | tr -d '"')}"
case "$IDENTITY" in "Developer ID"*) SIGNFLAGS="--options runtime"; if [ "$1" = release ]; then SIGNFLAGS="$SIGNFLAGS --timestamp"; fi;; esac
codesign --force $SIGNFLAGS --sign "${IDENTITY:--}" "$APP"
echo "built $APP (signed: ${IDENTITY:-ad-hoc})"
if [ "$1" = release ]; then
  ZIP="build/GridSnap-$VERSION.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  if [ -n "$SIGNFLAGS" ]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "${NOTARY_PROFILE:-gridsnap-notary}" --wait
    xcrun stapler staple "$APP"
    ditto -c -k --keepParent "$APP" "$ZIP"
  fi
  echo "zipped $ZIP  sha256 $(shasum -a 256 "$ZIP" | cut -d' ' -f1)  (update Casks/gridsnap.rb in homebrew-tap)"
fi
if [ "$1" = install ]; then rm -rf /Applications/GridSnap.app; cp -R "$APP" /Applications/; echo "installed /Applications/GridSnap.app"; fi
