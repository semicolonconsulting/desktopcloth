// Draws the Mac App Store screenshots (2880 x 1800, the 16:10 Retina size) from the app's own views: the menu bar
// images, the plain cloth and the welcome window. The desktop, its wallpaper and its icons are made up here, so no
// real files or anyone's wallpaper appear.
// Run appstore/screenshots.sh after build.sh; it writes build/appstore/1-*.png and so on.
import AppKit
import UniformTypeIdentifiers

let canvas = NSSize(width: 1440, height: 900) // points, drawn at 2x

@main
enum Screenshots {
    static func main() {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        _ = NSApplication.shared
        NSApp.applicationIconImage = NSImage(contentsOfFile: CommandLine.arguments[2])

        let welcome = WelcomeWindow(isCovered: { false }, toggleCover: {}).preparedWindow()
        let shots: [(String, String, String, Desktop)] = [
            ("1-hide-icons", "Hide your desktop icons\nwith one click.", "desktopcloth lives in your menu bar.", .icons(callout: true)),
            ("2-wallpaper", "Your files disappear.\nYour wallpaper stays.", "Ready for screen shares, presentations\nand recordings.", .wallpaper),
            ("3-plain-cloth", "Or lay a plain cloth\nover your desktop.", "Right-click the button to switch styles.", .cloth),
            ("4-welcome", "Easy to find,\neasy to try.", "A short guide on first launch,\nwith Open at Login.", .welcome(welcome)),
        ]
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for (name, title, subtitle, desktop) in shots {
            let png = render { draw(desktop, title: title, subtitle: subtitle) }
            try! png.write(to: out.appendingPathComponent("\(name).png"))
            print("wrote \(name).png")
        }
    }
}

enum Desktop {
    case icons(callout: Bool), wallpaper, cloth, welcome(NSWindow)
}

func render(_ body: () -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width) * 2, pixelsHigh: Int(canvas.height) * 2,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = canvas
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    cg.translateBy(x: 0, y: canvas.height)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    body()
    NSGraphicsContext.current = nil
    // Screenshots go up without an alpha channel: redraw into an opaque sRGB bitmap.
    let image = rep.cgImage!
    let opaque = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    opaque.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return NSBitmapImageRep(cgImage: opaque.makeImage()!).representation(using: .png, properties: [:])!
}

func draw(_ desktop: Desktop, title: String, subtitle: String) {
    let full = NSRect(origin: .zero, size: canvas)
    var iconsHidden = true
    switch desktop {
    case .icons(let callout):
        drawWallpaper(full)
        drawDesktopIcons()
        iconsHidden = false
        drawMenuBar(iconsHidden: false, callout: callout)
    case .wallpaper:
        drawWallpaper(full)
    case .cloth:
        drawWallpaper(full)
        drawView(clothView(), in: full)
    case .welcome(let window):
        drawWallpaper(full)
        drawDesktopIcons()
        iconsHidden = false
        drawWindow(window, at: NSPoint(x: 660, y: 190))
    }
    if case .icons = desktop {} else { drawMenuBar(iconsHidden: iconsHidden, callout: false) }
    drawCaption(title: title, subtitle: subtitle)
}

// An original evening sky with soft hills, standing in for the user's wallpaper.
func drawWallpaper(_ rect: NSRect) {
    NSGradient(colors: [NSColor(srgbRed: 0.13, green: 0.17, blue: 0.38, alpha: 1),
                        NSColor(srgbRed: 0.40, green: 0.30, blue: 0.58, alpha: 1),
                        NSColor(srgbRed: 0.93, green: 0.62, blue: 0.50, alpha: 1)])!
        .draw(in: rect, angle: 90)
    let hills: [(CGFloat, CGFloat, NSColor)] = [
        (560, 70, NSColor(srgbRed: 0.33, green: 0.25, blue: 0.48, alpha: 0.55)),
        (650, 60, NSColor(srgbRed: 0.22, green: 0.18, blue: 0.38, alpha: 0.7)),
        (740, 50, NSColor(srgbRed: 0.13, green: 0.12, blue: 0.27, alpha: 0.85)),
    ]
    for (i, (y, amplitude, color)) in hills.enumerated() {
        let hill = NSBezierPath()
        hill.move(to: NSPoint(x: 0, y: rect.maxY))
        hill.line(to: NSPoint(x: 0, y: y))
        let shift = CGFloat(i) * 260
        hill.curve(to: NSPoint(x: rect.width * 0.5, y: y - amplitude * 0.4),
                   controlPoint1: NSPoint(x: 240 + shift * 0.3, y: y - amplitude), controlPoint2: NSPoint(x: 480 - shift * 0.2, y: y + amplitude))
        hill.curve(to: NSPoint(x: rect.width, y: y - amplitude * 0.2),
                   controlPoint1: NSPoint(x: 980 + shift * 0.2, y: y - amplitude * 1.2), controlPoint2: NSPoint(x: 1220 - shift * 0.3, y: y + amplitude * 0.6))
        hill.line(to: NSPoint(x: rect.width, y: rect.maxY))
        hill.close()
        color.setFill()
        hill.fill()
    }
}

