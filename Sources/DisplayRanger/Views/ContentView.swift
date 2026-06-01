import SwiftUI

/// Root layout: drag canvas on the left, info + profiles sidebar on the right.
struct ContentView: View {
    @EnvironmentObject var manager: DisplayManager
    @EnvironmentObject var wallpapers: WallpaperStore
    @State private var selectedID: CGDirectDisplayID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Arrangement")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button {
                        manager.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .help("Re-read the current display layout")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                DisplayCanvasView(selectedID: $selectedID)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(minWidth: 440)
            .background(Color(white: 0.09))

            ScrollView {
                VStack(spacing: 12) {
                    InfoPanelView(selectedID: selectedID)
                    ProfilesView()
                    LoginItemToggle()
                }
                .padding(14)
            }
            .frame(minWidth: 300, maxWidth: 360)
            .background(Color(white: 0.12))
        }
        .onChange(of: manager.displays) { _, displays in
            // Keep selection valid as displays come and go.
            if let id = selectedID, !displays.contains(where: { $0.id == id }) {
                selectedID = displays.first?.id
            } else if selectedID == nil {
                selectedID = displays.first(where: { $0.isPrimary })?.id ?? displays.first?.id
            }
            // Wallpapers can differ per display; reload when the set changes.
            wallpapers.refresh()
        }
    }
}
