#!/bin/zsh
# Uploads build/desktopcloth-<version>.pkg, made by ./build.sh --appstore, to App Store Connect.
# Needs an App Store Connect API key (Users and Access → Integrations, App Manager role): save the downloaded
# AuthKey_<key ID>.p8 in ~/.appstoreconnect/private_keys, then run
#   ASC_KEY_ID=<key ID> ASC_ISSUER_ID=<issuer ID> ./appstore/upload.sh
# Each upload needs a higher CFBundleVersion in Info.plist than the last one.
set -e
cd "${0:A:h}/.."

[[ -n $ASC_KEY_ID && -n $ASC_ISSUER_ID ]] || { echo "Set ASC_KEY_ID and ASC_ISSUER_ID" >&2; exit 1; }
if [[ -z $DEVELOPER_DIR && -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
PKG="build/desktopcloth-$VERSION.pkg"
[[ -f $PKG ]] || { echo "Run ./build.sh --appstore first" >&2; exit 1; }

xcrun altool --validate-app --type macos --file "$PKG" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
xcrun altool --upload-app --type macos --file "$PKG" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
echo "Uploaded $PKG. It shows up in App Store Connect under TestFlight once Apple has processed it."
