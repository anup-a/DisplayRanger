import CoreGraphics
import Foundation

/// Watches for display connect events and, when a profile flagged
/// `autoApplyOnConnect` has all of its displays present, restores it automatically.
///
/// Wired as a singleton because the CoreGraphics reconfiguration callback is a
/// C function pointer with no per-instance context beyond the DisplayManager.
final class AutoApplyEngine {
    static let shared = AutoApplyEngine()
    private init() {}

    private weak var manager: DisplayManager?
    private weak var store: ProfileStore?

    /// Debounce: reconfiguration fires several times per change; coalesce them.
    private var pendingWork: DispatchWorkItem?
    /// Avoid re-applying the same profile repeatedly for one settle.
    private var lastAppliedProfileID: UUID?

    func configure(manager: DisplayManager, store: ProfileStore) {
        self.manager = manager
        self.store = store
    }

    /// Called from DisplayManager's reconfiguration callback. We only react to
    /// topology changes (add/remove), not pure rearrangements the user is making.
    func handleReconfiguration(flags: CGDisplayChangeSummaryFlags) {
        guard flags.contains(.addFlag) || flags.contains(.removeFlag) else { return }

        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.evaluate() }
        pendingWork = work
        // Let the arrangement settle before we read it and decide.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func evaluate() {
        guard let manager, let store else { return }
        let liveUUIDs = Set(manager.displays.map { DisplayIdentity.uuid(for: $0.id) })

        // Candidate = auto-apply profile whose displays are ALL currently connected.
        // Prefer the most specific match (largest display set).
        let candidate = store.profiles
            .filter { $0.autoApplyOnConnect && $0.displayUUIDs.isSubset(of: liveUUIDs) }
            .max { $0.entries.count < $1.entries.count }

        guard let candidate else {
            lastAppliedProfileID = nil
            return
        }
        // Don't thrash if we already applied this profile for the current topology.
        guard candidate.id != lastAppliedProfileID else { return }
        lastAppliedProfileID = candidate.id
        store.apply(candidate, manager: manager)
    }
}
