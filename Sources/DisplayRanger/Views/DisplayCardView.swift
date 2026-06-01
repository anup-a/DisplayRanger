import SwiftUI

/// A single display tile: the screen (real wallpaper, bezel, label) on top with the
/// device chrome (MacBook deck / iMac stand) directly below — both laid out *inside*
/// the cell so nothing protrudes into a neighbouring tile.
struct DisplayCardView: View {
    let display: DisplayModel
    let isSelected: Bool
    /// Full cell size (screen + chrome) allotted by the canvas layout.
    let cell: CGSize
    let wallpaper: NSImage?

    /// Screen height derived from the display's true aspect; the remainder of the
    /// cell holds the device chrome.
    private var screenHeight: CGFloat { cell.width / display.aspect }
    private var chromeHeight: CGFloat { max(0, cell.height - screenHeight) }

    private var bezel: CGFloat { max(2, screenHeight * 0.035) }
    private var corner: CGFloat { max(5, min(screenHeight, cell.width) * 0.06) }
    private var chromeKind: DeviceChrome.Kind { display.isBuiltin ? .laptop : .allInOne }
    private var aluminum: Color { display.isBuiltin ? Color(white: 0.62) : Color(white: 0.80) }

    var body: some View {
        VStack(spacing: 0) {
            screen
                .frame(width: cell.width, height: screenHeight)
                .overlay(alignment: .top) { if display.isBuiltin { notch } }
                .shadow(color: .black.opacity(isSelected ? 0.30 : 0.16),
                        radius: isSelected ? 10 : 4, y: 3)

            DeviceChrome(kind: chromeKind, screenWidth: cell.width, aluminum: aluminum)
                .frame(width: cell.width, height: chromeHeight)
        }
        .frame(width: cell.width, height: cell.height)
        .contentShape(Rectangle())
    }

    // MARK: Screen

    private var screen: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner).fill(Color.black)

            wallpaperFill
                .clipShape(RoundedRectangle(cornerRadius: corner - bezel * 0.5))
                .padding(bezel)

            VStack(spacing: 0) { Spacer(); labelBar }.padding(bezel)

            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.10),
                              lineWidth: isSelected ? 3 : 1)
        }
    }

    @ViewBuilder
    private var wallpaperFill: some View {
        if let wallpaper {
            Image(nsImage: wallpaper).resizable().aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(colors: [Color(white: 0.28), Color(white: 0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(
                    Image(systemName: display.isSidecar ? "ipad.landscape" : "display")
                        .font(.system(size: max(14, screenHeight * 0.16)))
                        .foregroundStyle(.white.opacity(0.55))
                )
        }
    }

    private var labelBar: some View {
        HStack(alignment: .bottom, spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(display.name)
                    .font(.system(size: max(9, screenHeight * 0.085), weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(display.resolutionLabel)
                    .font(.system(size: max(7, screenHeight * 0.060)))
                    .opacity(0.85).lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 2)
            if display.isPrimary {
                Text("PRIMARY")
                    .font(.system(size: max(6, screenHeight * 0.05), weight: .bold))
                    .padding(.horizontal, 4).padding(.vertical, 1.5)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.65)],
                           startPoint: .top, endPoint: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: corner - bezel * 0.5))
        )
    }

    private var notch: some View {
        RoundedRectangle(cornerRadius: bezel * 0.4)
            .fill(Color.black)
            .frame(width: cell.width * 0.16, height: bezel * 1.1)
            .offset(y: bezel * 0.3)
    }
}
