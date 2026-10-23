// desktopcloth: a menu bar toggle for macOS's built-in "Show Items: On Desktop" setting.
// Left-click hides/shows desktop icons. Right-click shows a menu with Quit.
import AppKit
import os

private let domain = "com.apple.WindowManager"
private let key = "StandardHideDesktopIcons"
private let log = Logger(subsystem: "com.semicolonc.desktopcloth", category: "toggle")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let settings = UserDefaults(suiteName: domain)!
    private let shownImage = statusImage(iconsHidden: false)
    private let hiddenImage = statusImage(iconsHidden: true)
    private lazy var menu: NSMenu = {
        let menu = NSMenu()
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

        // Keep the icon in sync when the setting is changed elsewhere (System Settings, Shortcuts).
        settings.addObserver(self, forKeyPath: key, options: [.new], context: nil)
        refresh()
    }

    private var iconsHidden: Bool {
        CFPreferencesAppSynchronize(domain as CFString)
        return settings.bool(forKey: key)
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }
        setIconsHidden(!iconsHidden)
    }

    // Same command as `defaults write`, which WindowManager picks up immediately.
    private func setIconsHidden(_ hidden: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["write", domain, key, "-bool", hidden ? "true" : "false"]
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            log.error("defaults write failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    private func refresh() {
        let hidden = iconsHidden
        statusItem.button?.image = hidden ? hiddenImage : shownImage
        statusItem.button?.toolTip = hidden ? "Show desktop icons" : "Hide desktop icons"
        log.info("desktop icons hidden: \(hidden, privacy: .public)")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async { self.refresh() }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
