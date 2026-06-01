import SwiftUI

/// Decorative device "furniture" drawn directly beneath a display tile's screen:
/// a MacBook deck for built-in displays, an iMac chin + stand for externals.
///
/// It lays itself out from the top down with a known `height`, so the caller can
/// anchor it flush under the screen (`.overlay(alignment: .bottom)` + `.offset`)
/// without disturbing the screen's positioned frame — keeping every tile's screen
/// center aligned to its real display position on the canvas.
///
/// All chrome is kept within the screen's width (no horizontal overhang) so tiles
/// never bleed into an edge-adjacent neighbor.
struct DeviceChrome: View {
    enum Kind { case laptop, allInOne }

    let kind: Kind
    /// Width of the screen this chrome hangs under.
    let screenWidth: CGFloat
    let aluminum: Color

    /// Total drawn height, used by the caller to offset the chrome below the screen.
    var height: CGFloat {
        switch kind {
        case .laptop:    return screenWidth * 0.075
        case .allInOne:  return chinHeight + neckHeight + footHeight
        }
    }

    private var chinHeight: CGFloat { screenWidth * 0.080 }
    private var neckHeight: CGFloat { screenWidth * 0.065 }
    private var footHeight: CGFloat { screenWidth * 0.028 }

    var body: some View {
        switch kind {
        case .laptop: laptop
        case .allInOne: imac
        }
    }

    // MARK: MacBook — a foreshortened keyboard deck (tapered, rounded front,
    // centered thumb scoop) with a darker hinge bar where it meets the screen.

    private var laptop: some View {
        let w = screenWidth
        let h = height
        return ZStack(alignment: .top) {
            LaptopDeck()
                .fill(
                    LinearGradient(colors: [aluminum.opacity(0.68), aluminum],
                                   startPoint: .top, endPoint: .bottom)
                )
                .overlay(LaptopDeck().stroke(Color.black.opacity(0.18), lineWidth: 0.5))
                .frame(width: w, height: h)

            // Hinge bar, flush at the top where the lid meets the deck.
            RoundedRectangle(cornerRadius: h * 0.22, style: .continuous)
                .fill(aluminum.opacity(0.45))
                .frame(width: w * 0.74, height: max(2, h * 0.16))
                .offset(y: -h * 0.04)
        }
        .frame(width: w, height: h)
        .shadow(color: .black.opacity(0.28), radius: 2.5, y: 1.5)
    }

    // MARK: iMac — flush chin, slim neck, curved foot (all within screen width).

    private var imac: some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(bottomLeadingRadius: chinHeight * 0.32,
                                   bottomTrailingRadius: chinHeight * 0.32,
                                   style: .continuous)
                .fill(LinearGradient(colors: [aluminum.opacity(0.95), aluminum.opacity(0.78)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: screenWidth, height: chinHeight)
            Rectangle()
                .fill(aluminum.opacity(0.82))
                .frame(width: screenWidth * 0.10, height: neckHeight)
            Capsule(style: .continuous)
                .fill(LinearGradient(colors: [aluminum.opacity(0.85), aluminum.opacity(0.55)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: screenWidth * 0.38, height: footHeight)
        }
        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
    }
}

/// A foreshortened MacBook deck: full screen width at the front (bottom), tapered
/// inward at the hinge (top), with rounded front corners and a shallow centered
/// thumb scoop on the front edge.
private struct LaptopDeck: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topInset = rect.width * 0.085
        let r = min(rect.height * 0.55, rect.width * 0.05)
        let scoopW = rect.width * 0.16
        let scoopDepth = rect.height * 0.42
        let midX = rect.midX

        // Top edge (at the hinge), inset on both sides for the taper.
        p.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        // Right edge down to a rounded front-right corner.
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        // Front edge → thumb scoop → continue.
        p.addLine(to: CGPoint(x: midX + scoopW / 2, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: midX - scoopW / 2, y: rect.maxY),
                       control: CGPoint(x: midX, y: rect.maxY - scoopDepth))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        // Rounded front-left corner back up to the top.
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
