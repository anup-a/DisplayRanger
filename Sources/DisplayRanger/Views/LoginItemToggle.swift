import SwiftUI

/// Footer control: start DisplayRanger automatically at login.
///
/// Disabled (with an explanatory hint) when running outside an app bundle, where
/// the ServiceManagement login-item API is unavailable — see `LoginItemManager`.
struct LoginItemToggle: View {
    @EnvironmentObject var loginItem: LoginItemManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            )) {
                Label("Launch at login", systemImage: "power")
                    .font(.callout)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.accentColor)
            .disabled(!loginItem.isAvailable)

            if !loginItem.isAvailable {
                Text("Available once installed as an app (not via swift run).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .sidebarCard()
    }
}
