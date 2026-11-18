import SwiftUI
import SeedboardCore

// 0.5, pick 15: More and File ▸ "Make a timeline of it…" on an ordinary board, and a list pasted onto a
// timeline. The rules are in SeedboardCore (TimelineMake.swift): the mirror of "As a project".

extension AppModel {
    /// Makes a NEW timeline board "<name> timeline" from the open board and opens it; the board itself stays
    /// as it is. With things chosen, only those. Says how many bars were made and what stayed behind.
    func makeTimeline(of session: BoardSession) {
        session.commitEdit()
        guard !session.board.placesItself else { return }
        guard let made = session.board.timelineOfIt(chosen: session.selection, today: .today()) else {
            say(session.board.isEmpty ? "The board is empty: there is nothing to make bars of."
                : "Nothing here can become a bar. Bars are made of ideas, shapes and things marked To do.",
                tone: .problem, seconds: 6)
            session.takeKeys()
            return
        }
        add(made.board)
        say(made.line, seconds: 6)
    }

    /// For pictures: `-makeTimeline` makes the timeline of the board opened with `-board <word>`, once.
    func makeTimelineAtLaunch() {
        guard LaunchOptions.arguments.contains("-makeTimeline"), let session, !session.board.placesItself else { return }
        makeTimeline(of: session)
    }
}

extension BoardSession {
    /// A list pasted onto a timeline: one bar per line, 7 days each, in a chain; a line with indented lines
    /// under it becomes a phase. With a row chosen they go under it. One Undo step.
    func timelinePaste(_ text: String) {
        guard !readOnly, editing == nil, board.isTimeline else { return }
        let nodes = Outline.parse(text.trimmingCharacters(in: .whitespacesAndNewlines))
        let under = single?.id
        var made: BarsPasted?
        change { made = $0.pasteBars(nodes, under: under, today: .today()) }
        guard let made, let first = made.bars.first else {
            AppModel.shared.say("Nothing to paste.")
            return
        }
        selectedLink = nil
        selection = Set(made.bars)
        timelineReveal(first)
        AppModel.shared.say(made.line)
    }

    /// ⌘V on a timeline: the words on the clipboard become bars.
    func timelinePasteClipboard() {
        guard !readOnly, editing == nil, board.isTimeline else { return }
        timelinePaste(AppModel.shared.clipboardText() ?? "")
    }
}
