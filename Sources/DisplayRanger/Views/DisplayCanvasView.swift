import SwiftUI

/// Drag-to-arrange canvas. Tiles are sized by each display's **physical** size (so a
/// 27" monitor dwarfs a 14" laptop) and **packed edge-to-edge** following the macOS
/// arrangement, so displays stick together like the native Displays pane. Device
/// chrome is drawn *inside* each tile, so nothing protrudes into a neighbour.
struct DisplayCanvasView: View {
    @EnvironmentObject var manager: DisplayManager
    @EnvironmentObject var wallpapers: WallpaperStore
    @Binding var selectedID: CGDirectDisplayID?

    @State private var dragOffset: CGSize = .zero
    @State private var draggingID: CGDirectDisplayID?

    /// Tile-size scale locked to the current display *set*, so dragging only moves
    /// tiles — it never resizes them. Recomputed on connect/disconnect/resize.
    @State private var lockedScale: CGFloat = 0
    @State private var lockKey: String = ""

    private let padding: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            let key = Self.sizeKey(manager.displays, canvas: geo.size)
            let fit = CanvasLayout.fitSizeScale(displays: manager.displays,
                                                canvas: geo.size, padding: padding)
            let scale = (key == lockKey && lockedScale > 0) ? lockedScale : fit
            let layout = CanvasLayout(displays: manager.displays, canvas: geo.size,
                                      padding: padding, sizeScale: scale)
            ZStack {
                canvasBackground

                if manager.displays.isEmpty {
                    Text("No displays detected").foregroundStyle(.secondary)
                } else {
                    ForEach(manager.displays) { display in
                        let cell = layout.cell(for: display)
                        let isDragging = draggingID == display.id
                        DisplayCardView(
                            display: display,
                            isSelected: selectedID == display.id,
                            cell: cell.size,
                            wallpaper: wallpapers.images[display.id]
                        )
                        .frame(width: cell.width, height: cell.height)
                        .position(x: cell.midX + (isDragging ? dragOffset.width : 0),
                                  y: cell.midY + (isDragging ? dragOffset.height : 0))
                        .onTapGesture { selectedID = display.id }
                        .gesture(dragGesture(for: display, layout: layout))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: manager.displays)
            .onAppear { lockedScale = fit; lockKey = key }
            .onChange(of: key) { _, newKey in lockedScale = fit; lockKey = newKey }
        }
    }

