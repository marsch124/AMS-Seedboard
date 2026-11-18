import SwiftUI
import SeedboardCore

// What the owner does to arrows and with the keys of a flow (0.2). Each is one step for Undo.

extension BoardSession {
    // MARK: The chosen arrow

    /// One way, both ways or a plain line.
    func setLinkEnds(_ ends: LinkEnds) {
        guard let id = selectedLink else { return }
        change { board in
            if let l = board.links.firstIndex(where: { $0.id == id }) { board.links[l].ends = ends }
        }
    }

    func toggleLinkDashed() {
        guard let id = selectedLink else { return }
        change { board in
            if let l = board.links.firstIndex(where: { $0.id == id }) { board.links[l].isDashed.toggle() }
        }
    }

    /// The end dot of the chosen arrow under the point (board points): the far end first.
    func linkEnd(at p: CGPoint) -> (link: UUID, start: Bool)? {
        guard !readOnly, editing == nil, !linking, let id = selectedLink, let arrow = board.arrow(id),
              let first = arrow.points.first, let last = arrow.points.last else { return nil }
        let reach = 13 / scale
        if hypot(p.x - last.x, p.y - last.y) <= reach { return (id, false) }
        if hypot(p.x - first.x, p.y - first.y) <= reach { return (id, true) }
        return nil
    }

    /// While an end is dragged: the end that stays put (the dashed line starts there) and the
    /// item the dragged end would land on.
    func endPull(_ id: UUID, start: Bool, to p: CGPoint) -> (from: CGPoint, over: UUID?)? {
        guard let arrow = board.arrow(id), let first = arrow.points.first, let last = arrow.points.last else { return nil }
        return (start ? last : first, board.endTarget(of: id, start: start, at: p))
    }

    /// An end was let go: it moves to that side of its shape, or onto the shape under it.
    func moveLinkEnd(_ id: UUID, start: Bool, to p: CGPoint) {
        change { $0.moveEnd(of: id, start: start, to: p) }
    }

    /// Where the field for an arrow's words sits on screen: beside the line, where the words are drawn.
    func wordsField(for id: UUID) -> (centre: CGPoint, leading: Bool)? {
        guard let arrow = board.arrow(id) else { return nil }
        let at = toScreen(arrow.words.at)
        let half: CGFloat = 85 - 6
        let tall = 13 * scale * 1.25 + 6
        return (CGPoint(x: at.x + (arrow.words.leading ? half : -half),
                        y: at.y + (arrow.words.above ? 3 - tall / 2 : tall / 2 - 3)), arrow.words.leading)
    }

    // MARK: Keys of a flow

    /// Tab on a flow shape (chosen, or while its words are typed): the next shape with its arrow,
    /// in the direction the flow is running. ⌘ with an arrow key: the same, in that direction.
    /// False when the key is not meant for this.
    func flowKey(_ press: KeyPress) -> Bool {
        guard !readOnly else { return false }
        guard let id = editing ?? (selection.count == 1 ? selection.first : nil),
              let item = board.item(id), item.kind.isShape else { return false }
        let mods = press.modifiers
        guard !mods.contains(.shift), !mods.contains(.option), !mods.contains(.control) else { return false }
        let direction: Direction
        if mods.contains(.command) {
            switch press.key {
            case .rightArrow: direction = .right
            case .leftArrow: direction = .left
            case .downArrow: direction = .down
            case .upArrow: direction = .up
            default: return false
            }
        } else if press.key == .tab {
            direction = board.flowDirection(at: id)
        } else {
            return false
        }
        addNext(from: id, direction: direction)
        return true
    }
}
