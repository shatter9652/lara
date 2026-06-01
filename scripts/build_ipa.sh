#!/bin/bash
set -euo pipefail

rm -rf build/
mkdir -p build

echo "Build Started!"
echo

xcodebuild \
  -project lara.xcodeproj \
  -scheme lara \
  -configuration Debug \
  -sdk iphoneos \
  -arch arm64e \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="Config/lara.entitlements" \
  archive \
  -archivePath "$PWD/build/lara.xcarchive" 2>&1 | xcpretty

APP_PATH="$PWD/build/lara.xcarchive/Products/Applications/lara.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Missing app at $APP_PATH"
  exit 1
fi
rm -rf "$PWD/build/Payload"
mkdir -p "$PWD/build/Payload"
cp -R "$APP_PATH" "$PWD/build/Payload/"

plutil -replace UIFileSharingEnabled -bool YES "$PWD/build/Payload/lara.app/Info.plist"

# Bundle full Frida (server+agent+plist) from deb into signed app for runtime use (PC decrypt/inject + terminal)
FRIDA_DEB="$PWD/frida_17.10.0_iphoneos-arm64.deb"
if [ -f "$FRIDA_DEB" ]; then
  FRIDA_TMP=/tmp/frida_extract_$$
  mkdir -p "$FRIDA_TMP"
  (cd "$FRIDA_TMP" && ar x "$FRIDA_DEB" && tar -xJf data.tar.xz)
  mkdir -p "$PWD/build/Payload/lara.app/frida"
  cp "$FRIDA_TMP/var/jb/usr/sbin/frida-server" "$PWD/build/Payload/lara.app/frida/" 2>/dev/null || true
  cp "$FRIDA_TMP/var/jb/usr/lib/frida-1.0/frida-agent.dylib" "$PWD/build/Payload/lara.app/frida/" 2>/dev/null || true
  cp "$FRIDA_TMP/var/jb/Library/LaunchDaemons/re.frida.server.plist" "$PWD/build/Payload/lara.app/frida/" 2>/dev/null || true
  rm -rf "$FRIDA_TMP"
fi

if ! command -v ldid >/dev/null 2>&1; then
  echo "ERROR: ldid not installed. Install with: brew install ldid" >&2
  exit 1
fi
ldid -SConfig/lara.entitlements "$PWD/build/Payload/lara.app/lara"
(cd "$PWD/build" && /usr/bin/zip -qry lara.ipa Payload)

echo
echo "build successful!"
echo "ipa at: build/lara.ipa"
exit 0
