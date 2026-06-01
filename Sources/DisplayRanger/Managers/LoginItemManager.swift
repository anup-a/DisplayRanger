import Foundation
import ServiceManagement

/// Launch-at-login via `SMAppService.mainApp` (macOS 13+).
///
/// `SMAppService.mainApp` only works inside a bundled `.app` with a bundle
/// identifier. Launched as a bare `swift run` executable there is no bundle, so
/// `isAvailable` is false and the UI disables the toggle with an explanatory hint
/// rather than throwing.
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    /// False when running outside an app bundle (e.g. `swift run`), where the
    /// ServiceManagement login-item API has nothing to register.
    let isAvailable: Bool

    init() {
        isAvailable = Bundle.main.bundleIdentifier != nil
        refresh()
    }

    private func refresh() {
        guard isAvailable else { isEnabled = false; return }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Register/unregister the app as a login item. Reverts the published state to
    /// the real system status on failure so the toggle never lies.
    func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("DisplayRanger: login-item toggle failed: \(error.localizedDescription)")
        }
        refresh()
    }
}
