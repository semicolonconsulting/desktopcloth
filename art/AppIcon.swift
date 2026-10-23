// Draws the app icon, a teal desktop with a cloth drawn over most of its icons, and writes it as an .icns file.
// Usage: AppIcon <out.icns>. build.sh runs it. Coordinates are on a 1024 canvas from the top left.
// The icns holds only PNG entries from 32 px up. macOS 27 draws the 16 and 32 px 1x entries (icp4/icp5) as noise,
// and Finder scales the 2x entries down cleanly instead.
import AppKit

let teal = NSColor(srgbRed: 0.08, green: 0.47, blue: 0.47, alpha: 1)

// The cloth's hem: a wavy diagonal from past the top edge to past the bottom edge, before the picture is turned.
func hem(offset: CGFloat = 0, amplitude: CGFloat = 26, phase: CGFloat = 0) -> [NSPoint] {
    let start = NSPoint(x: 820, y: 60), end = NSPoint(x: 140, y: 1000)
    let dx = end.x - start.x, dy = end.y - start.y, length = (dx * dx + dy * dy).squareRoot()
    let normal = NSPoint(x: dy / length, y: -dx / length) // points into the cloth (down and right)
    return (0...120).map { i in
        let t = CGFloat(i) / 120
        let wave = offset + amplitude * sin((t * 2.5 + phase) * 2 * .pi)
        return NSPoint(x: start.x + dx * t + normal.x * wave, y: start.y + dy * t + normal.y * wave)
    }
}

func path(through points: [NSPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: points[0])
    points.dropFirst().forEach { path.line(to: $0) }
    return path
}

func drawIcon(scale: CGFloat) {
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)

    // Body with a soft drop shadow. Shadow offsets are in pixels and point up, so they're scaled and negated.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
    shadow.shadowBlurRadius = 28 * scale
    shadow.set()
    teal.setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    body.addClip()

    // Desktop: blue-teal at the top to green-teal at the bottom.
    NSGradient(starting: NSColor(srgbRed: 0.25, green: 0.72, blue: 0.81, alpha: 1),
               ending: NSColor(srgbRed: 0.11, green: 0.78, blue: 0.68, alpha: 1))!
        .draw(in: NSRect(x: 100, y: 100, width: 824, height: 824), angle: 90)

    // The icons and cloth are drawn icons-top-left, then turned 90° clockwise (positive is clockwise on this
    // top-down canvas): icons top right, cloth over the bottom left. The desktop's colours and shadow aren't turned.
    let turn = NSAffineTransform()
    turn.translateX(by: 512, yBy: 512)
    turn.rotate(byDegrees: 90)
    turn.translateX(by: -512, yBy: -512)
    turn.concat()

    // Desktop icons in a 3 x 3 grid.
    NSColor.white.withAlphaComponent(0.92).setFill()
    for row in 0..<3 {
        for column in 0..<3 {
            let origin = NSPoint(x: 190 + CGFloat(column) * 178, y: 190 + CGFloat(row) * 178)
            NSBezierPath(roundedRect: NSRect(origin: origin, size: NSSize(width: 118, height: 118)),
                         xRadius: 30, yRadius: 30).fill()
        }
    }

    // The cloth, lifted off the desktop by a soft shadow along its hem.
    let cloth = path(through: hem())
    cloth.line(to: NSPoint(x: 60, y: 1000))
    cloth.line(to: NSPoint(x: 1000, y: 1000))
    cloth.line(to: NSPoint(x: 1000, y: 60))
    cloth.close()
    NSGraphicsContext.saveGraphicsState()
    let lift = NSShadow()
    lift.shadowColor = NSColor.black.withAlphaComponent(0.25)
    lift.shadowBlurRadius = 30 * scale
    lift.set()
    NSColor.white.setFill()
    cloth.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    cloth.addClip()
    NSGradient(starting: NSColor(srgbRed: 0.99, green: 1.00, blue: 1.00, alpha: 1),
               ending: NSColor(srgbRed: 0.80, green: 0.92, blue: 0.91, alpha: 1))!
        .draw(from: NSPoint(x: 380, y: 480), to: NSPoint(x: 924, y: 924), options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
    // Folds that follow the hem.
    for (offset, phase) in [(CGFloat(150), CGFloat(0.12)), (310, 0.3)] {
        let fold = path(through: hem(offset: offset, amplitude: 22, phase: phase))
        fold.lineWidth = 12
        fold.lineCapStyle = .round
        teal.withAlphaComponent(0.11).setStroke()
        fold.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let scale = CGFloat(pixels) / 1024
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    cg.translateBy(x: 0, y: CGFloat(pixels))
    cg.scaleBy(x: scale, y: -scale)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    drawIcon(scale: scale)
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

// icns: "icns" + total length, then entries of 4-byte type + length (including the 8-byte header) + PNG data.
func bigEndian(_ value: Int) -> Data { withUnsafeBytes(of: UInt32(value).bigEndian) { Data($0) } }
var entries = Data()
for (type, pixels) in [("ic11", 32), ("ic12", 64), ("ic07", 128), ("ic13", 256), ("ic08", 256),
                       ("ic14", 512), ("ic09", 512), ("ic10", 1024)] {
    let data = png(pixels: pixels)
    entries += type.data(using: .ascii)! + bigEndian(data.count + 8) + data
}
try! ("icns".data(using: .ascii)! + bigEndian(entries.count + 8) + entries)
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
