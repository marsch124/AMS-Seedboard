#if os(iOS)
import UIKit
import SeedboardCore

// Writing straight onto a shape with the Pencil (0.5, pick 30): Apple's Scribble, told where the
// things with words lie on the board. Writing over a box then starts typing in it — no two
// presses first. Which things take writing is a rule in SeedboardCore (`Board.takesWriting`).
//
// OFF until `Finger.scribbleOntoShapes` is flipped (PencilSwitches.swift): it needs a real iPad
// with a Pencil to tune and has never been seen running. The traps it is built round:
//   - The Pencil on a thing also chooses and moves it, and a still press of half a second opens
//     its menu. When the system says the writing has begun, that press is given up and the small
//     shove taken back — unless the tip has already gone further than 10 points from where it
//     landed (`InkShape.dragWins`): then it is a drag, the thing moves, and the writing is dropped.
//   - The words go into the board's own typing field (CanvasView.swift), which shows a moment
//     after `beginEdit`: it is looked for until it holds the keys, then handed to the system.
//   - While the Draw tool or the arrow tool is on the Pencil draws or joins: nothing is offered.

/// UIKit calls these on the main thread; the board's session lives there too (`MainActor.assumeIsolated`,
/// as the Pencil's double-tap listener in InkViews.swift does).
final class ShapeScribble: NSObject, UIIndirectScribbleInteractionDelegate {
    typealias ElementIdentifier = UUID

    private weak var surface: TouchSurface?
    /// The thing a drag won on since the writing began: its writing is dropped.
    private var dropped: UUID?

    /// Sets Scribble up on the board's touch surface — only when the feature is switched on.
    @MainActor
    func attach(to surface: TouchSurface) {
        self.surface = surface
        guard Finger.scribbleOntoShapes else { return }
        surface.addInteraction(UIIndirectScribbleInteraction(delegate: self))
    }

    /// The open board, when the Pencil may write into its things right now.
    @MainActor
    private var session: BoardSession? {
        guard let session = surface?.session, !session.readOnly, !session.ink.on, !session.linking else { return nil }
        return session
    }

    // MARK: Where the things with words lie

    func indirectScribbleInteraction(_ interaction: UIInteraction, requestElementsIn rect: CGRect,
                                     completion: @escaping ([UUID]) -> Void) {
        let found: [UUID] = MainActor.assumeIsolated {
            guard let session else { return [] }
            let corner = session.toBoard(rect.origin)
            let part = CGRect(x: corner.x, y: corner.y, width: rect.width / session.scale, height: rect.height / session.scale)
            return session.board.writable(in: part)
        }
        completion(found)
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, frameForElement elementIdentifier: UUID) -> CGRect {
        MainActor.assumeIsolated {
            guard let session, let item = session.board.item(elementIdentifier) else { return .null }
            return session.toScreen(item.frame)
        }
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, isElementFocused elementIdentifier: UUID) -> Bool {
        MainActor.assumeIsolated { surface?.session?.editing == elementIdentifier }
    }

    // MARK: Writing or dragging

    /// The thing is not opened for typing the moment the tip lands: a drag must be able to win first.
    func indirectScribbleInteraction(_ interaction: UIInteraction, shouldDelayFocusForElement elementIdentifier: UUID) -> Bool {
        true
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, willBeginWritingInElement elementIdentifier: UUID) {
        dropped = nil
        MainActor.assumeIsolated {
            guard let surface, let strayed = surface.pencilStrayed else { return }
            if InkShape.writingWins(strayed: Double(strayed)) {
                surface.giveUpPencil()
            } else {
                dropped = elementIdentifier
            }
        }
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, didFinishWritingInElement elementIdentifier: UUID) {
        dropped = nil
    }

    // MARK: The field the words go into

    func indirectScribbleInteraction(_ interaction: UIInteraction, focusElementIfNeeded elementIdentifier: UUID,
                                     referencePoint focusReferencePoint: CGPoint,
                                     completion: @escaping ((any UIResponder & UITextInput)?) -> Void) {
        let opened: Bool = MainActor.assumeIsolated {
            guard let session, dropped != elementIdentifier, session.board.takesWriting(elementIdentifier) else { return false }
            if session.editing != elementIdentifier { session.beginEdit(elementIdentifier) }
            return session.editing == elementIdentifier
        }
        guard opened else { completion(nil); return }
        waitForField(tries: 12, completion)
    }

    /// The typing field takes the keys a moment after `beginEdit`: looked for every 0.05 s, for 0.6 s at most.
    private func waitForField(tries: Int, _ completion: @escaping ((any UIResponder & UITextInput)?) -> Void) {
        let field: (any UIResponder & UITextInput)? = MainActor.assumeIsolated {
            guard let window = surface?.window else { return nil }
            return Self.field(in: window)
        }
        if let field {
            completion(field)
        } else if tries <= 0 {
            completion(nil)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { completion(nil); return }
                self.waitForField(tries: tries - 1, completion)
            }
        }
    }

    /// The view that holds the keys right now, when it takes text.
    @MainActor
    private static func field(in view: UIView) -> (any UIResponder & UITextInput)? {
        if view.isFirstResponder, let input = view as? (any UIResponder & UITextInput) { return input }
        for inner in view.subviews {
            if let found = field(in: inner) { return found }
        }
        return nil
    }
}
#endif