    private var canvasBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.10)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func dragGesture(for display: DisplayModel, layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if draggingID != display.id {
                    draggingID = display.id
                    selectedID = display.id
                }
                // Always snap the live preview flush to a neighbour — a display can
                // never be dragged into a detached or overlapping position.
                dragOffset = snappedOffset(for: display, rawTranslation: value.translation, layout: layout)
            }
            .onEnded { value in
                let snapped = snappedOffset(for: display, rawTranslation: value.translation, layout: layout)
                defer { draggingID = nil; dragOffset = .zero }
                let perPx = layout.displayPointsPerCanvasPoint(for: display)
                guard perPx > 0 else { return }
                manager.move(displayID: display.id,
                             to: CGPoint(x: display.origin.x + snapped.width * perPx,
                                         y: display.origin.y + snapped.height * perPx))
            }
    }

    /// Snap the dragged tile flush against whichever neighbour edge is nearest, so the
    /// arrangement is always contiguous (sticky) and never overlapping. Returns the
    /// canvas-space offset from the tile's resting cell to its snapped position.
    private func snappedOffset(for display: DisplayModel,
                               rawTranslation: CGSize,
                               layout: CanvasLayout) -> CGSize {
        let me = layout.cell(for: display)
        let others = manager.displays.filter { $0.id != display.id }.map { layout.cell(for: $0) }
        guard !others.isEmpty, me.width > 0 else { return rawTranslation }

        let free = me.offsetBy(dx: rawTranslation.width, dy: rawTranslation.height)
        var best: CGRect?
        var bestDist = CGFloat.greatestFiniteMagnitude

        for o in others {
            // Keep ≥30% overlap along the shared edge so it stays attached while sliding.
            let minVOverlap = min(me.height, o.height) * 0.3
            let yClamped = min(max(free.minY, o.minY - me.height + minVOverlap), o.maxY - minVOverlap)
            let minHOverlap = min(me.width, o.width) * 0.3
            let xClamped = min(max(free.minX, o.minX - me.width + minHOverlap), o.maxX - minHOverlap)

            let candidates = [
                CGRect(x: o.maxX, y: yClamped, width: me.width, height: me.height),            // right of o
                CGRect(x: o.minX - me.width, y: yClamped, width: me.width, height: me.height),  // left of o
                CGRect(x: xClamped, y: o.maxY, width: me.width, height: me.height),             // below o
                CGRect(x: xClamped, y: o.minY - me.height, width: me.width, height: me.height), // above o
            ]
            for c in candidates where !overlapsAny(c, others) {
                let d = hypot(c.midX - free.midX, c.midY - free.midY)
                if d < bestDist { bestDist = d; best = c }
            }
        }
        guard let b = best else { return rawTranslation }
        return CGSize(width: b.minX - me.minX, height: b.minY - me.minY)
    }

    /// True if `rect` meaningfully overlaps any of `others` (edge-touching is allowed).
    private func overlapsAny(_ rect: CGRect, _ others: [CGRect]) -> Bool {
        let r = rect.insetBy(dx: 1, dy: 1)
        return others.contains { $0.intersects(r) }
    }

    /// Identity of the current display *set* (sizes, not positions) + canvas size.
    private static func sizeKey(_ displays: [DisplayModel], canvas: CGSize) -> String {
        displays
            .map { "\($0.id):\(Int($0.bounds.width))x\(Int($0.bounds.height)):\(Int($0.physicalWidthMM))" }
            .sorted()
            .joined(separator: ",") + "@\(Int(canvas.width))x\(Int(canvas.height))"
    }
}

/// Packs displays into canvas cells: physical-size tiles laid **edge-to-edge** along
/// the macOS arrangement (no gaps — displays stick together), then uniformly scaled
/// by `sizeScale` and centred. Pure geometry — no SwiftUI.
struct CanvasLayout {
    private let cells: [CGDirectDisplayID: CGRect]
    private let displays: [CGDirectDisplayID: DisplayModel]

    init(displays: [DisplayModel], canvas: CGSize, padding: CGFloat, sizeScale: CGFloat) {
        var byID: [CGDirectDisplayID: DisplayModel] = [:]
        for d in displays { byID[d.id] = d }
        self.displays = byID

        guard !displays.isEmpty else { cells = [:]; return }
        let pack = DisplayPacker.pack(displays)            // edge-to-edge, unit (mm) space
        let usableW = max(canvas.width - padding * 2, 1)
        let offX = padding + (usableW - pack.bounds.width * sizeScale) / 2
        let usableH = max(canvas.height - padding * 2, 1)
        let offY = padding + (usableH - pack.bounds.height * sizeScale) / 2

        var rects: [CGDirectDisplayID: CGRect] = [:]
        for (id, r) in pack.cells {
            rects[id] = CGRect(x: (r.minX - pack.bounds.minX) * sizeScale + offX,
                               y: (r.minY - pack.bounds.minY) * sizeScale + offY,
                               width: r.width * sizeScale, height: r.height * sizeScale)
        }
        cells = rects
    }

    func cell(for display: DisplayModel) -> CGRect { cells[display.id] ?? .zero }

    /// Display points per canvas point for a tile (for converting drag deltas).
    func displayPointsPerCanvasPoint(for display: DisplayModel) -> CGFloat {
        let w = cells[display.id]?.width ?? 0
        return w > 0 ? display.bounds.width / w : 0
    }

    /// Largest scale that fits the packed arrangement inside the padded canvas.
    static func fitSizeScale(displays: [DisplayModel], canvas: CGSize, padding: CGFloat) -> CGFloat {
        guard !displays.isEmpty else { return 0 }
        let pack = DisplayPacker.pack(displays)
        let usableW = max(canvas.width - padding * 2, 1)
        let usableH = max(canvas.height - padding * 2, 1)
        let s = min(usableW / max(pack.bounds.width, 1), usableH / max(pack.bounds.height, 1))
        return max(s, 0.0001) * 0.98
    }
}

