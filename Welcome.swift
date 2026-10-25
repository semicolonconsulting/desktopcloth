// The welcome window, shown on first launch and from Settings… in the menu. Menu-bar-only apps are easy to
// miss, so it says where the button is, lets you try covering the desktop right away, and has the Open at Login and Check for Updates Automatically switches.
// Plain AppKit: SwiftUI's @State needs a compiler plugin that only ships with Xcode, and build.sh only needs the
// Command Line Tools.
import AppKit
import ServiceManagement
import os

private let log = Logger(subsystem: "com.semicolonc.desktopcloth", category: "welcome")

// The Mac App Store requires a privacy policy link inside the app: it's in the menu and in this window.
let privacyPolicyURL = URL(string: "https://github.com/semicolonconsulting/desktopcloth/blob/main/PRIVACY.md")!

// Open at Login, through macOS's login items (allowed in the App Sandbox, unlike launch agents).
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    // Turns it on or off and returns whether it's on afterwards. If macOS wants the user's approval first,
    // opens Login Items in System Settings.
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("login item \(on ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        return isEnabled
    }
}

final class WelcomeWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let isCovered: () -> Bool
    private let toggleCover: () -> Void
    private let loginBox = NSButton(checkboxWithTitle: "Open at Login", target: nil, action: nil)
    #if !APPSTORE
    private let updatesBox = NSButton(checkboxWithTitle: "Check for Updates Automatically", target: nil, action: nil)
    #endif
    private let tryButton = NSButton(title: "", target: nil, action: nil)

    init(isCovered: @escaping () -> Bool, toggleCover: @escaping () -> Void) {
        self.isCovered = isCovered
        self.toggleCover = toggleCover
    }

    // The menu's Settings… opens it too, under its own title.
    func show(title: String = "Welcome to desktopcloth") {
        let window = preparedWindow()
        window.title = title
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // The window, built and up to date but not shown. appstore/Screenshots.swift draws it from here.
    func preparedWindow() -> NSWindow {
        if window == nil { window = makeWindow() }
        update()
        return window!
    }

    // It counts as seen once it's closed, so quitting before reading it shows it again next time.
    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "welcomed")
    }

    // The menu bar button and menu can change things while the window is open.
    func windowDidBecomeKey(_ notification: Notification) { update() }

    private func update() {
        loginBox.state = LoginItem.isEnabled ? .on : .off
        #if !APPSTORE
        updatesBox.state = Updates.checksAutomatically ? .on : .off
        #endif
        tryButton.title = isCovered() ? "Uncover Desktop" : "Try It: Cover Desktop"
    }

    @objc private func toggleLogin() {
        LoginItem.set(loginBox.state == .on)
        update()
    }

    #if !APPSTORE
    @objc private func toggleUpdates() { Updates.checksAutomatically = updatesBox.state == .on }
    #endif

    @objc private func tryIt() {
        toggleCover()
        update()
    }

    @objc private func done() { window?.close() }
    @objc private func openPrivacyPolicy() { NSWorkspace.shared.open(privacyPolicyURL) }

    private func makeWindow() -> NSWindow {
        let width: CGFloat = 540, inset: CGFloat = 24
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true
        let titles = NSStackView(views: [label("desktopcloth", font: .systemFont(ofSize: 22, weight: .semibold)),
                                         label("Hide your desktop icons with one click.", color: .secondaryLabelColor)])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 4
        let header = NSStackView(views: [icon, titles])
        header.spacing = 16

        let textWidth = width - inset * 2 - 36
        let steps = [
            (statusImage(iconsHidden: false),
             "Click the desktopcloth button in the menu bar to cover your desktop icons. Click it again to bring them back."),
            (symbol("contextualmenu.and.cursorarrow"),
             "Right-click the button to cover with your wallpaper or a plain cloth, or to quit."),
            (symbol("folder"),
             "To show your wallpaper on the cloth, desktopcloth asks once for the folder your wallpaper is in."),
            (symbol("menubar.rectangle"),
             "Can't see the button? A full menu bar, the notch or a menu bar manager can hide it. You can try it here too."),
        ].map { image, text in step(image, text, width: textWidth) }

        let separator = NSBox()
        separator.boxType = .separator

        loginBox.target = self
        loginBox.action = #selector(toggleLogin)
        tryButton.target = self
        tryButton.action = #selector(tryIt)
        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        var settings: [NSView] = [loginBox]
        #if !APPSTORE
        updatesBox.target = self
        updatesBox.action = #selector(toggleUpdates)
        settings.append(updatesBox)
        #endif
        let checkboxes = NSStackView(views: settings)
        checkboxes.orientation = .vertical
        checkboxes.alignment = .leading
        checkboxes.spacing = 8
        // The spacer gives way first, so the checkbox titles are never cut short.
        checkboxes.setContentCompressionResistancePriority(.required, for: .horizontal)
        let controls = NSStackView(views: [checkboxes, spacer, tryButton, doneButton])

        let privacy = NSButton(title: "Privacy Policy", target: self, action: #selector(openPrivacyPolicy))
        privacy.isBordered = false
        privacy.contentTintColor = .linkColor
        privacy.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let footer = NSStackView(views: [label("Version \(version)  ·", font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                                               color: .secondaryLabelColor), privacy])
        footer.spacing = 4

        let stack = NSStackView(views: [header] + steps + [separator, controls, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: inset, left: inset, bottom: 20, right: inset)
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
        for row in [separator, controls] {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -inset * 2).isActive = true
        }

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to desktopcloth"
        window.contentView = stack
        window.isReleasedWhenClosed = false
        window.delegate = self
        stack.layoutSubtreeIfNeeded()
        window.setContentSize(stack.fittingSize)
        window.center()
        return window
    }

    private func label(_ text: String, font: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
                       color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        return field
    }

    private func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))!
    }

    private func step(_ image: NSImage, _ text: String, width: CGFloat) -> NSView {
        let imageView = NSImageView(image: image)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let field = NSTextField(wrappingLabelWithString: text)
        field.preferredMaxLayoutWidth = width
        let row = NSStackView(views: [imageView, field])
        row.alignment = .top
        row.spacing = 12
        return row
    }
}
