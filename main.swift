// desktopcloth: a menu bar button that hides desktop icons by laying a cloth over them (see Covers.swift).
// Nothing on the desktop or in macOS's settings changes, and quitting takes the cloth away. It runs in the
// App Sandbox, which the Mac App Store requires.
// Left-click covers or uncovers the icons. Right-click shows a menu with Settings (the welcome window), the cloth's style, Open at Login,
// Check for Updates (GitHub copy only, see Updates.swift), the privacy policy and Quit. The first launch also shows
// the welcome window (Welcome.swift).
import AppKit
import os

private let log = Logger(subsystem: "com.semicolonc.desktopcloth", category: "toggle")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let shownImage = statusImage(iconsHidden: false)
    private let hiddenImage = statusImage(iconsHidden: true)
    private let covers = Covers()
    private lazy var welcome = WelcomeWindow(isCovered: { [unowned self] in covers.isShown },
                                             toggleCover: { [unowned self] in toggleCover() })
    private let wallpaperItem = NSMenuItem(title: "Cover with Wallpaper", action: #selector(useWallpaper), keyEquivalent: "")
    private let clothItem = NSMenuItem(title: "Cover with Plain Cloth", action: #selector(useCloth), keyEquivalent: "")
    private let accessItem = NSMenuItem(title: "Allow Access to Wallpaper…", action: #selector(allowAccess), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
    private lazy var menu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        for item in [wallpaperItem, clothItem, accessItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        #if !APPSTORE
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        #endif
        menu.addItem(withTitle: "Privacy Policy", action: #selector(openPrivacyPolicy), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit desktopcloth", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No custom autosaveName: macOS 27 then files the item under the bundle ID like every other app,
        // which menu bar managers (Thaw) need to match it.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        WallpaperAccess.restore()
        // Covers again if the icons were covered when desktopcloth last quit.
        if UserDefaults.standard.bool(forKey: "covered") { cover() }
        refresh()
        if !UserDefaults.standard.bool(forKey: "welcomed") { welcome.show() }
        #if !APPSTORE
        Updates.startAutomaticChecks()
        #endif
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }
        toggleCover()
    }

    private func toggleCover() {
        covers.isShown ? covers.hide() : cover()
        UserDefaults.standard.set(covers.isShown, forKey: "covered")
        refresh()
    }

    private func cover() {
        covers.show()
        // The first time the wallpaper can't be read, ask for its folder once; the menu can ask again later.
        if covers.wallpaperUnreadable && !UserDefaults.standard.bool(forKey: "askedForWallpaper") {
            UserDefaults.standard.set(true, forKey: "askedForWallpaper")
            DispatchQueue.main.async { self.allowAccess() }
        }
    }

    @objc private func showSettings() { welcome.show(title: "desktopcloth Settings") }
    @objc private func useWallpaper() { covers.style = .wallpaper }
    @objc private func useCloth() { covers.style = .cloth }
    @objc private func toggleOpenAtLogin() { LoginItem.set(!LoginItem.isEnabled) }
    @objc private func openPrivacyPolicy() { NSWorkspace.shared.open(privacyPolicyURL) }
    #if !APPSTORE
    @objc private func checkForUpdates() { Updates.check(userInitiated: true) }
    #endif

    @objc private func allowAccess() {
        if WallpaperAccess.request(suggesting: NSScreen.main.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }) {
            covers.redraw()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        wallpaperItem.state = covers.style == .wallpaper ? .on : .off
        clothItem.state = covers.style == .cloth ? .on : .off
        accessItem.isHidden = !covers.wallpaperUnreadable
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    private func refresh() {
        statusItem.button?.image = covers.isShown ? hiddenImage : shownImage
        statusItem.button?.toolTip = covers.isShown ? "Show desktop icons" : "Hide desktop icons"
        log.info("desktop icons covered: \(self.covers.isShown, privacy: .public)")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
