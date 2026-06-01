import AppKit
import Combine
import CoreGraphics
import Foundation

/// Owns the live list of displays and wraps every CoreGraphics call that reads
/// or mutates the display arrangement.
///
/// Read path:  `CGGetOnlineDisplayList` + `CGDisplayBounds` (+ `NSScreen` for names).
/// Write path: `CGBeginDisplayConfiguration` / `CGConfigureDisplayOrigin` / `CGCompleteDisplayConfiguration`.
///
/// A `CGDisplayRegisterReconfigurationCallback` keeps `displays` in sync when the
/// hardware layout changes (connect / disconnect / rearrange from System Settings).
final class DisplayManager: ObservableObject {
    @Published private(set) var displays: [DisplayModel] = []

    /// Set while we are applying our own configuration, so the reconfiguration
    /// callback doesn't fight us with a redundant refresh mid-transaction.
    private var isApplying = false
    private var callbackRegistered = false

    // MARK: Lifecycle

    func start() {
        registerReconfigurationCallback()
        refresh()
    }

    deinit {
        if callbackRegistered {
            CGDisplayRemoveReconfigurationCallback(Self.reconfigurationCallback,
                                                   Unmanaged.passUnretained(self).toOpaque())
        }
    }

    // MARK: Reading the current arrangement

    func refresh() {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            DispatchQueue.main.async { self.displays = [] }
            return
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return }

        let nameMap = Self.screenNameMap()
        let mainID = CGMainDisplayID()

        let models: [DisplayModel] = ids.compactMap { id in
            // Skip displays that are mirror-mirrored away (we manage primaries only).
            guard CGDisplayIsOnline(id) != 0 else { return nil }
            let bounds = CGDisplayBounds(id)
            let name = nameMap[id] ?? Self.fallbackName(for: id)
            let builtin = CGDisplayIsBuiltin(id) != 0
            let sidecar = Self.looksLikeSidecar(name: name, isBuiltin: builtin)
            let mode = CGDisplayCopyDisplayMode(id)
            return DisplayModel(
                id: id,
                name: name,
                bounds: bounds,
                isPrimary: id == mainID,
                isBuiltin: builtin,
                isSidecar: sidecar,
                pixelWidth: mode?.pixelWidth ?? Int(bounds.width),
                pixelHeight: mode?.pixelHeight ?? Int(bounds.height),
                refreshHz: mode?.refreshRate ?? 0
            )
        }

        DispatchQueue.main.async { self.displays = models }
    }

    // MARK: Mutating the arrangement

    /// Move a single display so its top-left sits at `newOrigin` (display space).
    ///
    /// We commit the *whole* arrangement (not just the dragged display) and shift it
    /// so the current primary stays pinned at origin (0,0). macOS makes whichever
    /// display sits at (0,0) the primary, so committing only the dragged origin lets
    /// a drag that vacates or lands on (0,0) silently change which display is primary.
    /// Pinning the existing primary keeps it primary — dragging only repositions.
    ///
    /// macOS still snaps displays edge-adjacent, so the committed position may differ
    /// slightly from the requested one — we refresh afterward to reflect it.
    @discardableResult
    func move(displayID: CGDirectDisplayID, to newOrigin: CGPoint) -> Bool {
        var origins: [CGDirectDisplayID: CGPoint] = [:]
        for d in displays { origins[d.id] = d.origin }
        origins[displayID] = newOrigin

        if let primary = displays.first(where: { $0.isPrimary }),
           let primaryOrigin = origins[primary.id] {
            let dx = -primaryOrigin.x, dy = -primaryOrigin.y
            for (id, pt) in origins {
                origins[id] = CGPoint(x: pt.x + dx, y: pt.y + dy)
            }
        }
        return applyOrigins(origins)
    }

    /// Apply a full set of origins in one transaction (used by drag-drop and profile restore).
    @discardableResult
    func applyOrigins(_ origins: [CGDirectDisplayID: CGPoint]) -> Bool {
        guard !origins.isEmpty else { return true }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }

        isApplying = true
        defer { isApplying = false }

        for (id, origin) in origins {
            let status = CGConfigureDisplayOrigin(config, id,
                                                  Int32(origin.x.rounded()),
                                                  Int32(origin.y.rounded()))
            if status != .success {
                CGCancelDisplayConfiguration(config)
                return false
            }
        }

        let result = CGCompleteDisplayConfiguration(config, .permanently)
        refresh()
        return result == .success
    }

    /// Make `displayID` the primary display. macOS designates whichever display
    /// sits at origin (0,0) as primary, so we translate the whole arrangement by
    /// the chosen display's negative origin — preserving relative positions.
    @discardableResult
    func setPrimary(_ displayID: CGDirectDisplayID) -> Bool {
        guard let target = displays.first(where: { $0.id == displayID }) else { return false }
        guard !target.isPrimary else { return true }
        let dx = -target.origin.x
        let dy = -target.origin.y
        var origins: [CGDirectDisplayID: CGPoint] = [:]
        for d in displays {
            origins[d.id] = CGPoint(x: d.origin.x + dx, y: d.origin.y + dy)
        }
        return applyOrigins(origins)
    }

    // MARK: Name resolution

    /// Map CGDirectDisplayID → localized display name via NSScreen.
    private static func screenNameMap() -> [CGDirectDisplayID: String] {
        var map: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let id = CGDirectDisplayID(number.uint32Value)
            map[id] = screen.localizedName
        }
        return map
    }

    private static func fallbackName(for id: CGDirectDisplayID) -> String {
        CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display \(id)"
    }

    /// Best-effort Sidecar detection. There is no public flag for it, so we key off
    /// the localized name macOS assigns to an iPad acting as an external display.
    private static func looksLikeSidecar(name: String, isBuiltin: Bool) -> Bool {
        guard !isBuiltin else { return false }
        let lowered = name.lowercased()
        return lowered.contains("ipad") || lowered.contains("sidecar")
    }

    // MARK: Reconfiguration callback bridge

    private func registerReconfigurationCallback() {
        guard !callbackRegistered else { return }
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        if CGDisplayRegisterReconfigurationCallback(Self.reconfigurationCallback, ctx) == .success {
            callbackRegistered = true
        }
    }

    /// C-compatible callback. Fires twice per change (begin + end); we only act on
    /// the settled state and ignore events that arrive while we're mid-apply.
    private static let reconfigurationCallback: CGDisplayReconfigurationCallBack = {
        _, flags, userInfo in
        guard let userInfo else { return }
        let manager = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
        if manager.isApplying { return }
        // Only refresh on the "after" notifications, not the "begin" ones.
        if flags.contains(.setModeFlag) || flags.contains(.addFlag)
            || flags.contains(.removeFlag) || flags.contains(.movedFlag)
            || flags.contains(.setMainFlag) || flags.contains(.desktopShapeChangedFlag) {
            DispatchQueue.main.async { manager.refresh() }
            AutoApplyEngine.shared.handleReconfiguration(flags: flags)
        }
    }
}
