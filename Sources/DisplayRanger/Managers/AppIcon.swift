import AppKit

/// Programmatic Dock/app icon.
///
/// A bare `swift run` executable has no asset catalog, so we draw the icon at
/// launch and assign it to `NSApp.applicationIconImage` — this shows in the Dock
/// and app switcher even without a bundle. When the app is later packaged as a
/// `.app`, drop a real `Assets.xcassets/AppIcon.appiconset` in and this can go.
enum AppIcon {
    /// Install the generated icon on the running application.
    static func install() {
        NSApp.applicationIconImage = make()
    }

    /// Draw a simple two-display "arrangement" glyph: a large screen with a
    /// smaller secondary screen overlapping its lower-right, on an accent field.
    static func make(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let s = size
        // Rounded-rect background with a vertical accent gradient.
        let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
                              xRadius: s * 0.22, yRadius: s * 0.22)
        bg.addClip()
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.30, green: 0.46, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.16, green: 0.30, blue: 0.78, alpha: 1),
        ])
        gradient?.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -90)

        // Primary display (larger, upper-left).
        drawScreen(rect: NSRect(x: s * 0.16, y: s * 0.34, width: s * 0.50, height: s * 0.36),
                   fill: .white, alpha: 0.95)
        // Secondary display (smaller, lower-right, overlapping).
        drawScreen(rect: NSRect(x: s * 0.50, y: s * 0.20, width: s * 0.34, height: s * 0.26),
                   fill: .white, alpha: 0.80)

        return image
    }

    private static func drawScreen(rect: NSRect, fill: NSColor, alpha: CGFloat) {
        let body = NSBezierPath(roundedRect: rect,
                                xRadius: rect.width * 0.10,
                                yRadius: rect.width * 0.10)
        fill.withAlphaComponent(alpha).setFill()
        body.fill()
        NSColor(calibratedWhite: 0, alpha: 0.12).setStroke()
        body.lineWidth = max(1, rect.width * 0.02)
        body.stroke()

        // Little stand under the screen.
        let standWidth = rect.width * 0.30
        let stand = NSRect(x: rect.midX - standWidth / 2,
                           y: rect.minY - rect.height * 0.10,
                           width: standWidth,
                           height: rect.height * 0.10)
        fill.withAlphaComponent(alpha).setFill()
        NSBezierPath(rect: stand).fill()
    }
}
