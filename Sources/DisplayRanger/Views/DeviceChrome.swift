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
        case .laptop:    return screenWidth * 0.052
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

    // MARK: MacBook — a thin foreshortened deck (gently tapered, rounded front,
    // small centered thumb notch) with a recessed dark hinge where it meets the lid.

    private var laptop: some View {
        let w = screenWidth
        let h = height
        return ZStack(alignment: .top) {
            LaptopDeck()
                .fill(
                    LinearGradient(colors: [aluminum.opacity(0.78), aluminum],
                                   startPoint: .top, endPoint: .bottom)
                )
                .overlay(  // bright front lip to suggest the slab's thickness
                    LaptopDeck().stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                )
                .frame(width: w, height: h)

            // Recessed dark hinge line, flush where the lid meets the deck.
            Capsule(style: .continuous)
                .fill(Color(white: 0.22))
                .frame(width: w * 0.5, height: max(1.5, h * 0.20))
        }
        .frame(width: w, height: h)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
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
        let topInset = rect.width * 0.045          // gentle taper — not a funnel
        let r = min(rect.height * 0.45, rect.width * 0.03)
        let scoopW = rect.width * 0.11             // small, subtle thumb notch
        let scoopDepth = rect.height * 0.55
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
