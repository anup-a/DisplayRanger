import AppKit

// Mirrors Sources/DisplayRanger/Managers/AppIcon.swift, rendered at exact pixel
// sizes for an .iconset → .icns.
func drawScreen(_ rect: NSRect, alpha: CGFloat) {
    let body = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.10, yRadius: rect.width * 0.10)
    NSColor.white.withAlphaComponent(alpha).setFill(); body.fill()
    NSColor(calibratedWhite: 0, alpha: 0.12).setStroke()
    body.lineWidth = max(1, rect.width * 0.02); body.stroke()
    let standW = rect.width * 0.30
    let stand = NSRect(x: rect.midX - standW/2, y: rect.minY - rect.height*0.10, width: standW, height: rect.height*0.10)
    NSColor.white.withAlphaComponent(alpha).setFill(); NSBezierPath(rect: stand).fill()
}

func render(_ s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s), xRadius: s*0.22, yRadius: s*0.22)
    bg.addClip()
    NSGradient(colors: [NSColor(calibratedRed:0.30,green:0.46,blue:0.96,alpha:1),
                        NSColor(calibratedRed:0.16,green:0.30,blue:0.78,alpha:1)])?
        .draw(in: NSRect(x:0,y:0,width:s,height:s), angle: -90)
    drawScreen(NSRect(x: s*0.16, y: s*0.34, width: s*0.50, height: s*0.36), alpha: 0.95)
    drawScreen(NSRect(x: s*0.50, y: s*0.20, width: s*0.34, height: s*0.26), alpha: 0.80)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = CommandLine.arguments[1]
let sizes: [(Int, String)] = [
    (16,"icon_16x16"),(32,"icon_16x16@2x"),(32,"icon_32x32"),(64,"icon_32x32@2x"),
    (128,"icon_128x128"),(256,"icon_128x128@2x"),(256,"icon_256x256"),(512,"icon_256x256@2x"),
    (512,"icon_512x512"),(1024,"icon_512x512@2x"),
]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (px, name) in sizes {
    let rep = render(CGFloat(px))
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
print("wrote \(sizes.count) icons to \(out)")