// Generic files on the right-hand side, the way Finder lays out desktop icons. Icons come from each type's default
// app, so these are types that Apple's own apps open (Preview, TextEdit, QuickTime Player, Archive Utility) on the Mac
// the screenshots were made on: no third-party app icons.
func drawDesktopIcons() {
    let items: [(String, NSImage)] = [
        ("Meeting Notes.rtf", NSWorkspace.shared.icon(for: .rtf)),
        ("Invoice.pdf", NSWorkspace.shared.icon(for: .pdf)),
        ("Holiday.heic", NSWorkspace.shared.icon(for: .heic)),
        ("Photos", NSWorkspace.shared.icon(for: .folder)),
        ("Archive.zip", NSWorkspace.shared.icon(for: .zip)),
        ("Recording.mov", NSWorkspace.shared.icon(for: .quickTimeMovie)),
        ("Drafts", NSWorkspace.shared.icon(for: .folder)),
    ]
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
    shadow.shadowBlurRadius = 3
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    for (i, (name, icon)) in items.enumerated() {
        let column = CGFloat(i / 6), row = CGFloat(i % 6)
        // Below the menu bar callout in the first screenshot.
        let centre = NSPoint(x: canvas.width - 70 - column * 110, y: 140 + row * 110)
        icon.draw(in: NSRect(x: centre.x - 32, y: centre.y - 32, width: 64, height: 64))
        NSAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph, .shadow: shadow,
        ]).draw(in: NSRect(x: centre.x - 50, y: centre.y + 36, width: 100, height: 32))
    }
}

func drawMenuBar(iconsHidden: Bool, callout: Bool) {
    NSColor.black.withAlphaComponent(0.18).setFill()
    NSRect(x: 0, y: 0, width: canvas.width, height: 26).fill()
    var x: CGFloat = 20
    for (i, item) in ["Finder", "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
        let text = NSAttributedString(string: item, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: i == 0 ? .bold : .regular), .foregroundColor: NSColor.white,
        ])
        text.draw(at: NSPoint(x: x, y: 5))
        x += text.size().width + 20
    }
    let clock = NSAttributedString(string: "Fri 9:41 AM", attributes: [
        .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.white,
    ])
    clock.draw(at: NSPoint(x: canvas.width - 14 - clock.size().width, y: 5))

    // desktopcloth's own menu bar image, tinted white like other menu bar items on a dark wallpaper.
    let button = NSRect(x: canvas.width - 140, y: 3, width: 28, height: 20)
    if callout {
        NSColor.white.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: button, xRadius: 5, yRadius: 5).fill()
    }
    let image = statusImage(iconsHidden: iconsHidden)
    let white = NSImage(size: image.size, flipped: false) { rect in
        image.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceIn)
        return true
    }
    white.draw(in: NSRect(x: button.midX - 9, y: button.midY - 9, width: 18, height: 18))

    if callout {
        let text = NSAttributedString(string: "Click to cover your desktop icons", attributes: [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor(srgbRed: 0.08, green: 0.30, blue: 0.32, alpha: 1),
        ])
        let size = text.size()
        let width = size.width + 32
        let bubble = NSRect(x: min(button.midX - width / 2, canvas.width - 16 - width), y: button.maxY + 16,
                            width: width, height: size.height + 18)
        let path = NSBezierPath(roundedRect: bubble, xRadius: 10, yRadius: 10)
        path.move(to: NSPoint(x: button.midX - 9, y: bubble.minY))
        path.line(to: NSPoint(x: button.midX, y: bubble.minY - 9))
        path.line(to: NSPoint(x: button.midX + 9, y: bubble.minY))
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 12
        shadow.set()
        NSColor.white.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        text.draw(at: NSPoint(x: bubble.minX + 16, y: bubble.minY + 9))
    }
}

func drawCaption(title: String, subtitle: String) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 16
    let titleText = NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: 54, weight: .bold), .foregroundColor: NSColor.white, .shadow: shadow,
    ])
    let subtitleText = NSAttributedString(string: subtitle, attributes: [
        .font: NSFont.systemFont(ofSize: 24, weight: .regular), .foregroundColor: NSColor.white.withAlphaComponent(0.9), .shadow: shadow,
    ])
    titleText.draw(at: NSPoint(x: 90, y: 250))
    subtitleText.draw(at: NSPoint(x: 92, y: 260 + titleText.size().height + 14))
}

// The plain cloth, drawn by the app's own CoverView.
func clothView() -> NSView {
    let view = CoverView(screen: NSScreen.main!)
    view.frame = NSRect(origin: .zero, size: canvas)
    view.update(style: .cloth)
    return view
}

// Draws a view (and its subviews) at 2x into the current context.
func drawView(_ view: NSView, in rect: NSRect) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * 2), pixelsHigh: Int(view.bounds.height * 2),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: rep)
    rep.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

// The welcome window: its content drawn by AppKit, inside a hand-drawn macOS window frame with a shadow.
func drawWindow(_ window: NSWindow, at origin: NSPoint) {
    let content = window.contentView!
    content.appearance = NSAppearance(named: .aqua)
    content.layoutSubtreeIfNeeded()
    let titleBar: CGFloat = 32
    let frame = NSRect(x: origin.x, y: origin.y, width: content.bounds.width, height: content.bounds.height + titleBar)
    let shape = NSBezierPath(roundedRect: frame, xRadius: 16, yRadius: 16)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    NSColor(white: 0.98, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    for (i, color) in [NSColor(srgbRed: 1, green: 0.37, blue: 0.34, alpha: 1), NSColor(white: 0.82, alpha: 1), NSColor(white: 0.82, alpha: 1)].enumerated() {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: frame.minX + 14 + CGFloat(i) * 20, y: frame.minY + 10, width: 13, height: 13)).fill()
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    NSAttributedString(string: window.title, attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor(white: 0.3, alpha: 1), .paragraphStyle: paragraph,
    ]).draw(in: NSRect(x: frame.minX, y: frame.minY + 8, width: frame.width, height: 18))
    drawView(content, in: NSRect(x: frame.minX, y: frame.minY + titleBar, width: content.bounds.width, height: content.bounds.height))
    NSGraphicsContext.restoreGraphicsState()
}
