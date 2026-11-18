import SwiftUI
import SeedboardCore

// 0.9, lane "maps": a launch word for pictures.
//
//   -maps09     with `-sampleData`: adds two made-up boards, "Balanced map" (`-board Balanced`: a mind map spread
//               evenly left and right, one branch folded so its "+N" badge shows) and "Order flow"
//               (`-board Order`: a flowchart with Yes and No out of a diamond, an arrow that goes round a box,
//               words on an arrow, and numbered steps). The sample "Who does what" board (`-board Loan`) shows the
//               name colours and "sends N". The word has no value, so it stands after the pairs.

enum MapsLaunch {
    static func addBoards(to boards: inout [Board], now: Date = Date()) {
        guard LaunchOptions.sampleData, LaunchOptions.arguments.contains("-maps09") else { return }
        boards.append(balanced(now: now))
        boards.append(flow(now: now))
    }

    static func balanced(now: Date) -> Board {
        var board = Board(title: "Balanced map", created: now.addingTimeInterval(-3600), changed: now.addingTimeInterval(-3600), colour: "blue")
        let centre = board.addCentre(at: .zero, text: "Alex's trip", bothSides: false)
        let plan: [(String, [String])] = [
            ("Travel", ["Book the train", "Pack light", "Check the passport", "Buy tickets"]),
            ("Food", ["Find a bakery"]),
            ("Places", ["Old town", "The lake", "Museum"]),
            ("Money", []),
            ("People", ["Call Sam", "Send a card"]),
        ]
        for (name, steps) in plan {
            guard let branch = board.addChild(of: centre, text: name) else { continue }
            for step in steps { board.addChild(of: branch, text: step) }
        }
        board.balanceMap(centre)
        if let i = board.items.firstIndex(where: { $0.text == "Travel" }) { board.items[i].folded = true }
        board.layoutMaps()
        return board
    }

    static func flow(now: Date) -> Board {
        var board = Board(title: "Order flow", created: now.addingTimeInterval(-7200), changed: now.addingTimeInterval(-7200), colour: "orange")
        board.numberSteps = true
        let start = board.add(.round, centre: CGPoint(x: 0, y: 0), text: "Order arrives")
        let check = board.add(.diamond, centre: CGPoint(x: 0, y: 150), text: "In stock?")
        let pack = board.add(.box, centre: CGPoint(x: 260, y: 150), text: "Pack it")
        let wait = board.add(.box, centre: CGPoint(x: 0, y: 320), text: "Order more")
        let send = board.add(.round, centre: CGPoint(x: 520, y: 150), text: "Send")
        // A box that stands in the way of the arrow from "Order more" to "Send".
        board.add(.note, centre: CGPoint(x: 260, y: 320), text: "Ask Alex first", colour: "yellow")
        board.link(from: start, to: check)
        board.link(from: check, to: pack)
        board.link(from: check, to: wait)
        board.link(from: pack, to: send, text: "Same day")
        board.link(from: wait, to: send)
        return board
    }
}
