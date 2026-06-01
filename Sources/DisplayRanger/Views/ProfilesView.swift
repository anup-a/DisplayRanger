import SwiftUI

/// Save / restore / delete named layout profiles, with an auto-apply toggle.
struct ProfilesView: View {
    @EnvironmentObject var manager: DisplayManager
    @EnvironmentObject var store: ProfileStore

    @State private var newName: String = ""
    @State private var lastMissing: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHeader("Profiles", systemImage: "square.stack.3d.up")

            HStack(spacing: 8) {
                TextField("Profile name", text: $newName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    )
                    .onSubmit(saveCurrent)
                Button("Save", action: saveCurrent)
                    .buttonStyle(.plain)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(manager.displays.isEmpty ? Color.secondary : Color.accentColor)
                    .disabled(manager.displays.isEmpty)
            }

            if store.profiles.isEmpty {
                Text("No saved profiles yet. Arrange your displays, then save.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 7) {
                    ForEach(store.profiles) { profile in
                        profileRow(profile)
                    }
                }
            }

            if !lastMissing.isEmpty {
                Label("Skipped (not connected): \(lastMissing.joined(separator: ", "))",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .sidebarCard()
    }

    private func saveCurrent() {
        store.save(name: newName, displays: manager.displays)
        newName = ""
        lastMissing = []
    }

    private func profileRow(_ profile: LayoutProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name).font(.callout.weight(.semibold))
                    Text("\(profile.entries.count) display\(profile.entries.count == 1 ? "" : "s")")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    lastMissing = store.apply(profile, manager: manager)
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Restore this layout")

                Button(role: .destructive) {
                    store.delete(profile)
                } label: {
                    Image(systemName: "trash")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete profile")
            }
            Toggle("Auto-apply when its displays connect", isOn: Binding(
                get: { profile.autoApplyOnConnect },
                set: { store.setAutoApply($0, for: profile) }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
