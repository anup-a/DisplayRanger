import SwiftUI

/// Details + actions for the currently selected display.
struct InfoPanelView: View {
    @EnvironmentObject var manager: DisplayManager
    let selectedID: CGDirectDisplayID?

    private var display: DisplayModel? {
        manager.displays.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Display Info", systemImage: "display")

            if let display {
                header(display)

                VStack(spacing: 9) {
                    InfoRow(label: "Resolution", value: display.resolutionLabel)
                    InfoRow(label: "Refresh", value: display.refreshLabel)
                    InfoRow(label: "Position",
                            value: "(\(Int(display.origin.x)), \(Int(display.origin.y)))")
                    InfoRow(label: "Primary", value: display.isPrimary ? "Yes" : "No",
                            accent: display.isPrimary)
                }

                VStack(spacing: 8) {
                    Button {
                        manager.setPrimary(display.id)
                    } label: {
                        Label("Set as Primary", systemImage: "star.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(display.isPrimary)

                    Button {
                        DisplayFlasher.flash(displayID: display.id, name: display.name)
                    } label: {
                        Label("Identify Display", systemImage: "sparkles")
                    }
                    .buttonStyle(SubtleActionButtonStyle())
                    .help("Flash this screen so you can tell which physical display it is")
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            } else {
                Text("Select a display on the canvas.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.vertical, 8)
            }
        }
        .sidebarCard()
    }

    /// Device glyph + name + type.
    private func header(_ display: DisplayModel) -> some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: glyph(display))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(display.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(display.typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    private func glyph(_ display: DisplayModel) -> String {
        if display.isSidecar { return "ipad.landscape" }
        if display.isBuiltin { return "laptopcomputer" }
        return "desktopcomputer"
    }
}
