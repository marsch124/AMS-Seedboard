import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#endif

// 0.5, the `looks` lane: launch words for pictures of the mind-map branches and the four to-do marks.
//
//   -garden               with `-sampleData`: adds the sample mind map "Garden year" (three levels deep, both sides,
//                         one to-do, one folded idea): `-board Garden`
//   -marks                with `-sampleData`: adds the sample board "To-do marks" (`-board marks`) and fills
//                         `ParagonEcho` with made-up states, so all four marks show; the sample timeline
//                         (`-board timeline`) and "Loan steps" (`-board Loan`) show the four as well
//   -dueDays              with `-marks`: the tasks in PARAGON also have a due day (in 3 days, today, yesterday)
//   -zoom 1.5 | most      the opened board at this zoom, round its middle; `most` = as big as the whole board
//                         still fits (for pictures)
//   -window 1280x800      the Mac window at this size (for pictures)
//
// Trap: the Mac reads launch words in pairs, so a word WITHOUT a value (`-marks`, `-garden`, `-night`) must
// stand after the pairs (`-board marks -marks -sampleData`), or the window does not come up.

enum LooksLaunch {
    static let marks = LaunchOptions.arguments.contains("-marks")

    /// The sample boards these launch words add, and the made-up states of `-marks`. Sample data only.
    static func addBoards(to boards: inout [Board], now: Date = Date()) {
        guard LaunchOptions.sampleData else { return }
        if LaunchOptions.arguments.contains("-garden") { boards.append(garden(now: now)) }
        guard marks else { return }
        let made = marksBoard(now: now)
        boards.append(made.board)
        // 0.9: `-dueDays` also gives the tasks that are in PARAGON their due days: in 3 days, today, yesterday (past due).
        var days: [UUID: String] = [:]
        if LaunchOptions.arguments.contains("-dueDays") {
            let today = Day.today(now)
            var nth = 0
            for item in made.board.items where made.read[item.id] == .inParagon {
                days[item.id] = [today + 3, today, today - 1][nth % 3].iso
                nth += 1
            }
            for item in made.board.items where made.read[item.id] == .done { days[item.id] = (today - 2).iso }
        }
        ParagonEcho.shared.keep(made.read, due: days, for: made.board.id)
        for i in boards.indices where boards[i].isTimeline || boards[i].isSequence {
            let words = boards[i].isTimeline ? ["Foundation", "Find builder", "Permit", "Windows"]
                                             : ["Order the build", "Ask for loan", "Ask for permit", "Ask again"]
            var read: [UUID: TodoState] = [:]
            for (word, state) in zip(words, TodoState.allCases) {
                guard let n = boards[i].items.firstIndex(where: { $0.text.hasPrefix(word) }) else { continue }
                stand(&boards[i], n, state, &read)
            }
            ParagonEcho.shared.keep(read, for: boards[i].id)
        }
    }

