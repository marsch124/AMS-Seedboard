import SwiftUI
import SeedboardCore

// 0.14, pick 13: a link to one single thing. "Copy link to this" (bar and right-click menu of a thing) copies
// `seedboard://board/<board>/item/<thing>`; opening such a link opens the board, chooses the thing and brings it
// into the middle. The calendar's days carry the same kind of link. A thing that is gone: a short line.

extension BoardSession {
    /// The link to the chosen thing, when exactly one is chosen.
    var linkToChosen: String? {
        guard let item = single else { return nil }
        return BoardLink.link(board: board.id, item: item.id)
    }

    /// Chooses the thing and brings it to the middle of the view (gliding, zooming to a readable size).
    /// When the view has no size yet (the board is still opening) it happens as soon as it has.
    func showThing(_ id: UUID) {
        guard let item = board.item(id) else {
            thingToShow = nil
            AppModel.shared.say(BoardLink.thingGone + ".", tone: .problem, seconds: 5)
            return
        }
        guard viewSize.width > 10, viewSize.height > 10 else {
            thingToShow = id
            return
        }
        thingToShow = nil
        clearSelection()
        select(id)
        if board.isTimeline || board.isSequence {
            // These place themselves: the row is brought into sight.
            reveal(id)
            return
        }
        let frame = item.frame
        let fit = min(Double(viewSize.width) * 0.6 / max(frame.width, 1), Double(viewSize.height) * 0.45 / max(frame.height, 1))
        let target = CGFloat(min(1.2, max(0.6, fit)))
        glide(Glide.wholeBoard) {
            zoom(to: target)
            centreView(on: CGPoint(x: frame.midX, y: frame.midY))
        }
    }

    /// Called when the view's room is known: a thing waiting to be shown is shown now.
    func landWaitingThing() {
        guard let id = thingToShow, viewSize.width > 10 else { return }
        DispatchQueue.main.async { [weak self] in self?.showThing(id) }
    }
}

extension BarActions {
    /// "Copy link to this" for one chosen thing. In the bar it stands behind the "…" when the bar is narrow.
    func copyLink(drop: Int = 7) -> [BarAction] {
        let session = session
        guard !session.board.placesItself, let link = session.linkToChosen else { return [] }
        return [act("copyLink", "Copy link to this", .app(.seedCopy), show: .wideWord, drop: drop) {
            AppModel.shared.copyText(link)
            AppModel.shared.say("Link copied. It opens this board at this thing.")
        }]
    }
}
