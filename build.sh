#!/bin/zsh
# Builds "desktopcloth.app" (Apple silicon + Intel, macOS 13+) into ./build, zips it and packs it into a DMG.
# Needs the Xcode Command Line Tools: xcode-select --install
# To install the result: quit the running app, then copy build/desktopcloth.app to ~/Applications or /Applications.
# For other Macs, share build/desktopcloth-<version>.dmg. Making it briefly opens a Finder window, and the first
# run asks to let your terminal control Finder.
# ./build.sh --appstore builds only the app, for the Mac App Store: without Check for Updates (the App Store updates
# it) and without network access. It signs it with your Apple Distribution certificate and packs it into
# build/desktopcloth-<version>.pkg, signed with your Mac Installer Distribution certificate, ready for
# appstore/upload.sh or Transporter. That needs Xcode, both certificates in your keychain, and the app's Mac App Store
# provisioning profile saved as appstore/desktopcloth.provisionprofile.
# ./build.sh --notarize builds the GitHub copy signed with your Developer ID Application certificate instead of
# ad-hoc, has Apple notarize the DMG and staples the ticket, so it opens on any Mac without Open Anyway. That needs
# Xcode, the certificate in your keychain, and a notarytool login saved once with
#   xcrun notarytool store-credentials notary --apple-id <Apple ID> --team-id C6ZRF9KM22
# (set NOTARY_PROFILE to use a profile with another name).
set -e
cd "${0:A:h}"

TEAM_ID=C6ZRF9KM22
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" Info.plist)

