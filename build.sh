#!/bin/zsh
# Builds "desktopcloth.app" (Apple silicon + Intel, macOS 13+) into ./build, zips it and packs it into a DMG.
# Needs the Xcode Command Line Tools: xcode-select --install
# To install the result: quit the running app, then copy build/desktopcloth.app to ~/Applications or /Applications.
# For other Macs, share build/desktopcloth-<version>.dmg. Making it briefly opens a Finder window, and the first
# run asks to let your terminal control Finder.
set -e
cd "${0:A:h}"

APP="build/desktopcloth.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -target arm64-apple-macos13.0 -o build/desktopcloth-arm64 main.swift Covers.swift StatusImage.swift
swiftc -O -target x86_64-apple-macos13.0 -o build/desktopcloth-x86_64 main.swift Covers.swift StatusImage.swift
lipo -create -output "$APP/Contents/MacOS/desktopcloth" build/desktopcloth-arm64 build/desktopcloth-x86_64
rm build/desktopcloth-arm64 build/desktopcloth-x86_64

cp Info.plist "$APP/Contents/"
# The app icon is drawn by art/AppIcon.swift; the menu bar images are drawn at runtime by StatusImage.swift.
swiftc -O -o build/AppIcon art/AppIcon.swift
build/AppIcon "$APP/Contents/Resources/AppIcon.icns"
rm build/AppIcon

# Ad-hoc signature: enough to run on your own Macs (first launch elsewhere needs Privacy & Security → Open Anyway).
# desktopcloth.entitlements turns on the App Sandbox.
codesign --force --sign - --entitlements desktopcloth.entitlements "$APP"
ditto -c -k --keepParent "$APP" "build/desktopcloth.zip"

# DMG: the app, an Applications link to drag it onto and the read-me, with the app icon as the volume icon.
# Double-clicking it opens a window laid out over a background picture (dmg/background.swift) that says to drag.
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
DMG="build/desktopcloth-$VERSION.dmg"
VOLNAME="desktopcloth"
VOL="/Volumes/$VOLNAME"
[[ ! -e $VOL ]] || { echo "Eject the \"$VOLNAME\" disk first" >&2; exit 1; }

mkdir -p build/dmg/.background
ditto "$APP" "build/dmg/desktopcloth.app"
ln -s /Applications build/dmg/Applications
cp "dmg/Read Me.txt" build/dmg/
swiftc -O -o build/background dmg/background.swift
build/background build/background.png 1
build/background build/background@2x.png 2
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
echo "Built $APP, build/desktopcloth.zip and $DMG"
