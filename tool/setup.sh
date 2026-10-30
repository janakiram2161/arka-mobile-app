#!/usr/bin/env bash
# Prepares the Flutter project for building on Android and iOS:
#  1. generates the android/ and ios/ platform folders (if missing),
#  2. adds the packages the app uses,
#  3. sets the app name and the Android internet permission,
#  4. creates the app icon from the ARKA logo on arkaschmuck.de.
# Used by the GitHub build; also works on a Mac or PC with Flutter installed.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --org de.arkaschmuck --project-name arka_schmuck --platforms android,ios --no-pub .
fi

flutter pub add http cached_network_image shared_preferences webview_flutter url_launcher
flutter pub add --dev flutter_launcher_icons

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  perl -0pi -e 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
perl -pi -e 's/android:label="[^"]*"/android:label="ARKA Schmuck"/' "$MANIFEST"

PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ]; then
  perl -0pi -e 's#(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)#${1}ARKA Schmuck${2}#' "$PLIST"
fi

python3 tool/make_icon.py
dart run flutter_launcher_icons -f flutter_launcher_icons.yaml
