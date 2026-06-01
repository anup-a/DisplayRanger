import Combine
import CoreGraphics
import Foundation

/// One saved display layout.
struct LayoutProfile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var entries: [DisplayEntry]
    /// If true, AutoApplyEngine restores this profile when its displays connect.
    var autoApplyOnConnect: Bool = false
    var createdAt: Date = Date()

    /// Stable UUIDs of every display this profile describes.
    var displayUUIDs: Set<String> { Set(entries.map { $0.displayUUID }) }
}

/// A display's position within a profile, keyed by persistent UUID.
struct DisplayEntry: Codable, Equatable {
    var displayUUID: String
    /// Friendly name captured at save time (display only; matching uses the UUID).
    var displayName: String
    var originX: Double
    var originY: Double
    var isPrimary: Bool
}

/// Loads/saves profiles to ~/Library/Application Support/DisplayRanger/profiles.json
/// and applies them against the live display set.
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [LayoutProfile] = []

    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("DisplayRanger", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("profiles.json")
        load()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([LayoutProfile].self, from: data) {
            profiles = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: CRUD

    /// Capture the current arrangement as a new named profile.
    func save(name: String, displays: [DisplayModel]) {
        let entries = displays.map { d in
            DisplayEntry(displayUUID: DisplayIdentity.uuid(for: d.id),
                         displayName: d.name,
                         originX: Double(d.origin.x),
                         originY: Double(d.origin.y),
                         isPrimary: d.isPrimary)
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? defaultName() : trimmed
        // Overwrite a same-named profile rather than duplicating it.
        if let idx = profiles.firstIndex(where: { $0.name == finalName }) {
            profiles[idx].entries = entries
            profiles[idx].createdAt = Date()
        } else {
            profiles.append(LayoutProfile(name: finalName, entries: entries))
        }
        persist()
    }

    func delete(_ profile: LayoutProfile) {
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    func setAutoApply(_ enabled: Bool, for profile: LayoutProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx].autoApplyOnConnect = enabled
        persist()
    }

    private func defaultName() -> String {
        var n = 1
        while profiles.contains(where: { $0.name == "Layout \(n)" }) { n += 1 }
        return "Layout \(n)"
    }

    // MARK: Applying

    /// Restore a profile. Per the v1 spec we **apply what's present**: displays in
    /// the profile that aren't currently connected are skipped, the rest are moved.
    /// Returns the names of any missing displays (for optional UI feedback).
    @discardableResult
    func apply(_ profile: LayoutProfile, manager: DisplayManager) -> [String] {
        let live = manager.displays
        var origins: [CGDirectDisplayID: CGPoint] = [:]
        var primaryUUID: String?
        var missing: [String] = []

        for entry in profile.entries {
            guard let id = DisplayIdentity.currentDisplayID(forUUID: entry.displayUUID, among: live) else {
                missing.append(entry.displayName)
                continue
            }
            origins[id] = CGPoint(x: entry.originX, y: entry.originY)
            if entry.isPrimary { primaryUUID = entry.displayUUID }
        }

        guard !origins.isEmpty else { return missing }

        // macOS requires the main display at origin (0,0); a layout where no display
        // sits there can be rejected by CGCompleteDisplayConfiguration.
        if let primaryUUID,
           let primaryID = DisplayIdentity.currentDisplayID(forUUID: primaryUUID, among: live),
           let primaryOrigin = origins[primaryID] {
            // Profile's primary is connected: normalize so it sits at (0,0).
            let dx = -primaryOrigin.x, dy = -primaryOrigin.y
            for (id, pt) in origins {
                origins[id] = CGPoint(x: pt.x + dx, y: pt.y + dy)
            }
        } else {
            // Profile's primary is missing (e.g. it was the iPad): shift the present
            // displays so the top-left-most one lands at (0,0), preserving relative
            // positions. Without this, restoring a primary-less subset can fail.
            let minX = origins.values.map { $0.x }.min() ?? 0
            let minY = origins.values.map { $0.y }.min() ?? 0
            if minX != 0 || minY != 0 {
                for (id, pt) in origins {
                    origins[id] = CGPoint(x: pt.x - minX, y: pt.y - minY)
                }
            }
        }

        manager.applyOrigins(origins)
        return missing
    }
}
