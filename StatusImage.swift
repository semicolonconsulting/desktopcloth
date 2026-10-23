// Menu bar images, drawn in code as templates so macOS tints them for light and dark menu bars.
// Icons shown: a screen with a few desktop icons. Icons hidden: the same screen with a cloth drawn over it.
import AppKit

func statusImage(iconsHidden: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
        NSColor.black.set()
        let frame = NSBezierPath(roundedRect: NSRect(x: 1.75, y: 3.25, width: 14.5, height: 11.5), xRadius: 3, yRadius: 3)
        frame.lineWidth = 1.5
        frame.stroke()

        if iconsHidden {
            // A cloth inside the frame, leaving the top-right corner bare behind its wavy hem, as in the app icon.
            let inside = NSRect(x: 3.5, y: 5, width: 11, height: 8)
            NSBezierPath(roundedRect: inside, xRadius: 1.5, yRadius: 1.5).addClip()
            let cloth = NSBezierPath()
            cloth.move(to: NSPoint(x: inside.maxX, y: inside.maxY))
            cloth.line(to: NSPoint(x: inside.minX, y: inside.maxY))
            cloth.line(to: NSPoint(x: inside.minX, y: inside.minY))
            cloth.line(to: NSPoint(x: 7.5, y: inside.minY))
            cloth.curve(to: NSPoint(x: inside.maxX, y: 9.5),
                        controlPoint1: NSPoint(x: 10.5, y: 5.5), controlPoint2: NSPoint(x: 11.5, y: 9))
            cloth.close()
            cloth.fill()
        } else {
            for row in 0..<2 {
                for column in 0..<3 {
                    let icon = NSRect(x: 5 + CGFloat(column) * 3, y: 6 + CGFloat(row) * 3, width: 2, height: 2)
                    NSBezierPath(roundedRect: icon, xRadius: 0.5, yRadius: 0.5).fill()
                }
            }
        }
        return true
    }
    image.isTemplate = true
    return image
}