SOURCES=(main.swift Covers.swift DynamicWallpaper.swift StatusImage.swift Welcome.swift Updates.swift)
if [[ $1 == --appstore ]]; then
  FLAGS=(-D APPSTORE)
  ENTITLEMENTS=desktopcloth.entitlements
  PROFILE=appstore/desktopcloth.provisionprofile
  # Check everything signing needs before building.
  # App Store Connect only takes apps built with Xcode's SDK, so use Xcode even if the Command Line Tools are selected.
  if [[ -z $DEVELOPER_DIR && -d /Applications/Xcode.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
  xcrun --find xcodebuild &>/dev/null || { echo "Install Xcode first" >&2; exit 1; }
  [[ -f $PROFILE ]] || {
    echo "Download the Mac App Store provisioning profile for $BUNDLE_ID and save it as $PROFILE" >&2; exit 1
  }
  PROFILE_PLIST=$(mktemp)
  security cms -D -i $PROFILE > $PROFILE_PLIST
  PROFILE_TEAM=$(/usr/libexec/PlistBuddy -c "Print TeamIdentifier:0" $PROFILE_PLIST)
  PROFILE_APP=$(/usr/libexec/PlistBuddy -c "Print Entitlements:com.apple.application-identifier" $PROFILE_PLIST)
  rm $PROFILE_PLIST
  [[ $PROFILE_TEAM == $TEAM_ID && $PROFILE_APP == $TEAM_ID.$BUNDLE_ID ]] || {
    echo "$PROFILE is for $PROFILE_APP, not $TEAM_ID.$BUNDLE_ID" >&2; exit 1
  }
  # Certificate names look like "Apple Distribution: Name (TEAMID)" and "3rd Party Mac Developer Installer: Name (TEAMID)".
  APP_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Distribution: .*($TEAM_ID)" | head -1 | cut -d '"' -f 2)
  PKG_IDENTITY=$(security find-identity -v | grep -E "(3rd Party Mac Developer Installer|Mac Installer Distribution): .*\($TEAM_ID\)" \
    | head -1 | cut -d '"' -f 2)
  # Without -v, find-identity also lists certificates macOS doesn't trust, e.g. when the Apple WWDR G3 intermediate is missing.
  UNTRUSTED="is in your keychain but not trusted. Install https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"
  [[ -n $APP_IDENTITY ]] || {
    security find-identity -p codesigning | grep -q "Apple Distribution: .*($TEAM_ID)" \
      && echo "The Apple Distribution certificate for team $TEAM_ID $UNTRUSTED" >&2 \
      || echo "No Apple Distribution certificate for team $TEAM_ID in your keychain" >&2
    exit 1
  }
  [[ -n $PKG_IDENTITY ]] || {
    security find-identity | grep -qE "(3rd Party Mac Developer Installer|Mac Installer Distribution): .*\($TEAM_ID\)" \
      && echo "The Mac Installer Distribution certificate for team $TEAM_ID $UNTRUSTED" >&2 \
      || echo "No Mac Installer Distribution certificate for team $TEAM_ID in your keychain" >&2
    exit 1
  }
else
  FLAGS=()
  ENTITLEMENTS=desktopcloth-github.entitlements
fi

if [[ $1 == --notarize ]]; then
  if [[ -z $DEVELOPER_DIR && -d /Applications/Xcode.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
  xcrun --find notarytool &>/dev/null || { echo "Install Xcode first" >&2; exit 1; }
  NOTARY_PROFILE=${NOTARY_PROFILE:-notary}
  # The certificate name looks like "Developer ID Application: Name (TEAMID)". Sign by its SHA-1 fingerprint:
  # with two certificates of the same name, signing by name stops with "ambiguous".
  DEV_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application: .*($TEAM_ID)" | head -1 | awk '{print $2}')
  [[ -n $DEV_IDENTITY ]] || { echo "No Developer ID Application certificate for team $TEAM_ID in your keychain" >&2; exit 1; }
fi

APP="build/desktopcloth.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O $FLAGS -target arm64-apple-macos13.0 -o build/desktopcloth-arm64 $SOURCES
swiftc -O $FLAGS -target x86_64-apple-macos13.0 -o build/desktopcloth-x86_64 $SOURCES
lipo -create -output "$APP/Contents/MacOS/desktopcloth" build/desktopcloth-arm64 build/desktopcloth-x86_64
rm build/desktopcloth-arm64 build/desktopcloth-x86_64

cp Info.plist "$APP/Contents/"
# The app icon is drawn by art/AppIcon.swift; the menu bar images are drawn at runtime by StatusImage.swift.
swiftc -O -o build/AppIcon art/AppIcon.swift
build/AppIcon "$APP/Contents/Resources/AppIcon.icns"
rm build/AppIcon

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)

if [[ $1 == --appstore ]]; then
  # The SDK and Xcode keys Xcode would add; App Store Connect checks them.
  PLIST="$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add CFBundleSupportedPlatforms array" -c "Add CFBundleSupportedPlatforms:0 string MacOSX" \
    -c "Add DTPlatformName string macosx" \
    -c "Add DTPlatformVersion string $(xcrun --sdk macosx --show-sdk-platform-version)" \
    -c "Add DTSDKName string macosx$(xcrun --sdk macosx --show-sdk-version)" \
    -c "Add DTSDKBuild string $(xcrun --sdk macosx --show-sdk-build-version)" \
    -c "Add DTPlatformBuild string $(xcrun --sdk macosx --show-sdk-build-version)" \
    -c "Add DTXcode string $(xcodebuild -version | awk '/^Xcode/ {split($2, v, "."); printf "%04d", v[1] * 100 + v[2] * 10 + v[3]}')" \
    -c "Add DTXcodeBuild string $(xcodebuild -version | awk '/Build version/ {print $3}')" \
    -c "Add DTCompiler string com.apple.compilers.llvm.clang.1_0" \
    -c "Add BuildMachineOSBuild string $(sw_vers -buildVersion)" "$PLIST"

  # The App Store signature needs the profile inside the app and the app and team IDs in the entitlements.
  cp $PROFILE "$APP/Contents/embedded.provisionprofile"
  cp $ENTITLEMENTS build/appstore.entitlements
  /usr/libexec/PlistBuddy -c "Add com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" \
    -c "Add com.apple.developer.team-identifier string $TEAM_ID" build/appstore.entitlements
  # The downloaded profile carries com.apple.quarantine, which App Store Connect rejects (ITMS-91109).
  xattr -cr "$APP"
  codesign --force --sign "$APP_IDENTITY" --entitlements build/appstore.entitlements "$APP"
  rm build/appstore.entitlements
  codesign --verify --strict --deep "$APP"

  PKG="build/desktopcloth-$VERSION.pkg"
  productbuild --quiet --component "$APP" /Applications --sign "$PKG_IDENTITY" "$PKG"
  echo "Built $APP and $PKG for the Mac App Store (build $(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" Info.plist))"
  exit 0
fi

# The entitlements turn on the App Sandbox.
if [[ $1 == --notarize ]]; then
  # Notarization needs the hardened runtime and a secure timestamp.
  xattr -cr "$APP"
  codesign --force --sign "$DEV_IDENTITY" --options runtime --timestamp --entitlements $ENTITLEMENTS "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  # Ad-hoc signature: enough to run on your own Macs (first launch elsewhere needs Privacy & Security → Open Anyway).
  codesign --force --sign - --entitlements $ENTITLEMENTS "$APP"
fi

# DMG: the app, an Applications link to drag it onto and the read-me, with the app icon as the volume icon.
# Double-clicking it opens a window laid out over a background picture (dmg/background.swift) that says to drag.
DMG="build/desktopcloth-$VERSION.dmg"
VOLNAME="desktopcloth"
VOL="/Volumes/$VOLNAME"
[[ ! -e $VOL ]] || { echo "Eject the \"$VOLNAME\" disk first" >&2; exit 1; }

mkdir -p build/dmg/.background
ditto "$APP" "build/dmg/desktopcloth.app"
ln -s /Applications build/dmg/Applications
if [[ $1 == --notarize ]]; then
  # A notarized copy opens without Open Anyway, so leave out the read-me's section about it.
  awk '/^First launch on a new Mac$/ {skip = 1} /^Use$/ {skip = 0} !skip' "dmg/Read Me.txt" > "build/dmg/Read Me.txt"
else
  cp "dmg/Read Me.txt" build/dmg/
fi
swiftc -O -o build/background dmg/background.swift
[[ $1 == --notarize ]] && NOTE=notarized || NOTE=
build/background build/background.png 1 $NOTE
build/background build/background@2x.png 2 $NOTE
tiffutil -cathidpicheck build/background.png build/background@2x.png -out build/dmg/.background/background.tiff
rm build/background build/background.png build/background@2x.png

hdiutil create -quiet -volname "$VOLNAME" -srcfolder build/dmg -fs HFS+ -format UDRW build/rw.dmg
hdiutil attach -quiet -readwrite -noverify -noautoopen build/rw.dmg

# Finder saves the window layout into the volume's .DS_Store. Positions are icon centers and must match
# dmg/background.swift; the window is 640 x 500 points plus a 32-point title bar.
osascript - "$VOLNAME" <<'EOF' >/dev/null || {
on run {volName}
	tell application "Finder"
		tell disk volName
			open
			set current view of container window to icon view
			set toolbar visible of container window to false
			set statusbar visible of container window to false
			set bounds of container window to {200, 120, 840, 652}
			set opts to icon view options of container window
			set arrangement of opts to not arranged
			set icon size of opts to 112
			set text size of opts to 13
			set shows icon preview of opts to false
			set background picture of opts to file ".background:background.tiff"
			set extension hidden of item "desktopcloth.app" to true
			set extension hidden of item "Read Me.txt" to true
			set position of item "desktopcloth.app" of container window to {170, 192}
			set position of item "Applications" of container window to {470, 192}
			set position of item "Read Me.txt" of container window to {470, 348}
			-- Reopening makes Finder apply the background and save the layout.
			close
			open
		end tell
		set selection to {}
		tell disk volName
			update without registering applications
			delay 1
			close
		end tell
	end tell
end run
EOF
  hdiutil detach -quiet "$VOL"
  echo "Couldn't lay out the DMG window. If macOS asked to let your terminal control Finder, allow it" >&2
  echo "(System Settings > Privacy & Security > Automation) and run this again." >&2
  exit 1
}
for i in {1..20}; do [[ -f $VOL/.DS_Store ]] && break; sleep 0.5; done
[[ -f $VOL/.DS_Store ]] || { hdiutil detach -quiet "$VOL"; echo "Finder didn't save the DMG window layout" >&2; exit 1; }
# After the layout: Finder's update above deletes a volume icon that is already there.
cp "$APP/Contents/Resources/AppIcon.icns" "$VOL/.VolumeIcon.icns"
SetFile -a V "$VOL/.VolumeIcon.icns"
SetFile -a C "$VOL"
rm -rf "$VOL/.fseventsd"
sync
hdiutil detach -quiet "$VOL" || { sleep 2; hdiutil detach -quiet -force "$VOL"; }

hdiutil convert -quiet build/rw.dmg -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -rf build/dmg build/rw.dmg

if [[ $1 == --notarize ]]; then
  codesign --force --sign "$DEV_IDENTITY" --timestamp "$DMG"
  # Notarizing the DMG also notarizes the app inside it. The first submission from a new certificate can take
  # hours; if you stop waiting, Apple keeps going: check with `xcrun notarytool history --keychain-profile notary`,
  # then run the stapler and spctl lines below by hand.
  echo "Uploading $DMG to Apple's notary service and waiting for the result..."
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  # Stapling fails unless Apple accepted the DMG. Then `xcrun notarytool log <submission id> --keychain-profile
  # notary` says why.
  xcrun stapler staple "$DMG"
  # The same ticket covers the app, so the zip gets a stapled copy too.
  xcrun stapler staple "$APP"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG"
  spctl --assess --type execute --verbose "$APP"
fi

ditto -c -k --keepParent "$APP" "build/desktopcloth.zip"
if [[ $1 == --notarize ]]; then
  echo "Built $APP, build/desktopcloth.zip and $DMG, signed with Developer ID and notarized"
else
  echo "Built $APP, build/desktopcloth.zip and $DMG"
fi
