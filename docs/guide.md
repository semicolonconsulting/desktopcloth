# Desktopcloth guide

Desktopcloth is a menu bar button that hides and shows the icons on your desktop. Click it before a screen share, a presentation or a recording, and the files on your desktop are out of sight. Click it again to bring them back.

It lays a cloth over the desktop: a window that sits just above the desktop icons and below everything else, showing your wallpaper or a plain cloth. Nothing on your desktop is moved, deleted or changed.

- [Requirements](#requirements)
- [Install](#install)
- [Usage](#usage)
- [Wallpaper access](#wallpaper-access)
- [How it works](#how-it-works)
- [Limitations](#limitations)
- [Upgrading from 1.0](#upgrading-from-10)
- [Uninstall](#uninstall)

## Requirements

macOS 13 Ventura or later, on Intel or Apple Silicon. Tested on macOS 27.

## Install

1. Download `desktopcloth-<version>.dmg` from [Releases](https://github.com/semicolonconsulting/desktopcloth/releases) and open it.
2. Drag **Desktopcloth** onto the **Applications** folder in the window that opens.
3. Open Desktopcloth from Applications.

The copy from GitHub isn't notarized by Apple, so the first launch is blocked with a message that macOS "could not verify" it. To allow it, open System Settings → Privacy & Security, scroll down to the message about Desktopcloth and click **Open Anyway**. You only need to do this once. Alternatively, run:

```bash
xattr -dr com.apple.quarantine /Applications/desktopcloth.app
```

## Usage

The first time Desktopcloth opens, a welcome window shows where its button is. You can also cover the desktop from there with **Try It**, and turn on **Open at Login**.

- Click the menu bar button to cover or uncover the desktop icons. While they're covered, the button shows a cloth over the screen.
- Right-click the button to choose what the cloth looks like:
  - **Cover with Wallpaper** (the default): the cloth shows your wallpaper, so the desktop just looks empty.
  - **Cover with Plain Cloth**: a calm teal fabric.
- The right-click menu also has:
  - **Settings…**, which opens the welcome window again, with Open at Login and Check for Updates Automatically;
  - **Open at Login**, to start Desktopcloth when you log in;
  - **Check for Updates…**, which asks GitHub whether there's a newer version and offers to download it; unless you turn off **Check for Updates Automatically**, here or in Settings, it also checks about once a week (only in the copy from GitHub: the App Store updates its copy itself);
  - **Privacy Policy** and **Quit Desktopcloth**.
- Quitting takes the cloth away. If you quit while the desktop is covered, it's covered again the next time Desktopcloth opens.

If you use a menu bar manager such as Bartender, Ice or Thaw, it may put the new button in its hidden section. Move it out in that app's settings.

## Wallpaper access

Desktopcloth runs in the App Sandbox, so it can only read files you allow. The first time you cover the desktop with the wallpaper style, it asks you to choose the folder your wallpaper is in, and opens that folder for you. Click **Allow**. You only need to do this once per folder. Until then, or if you click Cancel, the plain cloth is shown instead. To allow a folder later, right-click the button and choose **Allow Access to Wallpaper…**.

## How it works

Each display gets a borderless window at the level just above the desktop icons. It appears on every Space and stays put in Mission Control. The window draws the display's current wallpaper, using the same scaling as System Settings (Fill Screen, Fit to Screen, Stretch or Centre), and checks every few seconds whether the wallpaper has changed. The cloth fades in and out, unless Reduce Motion is on.

Dynamic wallpapers, such as Catalina, change picture through the day. Desktopcloth shows the same picture as the desktop. For wallpapers that follow the sun, it works out where the sun is from your Mac's time zone, using that zone's main city instead of your exact location.

Desktopcloth doesn't change any macOS settings and collects no data. The only network access is Check for Updates in the copy from GitHub, which asks GitHub for the latest release about once a week (you can turn that off in the menu or in Settings). The Mac App Store copy has no network access at all. See the [privacy policy](../PRIVACY.md).

## Limitations

- While the desktop is covered, clicking it doesn't select Finder, and you can't drop files onto it.
- With a dynamic wallpaper, the cloth can switch scenes slightly before or after the desktop does, since it uses your time zone's city rather than your exact location. If you chose a still Light or Dark version of a dynamic wallpaper, the cloth may show another scene.
- Animated wallpapers may show as a still picture, or as the plain cloth if Desktopcloth can't read them.

## Upgrading from 1.0

Version 1.0 hid icons with macOS's own setting instead. If you hid your icons with 1.0, they stay hidden after upgrading. Turn them back on under System Settings → Desktop & Dock → Show Items → On Desktop.

## Uninstall

Quit Desktopcloth and move it from Applications to the Trash. Its settings stay in `~/Library/Containers/com.semicolonc.desktopcloth`, which you can also move to the Trash.