    /// After the boards are loaded and the launch board is open: the zoom and the window's size.
    @MainActor
    static func afterLoad(_ session: BoardSession?) {
        #if os(macOS)
        if let words = LaunchOptions.value(for: "-window")?.split(separator: "x"), words.count == 2,
           let w = Double(words[0]), let h = Double(words[1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else { return }
                let top = (window.screen ?? NSScreen.main)?.visibleFrame.maxY ?? 900
                window.setFrame(CGRect(x: 60, y: top - h - 20, width: w, height: h), display: true)
            }
        }
        #endif
        if let word = LaunchOptions.value(for: "-zoom"), let session {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                session.fit()
                if let zoom = Double(word) {
                    session.zoom(to: CGFloat(zoom))
                } else if word == "most", let all = session.board.bounds, all.width > 0, all.height > 0 {
                    // As big as the whole board still fits, clear of the top bar and the tools.
                    let room = CGSize(width: session.viewSize.width - 70, height: session.viewSize.height - 190)
                    session.zoom(to: min(room.width / all.width, room.height / all.height, 2.4))
                }
            }
        }
    }

    /// Puts the thing at `n` into `state`: ticked "to do"; sent, when PARAGON has it; and what was read back.
    private static func stand(_ board: inout Board, _ n: Int, _ state: TodoState, _ read: inout [UUID: TodoState]) {
        board.items[n].todo = true
        let id = board.items[n].id
        if state != .waiting { board.noteSent(id, words: board.items[n].text, place: SentTask.note) }
        if state == .done || state == .cancelled { read[id] = state }
    }

    /// "To-do marks": the four ways a to-do can stand, each on a shape, a sticky note and an idea of a mind map.
    static func marksBoard(now: Date = Date()) -> (board: Board, read: [UUID: TodoState]) {
        var board = Board(title: "To-do marks", created: now.addingTimeInterval(-86_400 * 6),
                          changed: now.addingTimeInterval(-86_400 * 6), colour: "purple")
        var read: [UUID: TodoState] = [:]
        let heads = ["To do", "In PARAGON", "Done in PARAGON", "Cancelled in PARAGON"]
        let boxes = ["Ask for the permit", "Find a builder", "Get the loan", "Sell the boat"]
        let notes = ["Call the council\non Monday", "Three offers\nby Friday", "Papers to\nthe bank", "Advert in\nthe paper"]
        let ideas = ["Measure the plot", "Order the timber", "Clear the path", "Rent a digger"]
        for (n, state) in TodoState.allCases.enumerated() {
            let x = CGFloat(n) * 200
            board.add(.text, centre: CGPoint(x: x, y: 0), text: heads[n])
            let box = board.add(.box, centre: CGPoint(x: x, y: 62), text: boxes[n], colour: n == 0 ? "" : ["blue", "teal", "orange"][n - 1])
            let note = board.add(.note, centre: CGPoint(x: x, y: 178), text: notes[n], colour: ["yellow", "pink", "green", "blue"][n])
            for id in [box, note] {
                if let i = board.index(of: id) { stand(&board, i, state, &read) }
            }
        }
        // A small mind map under them: one idea in each state.
        let centre = board.addCentre(at: CGPoint(x: 150, y: 345), text: "Summer cabin", bothSides: false)
        if let branch = board.addChild(of: centre, text: "Before the build") {
            for (n, state) in TodoState.allCases.enumerated() {
                guard let idea = board.addChild(of: branch, text: ideas[n]), let i = board.index(of: idea) else { continue }
                stand(&board, i, state, &read)
            }
        }
        board.layoutMaps()
        return (board, read)
    }

    /// "Garden year": a mind map three levels deep on both sides, with one to-do and one folded idea, so the
    /// branches' weights, the words on the line, the to-do mark and the folded dot can be looked at.
    static func garden(now: Date = Date()) -> Board {
        var board = Board(title: "Garden year", created: now.addingTimeInterval(-86_400 * 7),
                          changed: now.addingTimeInterval(-86_400 * 7), colour: "green")
        let centre = board.addCentre(at: .zero, text: "Garden year", bothSides: false)
        let plan: [(String, [(String, [String])])] = [
            ("Spring", [("Sow tomatoes", ["Indoors in March", "Plant out in May"]), ("Prune the apple tree", [])]),
            ("Summer", [("Water every evening", []), ("Build a raised bed", ["Buy timber", "Ask Alex for the saw"])]),
            ("Autumn", [("Harvest", ["Apples", "Potatoes"]), ("Plant bulbs", [])]),
            ("Winter", [("Plan next year", []), ("Order seeds", ["Tomatoes", "Beans"])]),
        ]
        for (season, jobs) in plan {
            guard let branch = board.addChild(of: centre, text: season) else { continue }
            for (job, steps) in jobs {
                guard let idea = board.addChild(of: branch, text: job) else { continue }
                for step in steps { board.addChild(of: idea, text: step) }
            }
        }
        // Both sides is switched on after the branches are there: the first two go right, the last two left.
        if let i = board.index(of: centre) { board.items[i].bothSides = true }
        if let i = board.items.firstIndex(where: { $0.text == "Buy timber" }) { board.items[i].todo = true }
        if let i = board.items.firstIndex(where: { $0.text == "Order seeds" }) { board.items[i].folded = true }
        board.layoutMaps()
        return board
    }
}
