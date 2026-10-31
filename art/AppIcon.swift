// Draws the app icon in the Liquid Glass style and writes it as an .icns file: a navy to sky blue desktop with glass
// icons, a sheet of frosted glass cloth drawn over most of them, and light catching the edges.
// Usage: AppIcon <out.icns>. build.sh runs it. Coordinates are on a 1024 canvas from the top left.
// The icns holds only PNG entries from 32 px up. macOS 27 draws the 16 and 32 px 1x entries (icp4/icp5) as noise,
// and Finder scales the 2x entries down cleanly instead.
import AppKit
import CoreImage

let navy = NSColor(srgbRed: 0.07, green: 0.17, blue: 0.40, alpha: 1)
let sky = NSColor(srgbRed: 0.40, green: 0.76, blue: 0.98, alpha: 1)
func white(_ alpha: CGFloat) -> NSColor { NSColor.white.withAlphaComponent(alpha) }

// The cloth's hem: a wavy diagonal from past the top edge to past the bottom edge, before it's turned (see turned).
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

// The cloth is laid out over the top left, then turned 90° clockwise about the centre (positive is clockwise on this
// top-down canvas) to lie over the bottom left.
func turned(_ path: NSBezierPath) -> NSBezierPath {
    let turn = NSAffineTransform()
    turn.translateX(by: 512, yBy: 512)
    turn.rotate(byDegrees: 90)
    turn.translateX(by: -512, yBy: -512)
    let copy = path.copy() as! NSBezierPath
    copy.transform(using: turn as AffineTransform)
    return copy
}

// A ring just inside a rounded rect, for light catching a glass edge.
func rim(_ rect: NSRect, radius: CGFloat, width: CGFloat) -> NSBezierPath {
    let ring = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    ring.append(NSBezierPath(roundedRect: rect.insetBy(dx: width, dy: width), xRadius: radius - width, yRadius: radius - width))
    ring.windingRule = .evenOdd
    return ring
}

// Edge light, strongest at the top left and bottom right as on Liquid Glass. Drawn at 45°: top left to bottom right.
func edgeLight(_ peak: CGFloat, _ low: CGFloat, _ end: CGFloat) -> NSGradient {
    NSGradient(colors: [white(peak), white(low), white(low), white(end)], atLocations: [0, 0.4, 0.6, 1], colorSpace: .sRGB)!
}

func drawIcon(scale: CGFloat, context cg: CGContext) {
    let frame = NSRect(x: 100, y: 100, width: 824, height: 824)
    let body = NSBezierPath(roundedRect: frame, xRadius: 185, yRadius: 185)

    // Body with a soft drop shadow. Shadow offsets are in pixels and point up, so they're scaled and negated.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
    shadow.shadowBlurRadius = 28 * scale
    shadow.set()
    navy.setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    body.addClip()

    // Desktop: navy at the top to sky blue at the bottom, with a soft light behind the icons.
    NSGradient(starting: navy, ending: sky)!.draw(in: frame, angle: 90)
    let glow = NSColor(srgbRed: 0.55, green: 0.80, blue: 1.0, alpha: 1)
    NSGradient(starting: glow.withAlphaComponent(0.3), ending: glow.withAlphaComponent(0))!
        .draw(fromCenter: NSPoint(x: 690, y: 300), radius: 0, toCenter: NSPoint(x: 690, y: 300), radius: 360, options: [])

    // Desktop icons: a 3 x 3 grid of glass tiles at the top right, raised by a soft shadow.
    let tiles = (0..<9).map { i in
        NSRect(x: 716 - CGFloat(i % 3) * 178, y: 190 + CGFloat(i / 3) * 178, width: 118, height: 118)
    }
    NSGraphicsContext.saveGraphicsState()
    let raise = NSShadow()
    raise.shadowColor = NSColor.black.withAlphaComponent(0.18)
    raise.shadowOffset = NSSize(width: 0, height: -6 * scale)
    raise.shadowBlurRadius = 20 * scale
    raise.set()
    cg.beginTransparencyLayer(auxiliaryInfo: nil) // one shadow for the whole grid, not one per tile
    let face = NSGradient(starting: white(0.84), ending: white(0.68))!
    tiles.forEach { face.draw(in: NSBezierPath(roundedRect: $0, xRadius: 32, yRadius: 32), angle: 90) }
    cg.endTransparencyLayer()
    NSGraphicsContext.restoreGraphicsState()
    let tileLight = edgeLight(1, 0.25, 0.7)
    tiles.forEach { tileLight.draw(in: rim($0, radius: 32, width: 3), angle: 45) }

    // The cloth, a sheet of frosted glass: what's under it shows through, blurred and whitened. A shadow beside the
    // hem lifts it off the desktop.
    let cloth = path(through: hem())
    cloth.line(to: NSPoint(x: 60, y: 1000))
    cloth.line(to: NSPoint(x: 1000, y: 1000))
    cloth.line(to: NSPoint(x: 1000, y: 60))
    cloth.close()
    let sheet = turned(cloth)
    let under = frosted(cg.makeImage()!, radius: 26 * scale)
    NSGraphicsContext.saveGraphicsState()
    let lift = NSShadow()
    lift.shadowColor = NSColor(srgbRed: 0.02, green: 0.06, blue: 0.18, alpha: 0.3)
    lift.shadowBlurRadius = 44 * scale
    lift.set()
    NSColor.white.setFill()
    sheet.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    sheet.addClip()
    cg.saveGState()
    cg.concatenate(cg.ctm.inverted()) // the snapshot is in pixels, from the bottom left
    cg.draw(under, in: CGRect(x: 0, y: 0, width: under.width, height: under.height))
    cg.restoreGState()
    NSGradient(starting: white(0.86), ending: NSColor(srgbRed: 0.80, green: 0.89, blue: 0.99, alpha: 0.86))!
        .draw(from: NSPoint(x: 140, y: 520), to: NSPoint(x: 560, y: 1080), options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
    // Light along the hem and along two folds that follow it.
    for (points, width, alpha) in [(hem(offset: 4), CGFloat(4), CGFloat(0.95)),
                                   (hem(offset: 179, amplitude: 22, phase: 0.12), 5, 0.55),
                                   (hem(offset: 339, amplitude: 22, phase: 0.3), 5, 0.55)] {
        let line = turned(path(through: points))
        line.lineWidth = width
        line.lineCapStyle = .round
        line.lineJoinStyle = .round
        white(alpha).setStroke()
        line.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Light catching the body's edge.
    edgeLight(0.98, 0.18, 0.68).draw(in: rim(frame, radius: 185, width: 4), angle: 45)

    NSGraphicsContext.restoreGraphicsState()
}

// A Gaussian blur of the picture so far, for the frosted cloth.
func frosted(_ image: CGImage, radius: CGFloat) -> CGImage {
    let input = CIImage(cgImage: image)
    let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
    return CIContext().createCGImage(blurred, from: input.extent)!
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
    drawIcon(scale: scale, context: cg)
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