/// Lays display cells edge-to-edge in unit (millimetre) space, mirroring the macOS
/// point arrangement: each non-anchor display is attached to an already-placed
/// neighbour on the shared edge, offset along that edge by the same fraction it has
/// in point space. Cell = physical screen + device chrome reserved below it.
enum DisplayPacker {
    struct Result { let cells: [CGDirectDisplayID: CGRect]; let bounds: CGRect }

    static func pack(_ displays: [DisplayModel]) -> Result {
        guard let anchor = displays.first(where: { $0.isPrimary }) ?? displays.first else {
            return Result(cells: [:], bounds: .zero)
        }
        var placed: [CGDirectDisplayID: CGRect] = [anchor.id: rect(at: .zero, for: anchor)]
        var queue = [anchor]

        while let p = queue.first {
            queue.removeFirst()
            for q in displays where placed[q.id] == nil {
                guard let side = side(of: q, relativeTo: p) else { continue }
                placed[q.id] = place(q, side: side, near: p, pRect: placed[p.id]!)
                queue.append(q)
            }
        }
        // Disconnected displays (rare): drop them to the right of the union.
        var union = placed.values.first ?? .zero
        for r in placed.values { union = union.union(r) }
        for d in displays where placed[d.id] == nil {
            let r = rect(at: CGPoint(x: union.maxX + 12, y: union.minY), for: d)
            placed[d.id] = r
            union = union.union(r)
        }
        return Result(cells: placed, bounds: union)
    }

    private enum Side { case right, left, above, below }

    private static func cellSize(_ d: DisplayModel) -> CGSize {
        let w = d.physicalWidthMM > 0 ? d.physicalWidthMM : d.bounds.width
        let chrome = DeviceChrome.height(kind: d.isBuiltin ? .laptop : .allInOne, screenWidth: w)
        return CGSize(width: w, height: w / d.aspect + chrome)
    }

    private static func rect(at origin: CGPoint, for d: DisplayModel) -> CGRect {
        CGRect(origin: origin, size: cellSize(d))
    }

    /// Which side of `p` display `q` sits on, if their point bounds share an edge.
    private static func side(of q: DisplayModel, relativeTo p: DisplayModel) -> Side? {
        let tol: CGFloat = 2
        let a = p.bounds, b = q.bounds
        let yOverlap = a.minY < b.maxY - tol && b.minY < a.maxY - tol
        let xOverlap = a.minX < b.maxX - tol && b.minX < a.maxX - tol
        if abs(b.minX - a.maxX) <= tol && yOverlap { return .right }
        if abs(b.maxX - a.minX) <= tol && yOverlap { return .left }
        if abs(b.minY - a.maxY) <= tol && xOverlap { return .below }
        if abs(b.maxY - a.minY) <= tol && xOverlap { return .above }
        return nil
    }

    private static func place(_ q: DisplayModel, side: Side, near p: DisplayModel, pRect: CGRect) -> CGRect {
        let s = cellSize(q)
        let fracY = (q.bounds.minY - p.bounds.minY) / max(p.bounds.height, 1)
        let fracX = (q.bounds.minX - p.bounds.minX) / max(p.bounds.width, 1)
        switch side {
        case .right: return CGRect(x: pRect.maxX, y: pRect.minY + fracY * pRect.height, width: s.width, height: s.height)
        case .left:  return CGRect(x: pRect.minX - s.width, y: pRect.minY + fracY * pRect.height, width: s.width, height: s.height)
        case .below: return CGRect(x: pRect.minX + fracX * pRect.width, y: pRect.maxY, width: s.width, height: s.height)
        case .above: return CGRect(x: pRect.minX + fracX * pRect.width, y: pRect.minY - s.height, width: s.width, height: s.height)
        }
    }
}
