import AppKit
import CoreGraphics
import SwiftUI

/// Briefly flashes a full-screen colored overlay on a *single* physical display so
/// the user can tell which physical screen a canvas tile maps to ("which display
/// is this?").
///
/// Uses a transient borderless window on the target screen rather than
/// `CGDisplayFade`, which dims every display at once and so can't identify one.
enum DisplayFlasher {
    /// Map the CoreGraphics display ID back to its AppKit `NSScreen`.
    private static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return number?.uint32Value == displayID
        }
    }

    static func flash(displayID: CGDirectDisplayID, name: String) {
        guard let screen = screen(for: displayID) else { return }

        let window = NSWindow(contentRect: screen.frame,
                              styleMask: .borderless,
                              backing: .buffered,
                              defer: false,
                              screen: screen)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: FlashOverlay(name: name))
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        window.contentView = host
        window.setFrame(screen.frame, display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()

        // Two pulses, then dismiss — distinct enough to spot at a glance.
        pulse(window, steps: [(0.85, 0.12), (0.0, 0.20), (0.85, 0.12), (0.0, 0.28)]) {
            window.orderOut(nil)
        }
    }

    /// Run an alpha keyframe sequence `[(targetAlpha, duration)]` then call `done`.
    private static func pulse(_ window: NSWindow,
                              steps: [(alpha: CGFloat, duration: TimeInterval)],
                              done: @escaping () -> Void) {
        guard let step = steps.first else { done(); return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = step.duration
            window.animator().alphaValue = step.alpha
        } completionHandler: {
            pulse(window, steps: Array(steps.dropFirst()), done: done)
        }
    }
}

/// The flashed overlay: an accent wash with the display's name, large enough to
/// read from across a desk.
private struct FlashOverlay: View {
    let name: String

    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.55)
            Text(name)
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.4), radius: 10, y: 2)
                .padding(40)
        }
        .ignoresSafeArea()
    }
}
