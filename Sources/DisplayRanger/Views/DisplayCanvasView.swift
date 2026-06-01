import SwiftUI

/// Drag-to-arrange canvas. Renders every display proportionally inside the
/// available space and lets the user drag a tile to a new position; on drop the
/// new origin is committed to macOS via `DisplayManager.move`.
struct DisplayCanvasView: View {
    @EnvironmentObject var manager: DisplayManager
    @EnvironmentObject var wallpapers: WallpaperStore
    @Binding var selectedID: CGDirectDisplayID?

    /// Live drag offset (in canvas points) for the tile being dragged.
    @State private var dragOffset: CGSize = .zero
    @State private var draggingID: CGDirectDisplayID?

    /// Scale locked to the current *set* of displays (their IDs + sizes + the
    /// canvas size), so repositioning a tile never resizes it. It's only
    /// recomputed when a display connects/disconnects or the window resizes.
    @State private var lockedScale: CGFloat = 0
    @State private var lockKey: String = ""

    private let padding: CGFloat = 36
    /// Fraction of each tile's true rect actually drawn, leaving a gap between
    /// edge-adjacent displays for device chrome.
    private static let tileInset: CGFloat = 0.90

    var body: some View {
        GeometryReader { geo in
            let key = Self.sizeKey(manager.displays, canvas: geo.size)
            let fit = CanvasLayout.fitScale(displays: manager.displays,
                                            canvas: geo.size, padding: padding)
            // Reuse the locked scale while the display set is unchanged; fall back
            // to a fresh fit on the first frame after the set changes.
            let scale = (key == lockKey && lockedScale > 0) ? lockedScale : fit
            let layout = CanvasLayout(displays: manager.displays,
                                      canvas: geo.size, scale: scale)
            ZStack {
                canvasBackground

                if manager.displays.isEmpty {
                    Text("No displays detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(manager.displays) { display in
                        let rect = layout.rect(for: display)
                        let isDragging = draggingID == display.id
                        // Inset each tile inside its true rect, centered, so
                        // edge-adjacent displays render with a small gap and their
                        // device chrome never bleeds into a neighbor.
                        let screen = CGSize(width: rect.width * Self.tileInset,
                                            height: rect.height * Self.tileInset)
                        DisplayCardView(
                            display: display,
                            isSelected: selectedID == display.id,
                            screenSize: screen,
                            wallpaper: wallpapers.images[display.id]
                        )
                        .frame(width: screen.width, height: screen.height)
                        .position(x: rect.midX + (isDragging ? dragOffset.width : 0),
                                  y: rect.midY + (isDragging ? dragOffset.height : 0))
                        .onTapGesture { selectedID = display.id }
                        .gesture(dragGesture(for: display, layout: layout))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            // Animate any change to the live display set — drag-drop settles,
            // profile restores, and connect/disconnect all glide rather than snap.
            // Keyed to `manager.displays` (not per-tile `rect`) so a live drag stays
            // 1:1 with the cursor while everything else animates.
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: manager.displays)
            .onAppear { lockedScale = fit; lockKey = key }
            .onChange(of: key) { _, newKey in lockedScale = fit; lockKey = newKey }
        }
    }

    private var canvasBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(colors: [Color(white: 0.16), Color(white: 0.10)],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    /// Identity of the current display *set* (ignores positions) + canvas size.
    private static func sizeKey(_ displays: [DisplayModel], canvas: CGSize) -> String {
        let parts = displays
            .map { "\($0.id):\(Int($0.bounds.width))x\(Int($0.bounds.height))" }
            .sorted()
        return parts.joined(separator: ",") + "@\(Int(canvas.width))x\(Int(canvas.height))"
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
                defer {
                    draggingID = nil
                    dragOffset = .zero
                }
                guard layout.scale > 0 else { return }
                // Convert canvas-space translation back into display-space points.
                let deltaX = value.translation.width / layout.scale
                let deltaY = value.translation.height / layout.scale
                let newOrigin = CGPoint(x: display.origin.x + deltaX,
                                        y: display.origin.y + deltaY)
                manager.move(displayID: display.id, to: newOrigin)
            }
    }
}

/// Pure geometry helper: maps the union of all display bounds into the canvas at a
/// caller-supplied uniform `scale`, preserving relative positions and centering
/// the result. Scale is supplied (not derived from positions) so the canvas can
/// keep tile sizes constant while displays are dragged around — see `lockedScale`.
struct CanvasLayout {
    let scale: CGFloat
    let offset: CGSize
    let unionOrigin: CGPoint

    init(displays: [DisplayModel], canvas: CGSize, scale: CGFloat) {
        self.scale = scale
        guard !displays.isEmpty else {
            offset = .zero; unionOrigin = .zero; return
        }
        var union = displays[0].bounds
        for d in displays.dropFirst() { union = union.union(d.bounds) }
        unionOrigin = union.origin

        // Center the scaled union within the canvas.
        let scaledW = union.width * scale
        let scaledH = union.height * scale
        offset = CGSize(width: (canvas.width - scaledW) / 2,
                        height: (canvas.height - scaledH) / 2)
    }

    /// Scale that fits the union of all displays into the padded canvas. Trimmed
    /// to ~88% to leave headroom for device chrome (stands hang below the screen).
    static func fitScale(displays: [DisplayModel], canvas: CGSize, padding: CGFloat) -> CGFloat {
        guard !displays.isEmpty else { return 0 }
        var union = displays[0].bounds
        for d in displays.dropFirst() { union = union.union(d.bounds) }
        let usableW = max(canvas.width - padding * 2, 1)
        let usableH = max(canvas.height - padding * 2, 1)
        return min(usableW / max(union.width, 1), usableH / max(union.height, 1)) * 0.94
    }

    func rect(for display: DisplayModel) -> CGRect {
        let x = (display.bounds.origin.x - unionOrigin.x) * scale + offset.width
        let y = (display.bounds.origin.y - unionOrigin.y) * scale + offset.height
        return CGRect(x: x, y: y,
                      width: display.bounds.width * scale,
                      height: display.bounds.height * scale)
    }
}
