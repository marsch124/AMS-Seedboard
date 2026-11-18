import SwiftUI

#if os(iOS)
import UIKit

/// iPad with a trackpad, a Magic Keyboard or a mouse: the two-finger scroll of the trackpad (or a mouse
/// wheel) moves a timeline or a "Who does what" board, and ⌘ with scrolling zooms round the pointer —
/// what `ScrollCatcher` does on the Mac and what `TouchLayer` already does on an ordinary board.
/// The pinch on the glass (and the trackpad's pinch) stays with the boards' own `MagnifyGesture`.
///
/// A scroll is no touch, so it is found by its own recogniser. The recogniser lives on the top view of
/// the screen (the boards' content lies over this little background view, so nothing below it is asked)
/// and answers only for scrolling that happens inside this view's own box.
struct TrackpadCatcher: UIViewRepresentable {
    let session: BoardSession

    func makeUIView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.session = session
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: CatcherView, context: Context) { view.session = session }

    final class CatcherView: UIView, UIGestureRecognizerDelegate {
        weak var session: BoardSession?
        private let scroll = UIPanGestureRecognizer()
        private weak var host: UIView?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            host?.removeGestureRecognizer(scroll)
            host = nil
            guard window != nil else { return }
            var top: UIView = self
            while let next = top.superview, !(next is UIWindow) { top = next }
            // No touch types at all: this one only hears the scrolling of a trackpad and of a mouse wheel.
            scroll.allowedTouchTypes = []
            scroll.allowedScrollTypesMask = .all
            scroll.cancelsTouchesInView = false
            scroll.delegate = self
            scroll.addTarget(self, action: #selector(scrolled(_:)))
            top.addGestureRecognizer(scroll)
            host = top
        }

        deinit { host?.removeGestureRecognizer(scroll) }

        override func gestureRecognizerShouldBegin(_ recogniser: UIGestureRecognizer) -> Bool {
            recogniser === scroll ? bounds.contains(recogniser.location(in: self)) : super.gestureRecognizerShouldBegin(recogniser)
        }

        func gestureRecognizer(_ a: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer) -> Bool { true }

        @objc private func scrolled(_ recogniser: UIPanGestureRecognizer) {
            guard recogniser.state == .began || recogniser.state == .changed, let session else { return }
            // Each time only the way since the last time.
            let way = recogniser.translation(in: self)
            recogniser.setTranslation(.zero, in: self)
            guard way != .zero, way.x.isFinite, way.y.isFinite else { return }
            if recogniser.modifierFlags.contains(.command) {
                // ⌘ and scrolling: zoom by 1 % per point, round the pointer (as on the Mac).
                var at = recogniser.location(in: self)
                if !bounds.contains(at) { at = CGPoint(x: bounds.midX, y: bounds.midY) }
                session.zoom(to: session.scale * exp(min(max(way.y, -60), 60) * 0.01), around: at)
            } else {
                session.pan(by: CGSize(width: way.x, height: way.y))
            }
        }
    }
}
#endif
