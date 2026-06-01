import CoreGraphics
import Foundation

/// A snapshot of a single connected display, derived from CoreGraphics + NSScreen.
///
/// All geometry is expressed in the global *display* coordinate space used by
/// `CGDisplayBounds` (origin top-left, y increasing downward). This is the same
/// space `CGConfigureDisplayOrigin` expects, so we never have to convert between
/// the AppKit (bottom-left) and CoreGraphics (top-left) conventions.
struct DisplayModel: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    /// Global bounds in CoreGraphics display space (points).
    let bounds: CGRect
    let isPrimary: Bool
    let isBuiltin: Bool
    let isSidecar: Bool
    /// Pixel dimensions of the active mode.
    let pixelWidth: Int
    let pixelHeight: Int
    /// Refresh rate in Hz (0 if unavailable, e.g. some built-in panels report 0).
    let refreshHz: Double
    /// Physical screen size in millimetres (`CGDisplayScreenSize`); 0 if the display
    /// doesn't report it (e.g. some virtual / Sidecar displays). Used to scale canvas
    /// tiles by real-world size so a 27" monitor visibly dwarfs a 14" laptop.
    let physicalWidthMM: CGFloat
    let physicalHeightMM: CGFloat

    var origin: CGPoint { bounds.origin }
    var size: CGSize { bounds.size }

    /// Aspect ratio (width / height) from the point bounds.
    var aspect: CGFloat { bounds.width / max(bounds.height, 1) }

    /// Diagonal in inches, or nil when the physical size is unknown.
    var diagonalInches: Double? {
        guard physicalWidthMM > 0, physicalHeightMM > 0 else { return nil }
        let mm = (physicalWidthMM * physicalWidthMM + physicalHeightMM * physicalHeightMM).squareRoot()
        return Double(mm) / 25.4
    }

    /// Human-readable type label for the info panel.
    var typeLabel: String {
        if isSidecar { return "iPad (Sidecar)" }
        if isBuiltin { return "Built-in" }
        return "External"
    }

    var resolutionLabel: String {
        "\(pixelWidth) × \(pixelHeight)"
    }

    var refreshLabel: String {
        refreshHz > 0 ? String(format: "%.0f Hz", refreshHz) : "—"
    }
}
