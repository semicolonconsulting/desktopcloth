// The cloth: one borderless window per display, just above the desktop icons and below every other window.
// It draws the display's wallpaper, so the desktop looks empty, or a plain cloth when the wallpaper can't be read.
import AppKit
import os

private let log = Logger(subsystem: "com.semicolonc.desktopcloth", category: "cover")

enum CoverStyle: String {
    case wallpaper, cloth
}

final class Covers {
    private(set) var isShown = false
    private var windows: [NSWindow] = []
    private var timer: Timer?

    var style: CoverStyle {
        get { CoverStyle(rawValue: UserDefaults.standard.string(forKey: "coverStyle") ?? "") ?? .wallpaper }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "coverStyle"); redraw() }
    }

    // True when the wallpaper style is chosen but some display's wallpaper file couldn't be read.
    var wallpaperUnreadable: Bool {
        style == .wallpaper && views.contains { $0.wallpaperUnreadable }
    }

    private var views: [CoverView] { windows.compactMap { $0.contentView as? CoverView } }

    init() {
        let center = NotificationCenter.default, workspace = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            if self?.isShown == true { self?.rebuild() }
        }
        // Each Space can have its own wallpaper.
        workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.redraw()
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.redraw()
        }
    }

    func show() {
        isShown = true
        rebuild(fadingIn: true)
        fade(windows, to: 1)
        // macOS doesn't announce wallpaper changes, so check now and then while covered.
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.redraw() }
    }

    func hide() {
        isShown = false
        timer?.invalidate()
        timer = nil
        // Let go of the windows now, so covering again during the fade-out starts fresh ones.
        let leaving = windows
        windows = []
        fade(leaving, to: 0) { leaving.forEach { $0.orderOut(nil) } }
    }

    // Fades the cloth in or out, much as macOS fades desktop icons, or switches at once with Reduce Motion on.
    private func fade(_ windows: [NSWindow], to alpha: CGFloat, then done: @escaping () -> Void = {}) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            windows.forEach { $0.alphaValue = alpha }
            return done()
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            windows.forEach { $0.animator().alphaValue = alpha }
        }, completionHandler: done)
    }

    func redraw() {
        views.forEach { $0.update(style: style) }
    }

    // Display changes rebuild the windows straight away; covering builds them transparent, ready to fade in.
    private func rebuild(fadingIn: Bool = false) {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            // A non-activating panel: clicking the cloth doesn't bring desktopcloth to the front.
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.setFrame(screen.frame, display: false)
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.isOpaque = true
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            let view = CoverView(screen: screen)
            view.update(style: style)
            panel.contentView = view
            panel.alphaValue = fadingIn ? 0 : 1
            panel.orderFrontRegardless()
            return panel
        }
        log.info("covering \(self.windows.count, privacy: .public) display(s)")
    }
}

final class CoverView: NSView {
    private let screen: NSScreen
    private var style = CoverStyle.wallpaper
    private var wallpaperURL: URL?
    private var source: CGImageSource?
    private var dynamic: DynamicWallpaper?
    private var picture = 0
    private var wallpaper: NSImage?
    private(set) var wallpaperUnreadable = false

