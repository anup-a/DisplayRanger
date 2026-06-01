import SwiftUI

/// A single display tile: the screen shows the display's real wallpaper inside a
/// device frame (MacBook for built-in, iMac for external), with a legible label
/// scrim along the bottom. The device chrome is drawn *below* the screen via an
/// overlay so it never shifts the screen's positioned frame on the canvas.
struct DisplayCardView: View {
    let display: DisplayModel
    let isSelected: Bool
    /// The on-canvas size of the screen area (drives all proportions).
    let screenSize: CGSize
    let wallpaper: NSImage?

    private var bezel: CGFloat { max(2, screenSize.height * 0.035) }
    private var corner: CGFloat { max(5, min(screenSize.height, screenSize.width) * 0.06) }

    private var chromeKind: DeviceChrome.Kind { display.isBuiltin ? .laptop : .allInOne }
    private var aluminum: Color {
        display.isBuiltin ? Color(white: 0.62) : Color(white: 0.80)
    }

    var body: some View {
        screen
            .overlay(alignment: .top) { if display.isBuiltin { notch } }
            .overlay(alignment: .bottom) { chrome }
            .shadow(color: .black.opacity(isSelected ? 0.30 : 0.16),
                    radius: isSelected ? 10 : 4, y: 3)
            .contentShape(Rectangle())
    }

    // MARK: Screen

    private var screen: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color.black)

            wallpaperFill
                .clipShape(RoundedRectangle(cornerRadius: corner - bezel * 0.5))
                .padding(bezel)

            VStack(spacing: 0) { Spacer(); labelBar }
                .padding(bezel)

            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.10),
                              lineWidth: isSelected ? 3 : 1)
        }
    }

    @ViewBuilder
    private var wallpaperFill: some View {
        if let wallpaper {
            Image(nsImage: wallpaper)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(colors: [Color(white: 0.28), Color(white: 0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(
                    Image(systemName: display.isSidecar ? "ipad.landscape" : "display")
                        .font(.system(size: max(14, screenSize.height * 0.16)))
                        .foregroundStyle(.white.opacity(0.55))
                )
        }
    }

    // MARK: Label scrim

    private var labelBar: some View {
        HStack(alignment: .bottom, spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(display.name)
                    .font(.system(size: max(9, screenSize.height * 0.085), weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(display.resolutionLabel)
                    .font(.system(size: max(7, screenSize.height * 0.060)))
                    .opacity(0.85)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 2)
            if display.isPrimary {
                Text("PRIMARY")
                    .font(.system(size: max(6, screenSize.height * 0.050), weight: .bold))
                    .padding(.horizontal, 4).padding(.vertical, 1.5)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.65)],
                           startPoint: .top, endPoint: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: corner - bezel * 0.5))
        )
    }

    // MARK: Chrome + notch

    private var notch: some View {
        RoundedRectangle(cornerRadius: bezel * 0.4)
            .fill(Color.black)
            .frame(width: screenSize.width * 0.16, height: bezel * 1.1)
            .offset(y: bezel * 0.3)
    }

    private var chrome: some View {
        let furniture = DeviceChrome(kind: chromeKind, screenWidth: screenSize.width, aluminum: aluminum)
        // Anchored at the screen's bottom, pushed fully below it.
        return furniture.offset(y: furniture.height)
    }
}
