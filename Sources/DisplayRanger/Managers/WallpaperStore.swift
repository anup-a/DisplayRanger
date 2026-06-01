import AppKit
import Combine
import CoreGraphics
import Foundation
import ImageIO

/// Loads each display's desktop wallpaper (downsampled) so canvas tiles can show
/// the real picture instead of a flat color. Keyed by `CGDirectDisplayID`.
///
/// Wallpapers rarely change mid-session, so this only reloads when asked (on
/// launch and whenever the display set changes).
final class WallpaperStore: ObservableObject {
    @Published private(set) var images: [CGDirectDisplayID: NSImage] = [:]

    /// Reload every connected screen's wallpaper off the main thread.
    func refresh() {
        let workspace = NSWorkspace.shared
        var urls: [CGDirectDisplayID: URL] = [:]
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let url = workspace.desktopImageURL(for: screen) else { continue }
            urls[CGDirectDisplayID(number.uint32Value)] = url
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [CGDirectDisplayID: NSImage] = [:]
            for (id, url) in urls {
                if let image = Self.downsampled(url: url, maxPixel: 640) {
                    loaded[id] = image
                }
            }
            DispatchQueue.main.async { self.images = loaded }
        }
    }

    /// Decode a screen-sized thumbnail via ImageIO — cheap, never holds the full
    /// 4K/5K wallpaper in memory.
    private static func downsampled(url: URL, maxPixel: CGFloat) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
