# Build from source

You need the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/semicolonconsulting/desktopcloth.git
cd desktopcloth
./build.sh
```

`build.sh` creates `build/desktopcloth.app`, `build/desktopcloth.zip` and `build/desktopcloth-<version>.dmg`. The app is ad-hoc signed with the App Sandbox turned on. While it makes the DMG, a Finder window opens briefly to lay out the install window, and the first run asks to let your terminal control Finder. Eject any mounted `desktopcloth` disk before building.

`./build.sh --appstore` builds only the app, for the Mac App Store: it leaves out Check for Updates, since the App Store updates the app, and has no network access.

## Source files

| File | What it is |
| --- | --- |
| `main.swift` | The menu bar button and its menu |
| `Covers.swift` | The cloth windows, and access to the wallpaper folder |
| `DynamicWallpaper.swift` | Picks the picture a dynamic wallpaper is showing right now |
| `Welcome.swift` | The welcome window, and Open at Login |
| `Updates.swift` | Check for Updates, against GitHub Releases (not in the App Store build) |
| `StatusImage.swift` | The menu bar images, drawn in code |
| `art/AppIcon.swift` | The app icon, drawn when you build |
| `desktopcloth.entitlements` | The App Sandbox and the file access it allows (Mac App Store build) |
| `desktopcloth-github.entitlements` | The same, plus network access for Check for Updates (GitHub build) |
| `dmg/` | The DMG window background and the read-me inside the DMG |
| `appstore/` | The Mac App Store listing text, and the script that draws its screenshots |
| `docs/` | This guide, and the pictures in the README |
| `build.sh` | Builds the app, the zip and the DMG, or with `--appstore` the App Store app |
