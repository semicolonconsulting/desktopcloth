# desktopcloth

A macOS menu bar button that hides and shows the icons on your desktop.
<img width="543" height="279" alt="desktopcloth_icon" src="https://github.com/user-attachments/assets/20967639-7ad3-47c1-b31b-c72fc94ac8fc" />

Click it before a screen share, a presentation or a recording, and the files on your desktop are out of sight. Click it again to bring them back. It flips macOS's own setting (System Settings → Desktop & Dock → Show Items → On Desktop), so nothing is moved or deleted.

<img width="543" height="369" alt="desktopcloth" src="https://github.com/user-attachments/assets/3bfc30bb-09ef-4f3b-9547-191812d93db5" />


## Requirements

macOS 13 Ventura or later, on Intel or Apple Silicon. Tested on macOS 27.

## Install

1. Download `desktopcloth-<version>.dmg` from [Releases](https://github.com/semicolonconsulting/desktopcloth/releases) and open it.
2. Drag **desktopcloth** onto the **Applications** folder in the window that opens.
3. Open desktopcloth from Applications.

The app isn't notarized by Apple, so the first launch is blocked with a message that macOS "could not verify" it. To allow it, open System Settings → Privacy & Security, scroll down to the message about desktopcloth and click **Open Anyway**. You only need to do this once. Alternatively, run:

```bash
xattr -dr com.apple.quarantine /Applications/desktopcloth.app
```

To start it automatically, add it under System Settings → General → Login Items & Extensions → Open at Login.

## Usage

- Click the menu bar button to hide or show desktop icons. While they're hidden, the button shows a cloth over the screen.
- Right-click the button for **Quit desktopcloth**.
- If you change the setting in System Settings, the button follows.

If you use a menu bar manager such as Bartender, Ice or Thaw, it may put the new button in its hidden section. Move it out in that app's settings.

## How it works

The button runs `defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true` (or `false`), the preference behind the System Settings switch. macOS picks it up immediately. desktopcloth has no network access and collects no data.

## Build from source

You need the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/semicolonconsulting/desktopcloth.git
cd desktopcloth
./build.sh
```

`build.sh` creates `build/desktopcloth.app`, `build/desktopcloth.zip` and `build/desktopcloth-<version>.dmg`. The app is ad-hoc signed. While it makes the DMG, a Finder window opens briefly to lay out the install window, and the first run asks to let your terminal control Finder. Eject any mounted `desktopcloth` disk before building.

| File | What it is |
| --- | --- |
| `main.swift` | The menu bar app |
| `StatusImage.swift` | The menu bar images, drawn in code |
| `art/AppIcon.swift` | The app icon, drawn when you build |
| `dmg/` | The DMG window background and the read-me inside the DMG |
| `build.sh` | Builds the app, the zip and the DMG |

## Uninstall

Quit desktopcloth and move it from Applications to the Trash. If you quit while icons are hidden, they stay hidden. Turn them back on under System Settings → Desktop & Dock → Show Items → On Desktop.

## License

MIT. See [LICENSE](LICENSE).
