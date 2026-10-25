#!/bin/zsh
# Draws the Mac App Store screenshots (appstore/Screenshots.swift) into build/appstore.
# Run ./build.sh first: the app icon comes from the built app.
set -e
cd "${0:A:h}/.."

mkdir -p build/appstore
# Info.plist is embedded so the welcome window shows the app's version.
swiftc -O -o build/screenshots appstore/Screenshots.swift Covers.swift DynamicWallpaper.swift StatusImage.swift Welcome.swift \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist
build/screenshots build/appstore build/desktopcloth.app/Contents/Resources/AppIcon.icns
rm build/screenshots
