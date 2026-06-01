import SwiftUI

/// Drag-to-arrange canvas. Tiles are sized by each display's **physical** size so a
/// 27" monitor visibly dwarfs a 14" laptop, positioned by the macOS point
/// arrangement, and scaled so the whole set fits the canvas with no overlap. Device
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
                dragOffset = value.translation
            }
            .onEnded { value in
                defer { draggingID = nil; dragOffset = .zero }
                guard layout.positionScale > 0 else { return }
                // Canvas translation → display-space points uses the *position* scale.
                let dx = value.translation.width / layout.positionScale
                let dy = value.translation.height / layout.positionScale
                manager.move(displayID: display.id,
                             to: CGPoint(x: display.origin.x + dx, y: display.origin.y + dy))
            }
    }

    /// Identity of the current display *set* (sizes, not positions) + canvas size.
    private static func sizeKey(_ displays: [DisplayModel], canvas: CGSize) -> String {
        displays
            .map { "\($0.id):\(Int($0.bounds.width))x\(Int($0.bounds.height)):\(Int($0.physicalWidthMM))" }
            .sorted()
            .joined(separator: ",") + "@\(Int(canvas.width))x\(Int(canvas.height))"
    }
}

/// Maps displays to canvas cells: physical-size tiles placed at point-arrangement
/// centres, uniformly scaled by `sizeScale`. Pure geometry — no SwiftUI.
struct CanvasLayout {
    private let cells: [CGDirectDisplayID: CGRect]
    /// Canvas points per display point (for converting drag deltas back to display space).
    let positionScale: CGFloat

    init(displays: [DisplayModel], canvas: CGSize, padding: CGFloat, sizeScale: CGFloat) {
        guard !displays.isEmpty else { cells = [:]; positionScale = 0; return }
        let geom = LayoutGeometry(displays: displays, canvas: canvas, padding: padding)
        positionScale = geom.positionScale
        var rects: [CGDirectDisplayID: CGRect] = [:]
        for d in displays {
            let c = geom.center(d)
            let size = geom.cellSize(d, sizeScale: sizeScale)
            rects[d.id] = CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2,
                                 width: size.width, height: size.height)
        }
        cells = rects
    }

    func cell(for display: DisplayModel) -> CGRect { cells[display.id] ?? .zero }

    /// Largest tile-size scale that keeps every cell inside the canvas and prevents
    /// any two cells from overlapping, given the point-arrangement centres.
    static func fitSizeScale(displays: [DisplayModel], canvas: CGSize, padding: CGFloat) -> CGFloat {
        guard !displays.isEmpty else { return 0 }
        let geom = LayoutGeometry(displays: displays, canvas: canvas, padding: padding)
        var k = CGFloat.greatestFiniteMagnitude

        // Canvas-fit: each cell (at unit scale) must fit centred within the padded canvas.
        for d in displays {
            let c = geom.center(d), u = geom.unitCell(d)
            k = min(k,
                    2 * (c.x - padding) / u.width,
                    2 * (canvas.width - padding - c.x) / u.width,
                    2 * (c.y - padding) / u.height,
                    2 * (canvas.height - padding - c.y) / u.height)
        }
        // Pairwise no-overlap along the axis on which the two displays are separated.
        let gap: CGFloat = 8
        for i in 0..<displays.count {
            for j in (i + 1)..<displays.count {
                let a = displays[i], b = displays[j]
                let ca = geom.center(a), cb = geom.center(b)
                let ua = geom.unitCell(a), ub = geom.unitCell(b)
                let sepX = a.bounds.maxX <= b.bounds.minX + 1 || b.bounds.maxX <= a.bounds.minX + 1
                if sepX {
                    let need = (ua.width + ub.width) / 2
                    if need > 0 { k = min(k, (abs(ca.x - cb.x) - gap) / need) }
                } else {
                    let need = (ua.height + ub.height) / 2
                    if need > 0 { k = min(k, (abs(ca.y - cb.y) - gap) / need) }
                }
            }
        }
        return max(k, 0.0001) * 0.98
    }
}

/// Shared point-arrangement → canvas math (centres, per-display cell sizing).
private struct LayoutGeometry {
    let canvas: CGSize
    let unionCenter: CGPoint
    let positionScale: CGFloat

    init(displays: [DisplayModel], canvas: CGSize, padding: CGFloat) {
        self.canvas = canvas
        var union = displays[0].bounds
        for d in displays.dropFirst() { union = union.union(d.bounds) }
        unionCenter = CGPoint(x: union.midX, y: union.midY)
        let usableW = max(canvas.width - padding * 2, 1)
        let usableH = max(canvas.height - padding * 2, 1)
        positionScale = min(usableW / max(union.width, 1), usableH / max(union.height, 1))
    }

    func center(_ d: DisplayModel) -> CGPoint {
        CGPoint(x: (d.bounds.midX - unionCenter.x) * positionScale + canvas.width / 2,
                y: (d.bounds.midY - unionCenter.y) * positionScale + canvas.height / 2)
    }

    /// Tile size at scale 1: physical width drives size; height = screen (by aspect)
    /// + device chrome reserved inside the cell.
    func unitCell(_ d: DisplayModel) -> CGSize {
        let w = basePhysicalWidth(d)
        let chrome = DeviceChrome.height(kind: d.isBuiltin ? .laptop : .allInOne, screenWidth: w)
        return CGSize(width: w, height: w / d.aspect + chrome)
    }

    func cellSize(_ d: DisplayModel, sizeScale: CGFloat) -> CGSize {
        let u = unitCell(d)
        return CGSize(width: u.width * sizeScale, height: u.height * sizeScale)
    }

    /// Physical width in mm, or the point width when the display doesn't report a
    /// physical size (e.g. Sidecar / virtual displays).
    private func basePhysicalWidth(_ d: DisplayModel) -> CGFloat {
        d.physicalWidthMM > 0 ? d.physicalWidthMM : d.bounds.width
    }
}