    init(screen: NSScreen) {
        self.screen = screen
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func update(style: CoverStyle) {
        let url = NSWorkspace.shared.desktopImageURL(for: screen)
        var changed = style != self.style
        if url != wallpaperURL || (wallpaper == nil && url != nil) {
            wallpaperURL = url
            // In the App Sandbox this fails until the user has allowed access to the wallpaper's folder.
            source = url.flatMap { CGImageSourceCreateWithURL($0 as CFURL, nil) }
            dynamic = source.flatMap { DynamicWallpaper(source: $0) }
            wallpaper = nil
        }
        // A dynamic wallpaper moves on to another picture as the day goes on, so this is checked every time.
        let index = dynamic?.index(dark: effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua) ?? 0
        if wallpaper == nil || index != picture {
            picture = index
            wallpaper = source.flatMap { CGImageSourceCreateImageAtIndex($0, index, nil) }.map { NSImage(cgImage: $0, size: .zero) }
            changed = true
        }
        let unreadable = url != nil && wallpaper == nil
        if unreadable && !wallpaperUnreadable { log.info("can't read wallpaper \(url?.path ?? "", privacy: .public)") }
        wallpaperUnreadable = unreadable
        self.style = style
        if changed { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard style == .wallpaper, let image = wallpaper else { return drawCloth() }
        let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
        (options[.fillColor] as? NSColor ?? .black).setFill()
        bounds.fill()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: wallpaperRect(for: image, options: options))
    }

    // Where macOS puts the wallpaper for its scaling options: Fill Screen, Fit to Screen, Stretch or Centre.
    private func wallpaperRect(for image: NSImage, options: [NSWorkspace.DesktopImageOptionKey: Any]) -> NSRect {
        let pixels = image.representations.first.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? image.size
        let scaling = (options[.imageScaling] as? NSNumber).flatMap { NSImageScaling(rawValue: $0.uintValue) }
            ?? .scaleProportionallyUpOrDown
        let clipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? true
        func centred(_ size: NSSize) -> NSRect {
            NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
        }
        let fit = min(bounds.width / pixels.width, bounds.height / pixels.height)
        let fill = max(bounds.width / pixels.width, bounds.height / pixels.height)
        switch scaling {
        case .scaleAxesIndependently:
            return bounds
        case .scaleNone:
            return centred(NSSize(width: pixels.width / screen.backingScaleFactor, height: pixels.height / screen.backingScaleFactor))
        case .scaleProportionallyDown:
            let factor = min(fit, 1 / screen.backingScaleFactor)
            return centred(NSSize(width: pixels.width * factor, height: pixels.height * factor))
        default:
            let factor = clipping ? fill : fit
            return centred(NSSize(width: pixels.width * factor, height: pixels.height * factor))
        }
    }

    // A plain teal cloth with a few soft folds, in the app icon's colours.
    private func drawCloth() {
        NSGradient(starting: NSColor(srgbRed: 0.30, green: 0.52, blue: 0.55, alpha: 1),
                   ending: NSColor(srgbRed: 0.16, green: 0.33, blue: 0.37, alpha: 1))!
            .draw(in: bounds, angle: -60)
        let fold = NSBezierPath()
        let step = bounds.height / 4
        for i in 0..<5 {
            let y = CGFloat(i) * step
            fold.move(to: NSPoint(x: 0, y: y))
            fold.curve(to: NSPoint(x: bounds.width, y: y + step * 0.8),
                       controlPoint1: NSPoint(x: bounds.width * 0.35, y: y + step * 0.9),
                       controlPoint2: NSPoint(x: bounds.width * 0.65, y: y - step * 0.2))
        }
        fold.lineWidth = step * 0.35
        NSColor.white.withAlphaComponent(0.035).setStroke()
        fold.stroke()
    }
}

// Sandbox access to wallpaper folders, kept as security-scoped bookmarks the user grants once.
enum WallpaperAccess {
    private static let key = "wallpaperFolders"

    static func restore() {
        for data in UserDefaults.standard.array(forKey: key) as? [Data] ?? [] {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale) {
                _ = url.startAccessingSecurityScopedResource()
            }
        }
    }

    // Asks the user to choose the folder their wallpaper is in. Returns true if they allowed it.
    static func request(suggesting wallpaper: URL?) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Allow"
        panel.message = "To lay your wallpaper over the desktop icons, desktopcloth needs to read the folder it's in."
        panel.directoryURL = wallpaper?.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return false }
        _ = url.startAccessingSecurityScopedResource()
        UserDefaults.standard.set((UserDefaults.standard.array(forKey: key) ?? []) + [data], forKey: key)
        return true
    }
}
