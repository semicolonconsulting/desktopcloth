# desktopcloth: Mac App Store listing

Everything to paste into App Store Connect for desktopcloth 1.2 (build 3). Character limits are App Store Connect's.

## App information

| Field | Value |
| --- | --- |
| Name (30) | desktopcloth |
| Subtitle (30) | Hide desktop icons in a click |
| Bundle ID | com.semicolonc.desktopcloth |
| SKU | desktopcloth |
| Primary category | Utilities |
| Secondary category | Productivity |
| Copyright | 2026 Semicolon Consulting |
| Privacy Policy URL | https://github.com/semicolonconsulting/desktopcloth/blob/main/PRIVACY.md |
| Support URL | https://github.com/semicolonconsulting/desktopcloth/issues |
| Marketing URL | https://github.com/semicolonconsulting/desktopcloth |
| Price | Your choice (free, or a price tier) |

## Promotional text (170)

Cover your desktop icons before a screen share, presentation or recording, and bring them back with one more click. Nothing on your desktop moves.

## Description (4000)

desktopcloth hides the icons on your desktop with one click, so your files stay out of sight during screen shares, presentations and recordings.

It lays a cloth over your desktop: a window that sits just above the desktop icons and below everything else. Your apps keep working as usual. Click the menu bar button again, and your icons are back exactly where they were.

FEATURES
• One click in the menu bar covers or uncovers your desktop icons.
• Cover with Wallpaper: the cloth shows your own wallpaper, so the desktop simply looks empty.
• Cover with Plain Cloth: a calm teal fabric instead.
• Covers every display, on every Space.
• Open at Login, so it's always ready.
• A short welcome guide on first launch, where you can try it right away.

PRIVATE BY DESIGN
• Nothing on your desktop is moved, renamed or deleted, and no macOS settings are changed.
• Quitting desktopcloth takes the cloth away.
• No data collected, no network access, no account.
• To show your wallpaper, desktopcloth asks once for the folder it's in, and reads it only to draw it on your screen.

desktopcloth is open source under the MIT License.

## Keywords (100)

hide,desktop,icons,clutter,screen share,presentation,meeting,recording,clean,wallpaper,privacy

## Screenshots

Mac, 2880 × 1800, in this order. Make them with `./build.sh` then `./appstore/screenshots.sh`; they land in `build/appstore/`.

1. `1-hide-icons.png`: "Hide your desktop icons with one click."
2. `2-wallpaper.png`: "Your files disappear. Your wallpaper stays."
3. `3-plain-cloth.png`: "Or lay a plain cloth over your desktop."
4. `4-welcome.png`: "Easy to find, easy to try."

## App Privacy

- Data collection: **No, we do not collect data from this app.** The label then reads "Data Not Collected".

## Age rating

Answer **None** (or **No**) to every question. The result is 4+.

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in Info.plist, so App Store Connect doesn't ask.

## App Review information

- Sign-in required: **No**.
- Contact: your name, phone and email (App Store Connect asks for them here; they aren't shown publicly).

### Notes for the reviewer (4000)

desktopcloth is a menu bar app with no Dock icon. On first launch it opens a welcome window that explains how it works.

To test without looking for the menu bar button, click "Try It: Cover Desktop" in the welcome window. The desktop icons are covered by a window that shows the wallpaper, or a plain teal cloth. Click "Uncover Desktop" to take it away. The welcome window can be reopened from the menu (Settings…).

The menu bar button is a small screen icon. Left-click covers or uncovers the desktop. Right-click shows the menu: Settings…, Cover with Wallpaper, Cover with Plain Cloth, Open at Login, Privacy Policy, and Quit desktopcloth.

How it works: one borderless window per display, at the window level just above the desktop icons (CGWindowLevelForKey(.desktopIconWindow) + 1), on all Spaces. It doesn't change any macOS settings or touch any files, and quitting removes it.

Wallpaper access: in the App Sandbox the app can read where the wallpaper is (NSWorkspace desktopImageURL) but not the picture itself. The first time the desktop is covered in the wallpaper style, an open panel suggests the wallpaper's folder. Choosing it grants read-only access (com.apple.security.files.user-selected.read-only), kept as an app-scoped security-scoped bookmark (com.apple.security.files.bookmarks.app-scope). If the panel is cancelled, the plain cloth is shown instead; both styles cover the icons.

Open at Login uses SMAppService.mainApp and is off until the user turns it on.

There's no account, no network access, no in-app purchase and no data collection.

## Before submitting

1. Join the Apple Developer Program and install Xcode.
2. In Certificates, Identifiers & Profiles, register the bundle ID `com.semicolonc.desktopcloth`.
3. Create the app record in App Store Connect with the fields above.
4. Build a signed App Store package. `build.sh` only makes ad-hoc builds; this step needs your Apple Distribution and Mac Installer Distribution certificates, and a provisioning profile.
5. Upload it with Transporter or Xcode, add the screenshots, and submit for review.
