import Foundation

/// The words of "How it works" and "What's new". Every release adds its entry at the top of `news`
/// and changes the parts of `guide` that it touched.
enum Guide {
    struct Part: Identifiable {
        let title: String
        let text: [String]
        var id: String { title }
    }

    struct Release: Identifiable {
        let version: String
        let date: String
        let items: [String]
        var id: String { version }
    }

    static let guide: [Part] = [
        Part(title: "What this app is", text: [
            "Seedboard is a place to think. Each board is an endless canvas where you can draw a mind map, lay out a flow with shapes and arrows, and stick notes anywhere.",
            "When an idea is ready, one green button, Send to PARAGON, hands the board to your notes app.",
        ]),
        Part(title: "Your boards", text: [
            "The list at the side shows your boards in three groups: Pinned, Recent, and Sent to PARAGON.",
            "Choose New board to start. You can begin with a blank board or with a starter: Mind map, Flow, Pros and cons, or Plan in steps.",
        ]),
        Part(title: "Mind maps", text: [
            "Pick a board, choose a first idea and just type. Press Tab to make a child idea. Press Return for the next idea beside it.",
            "The branches lay themselves out and each branch takes its own colour.",
            "Paste a list of lines, and it becomes a mind map. A line that is pushed in under another becomes its child.",
        ]),
        Part(title: "Shapes and arrows", text: [
            "Shapes: a box, a rounded box, a diamond and a round one. Put words inside any of them.",
            "An arrow joins two shapes. When you move a shape, its arrows follow. Tap an arrow to write words on it.",
            "A small plus appears beside the shape you chose. Tap it and the next shape appears already joined with an arrow.",
        ]),
        Part(title: "Sticky notes, text and frames", text: [
            "Sticky notes come in six colours. Free text sits on the canvas without a box.",
            "A frame groups things that belong together. Move the frame and everything inside it moves with it.",
        ]),
        Part(title: "Moving things around", text: [
            "Choose a thing to move it, pull a corner to resize it, copy it, or delete it. Undo takes back your last step.",
            "Zoom with a pinch. Move around with a two-finger scroll. On the Mac you can also hold the Space bar and drag.",
        ]),
        Part(title: "To do boxes", text: [
            "Mark any box as To do. When you send the board to PARAGON, these boxes can go to your Inbox as tasks.",
        ]),
        Part(title: "Send to PARAGON", text: [
            "As a note: the board goes as a picture with its outline written underneath.",
            "As a project: the branches of a mind map become headings and the ideas become tasks.",
            "To do boxes: they go to your PARAGON Inbox on their own.",
            "Each sent note carries a link back to the board, so one tap brings you home.",
            "In Settings, PARAGON tells you whether your notes app can be found. Press Check again to look once more.",
        ]),
        Part(title: "Where your boards are kept", text: [
            "Every board is its own file. It is kept on the device and in iCloud, so your Mac, iPad and iPhone show the same boards.",
            "If two devices change the same board at once, the newer one is kept and the other is saved as a safety copy. A safety copy of all boards is also made once a day.",
            "A board you remove is not thrown away. It waits in a Removed folder for 30 days.",
            "Settings, under Your boards, says how many boards there are and when the last safety copy was made.",
        ]),
        Part(title: "On the iPhone", text: [
            "The iPhone is for looking at your boards and jotting down an idea. The big canvas work is best on the iPad and the Mac.",
        ]),
        Part(title: "Version", text: [
            "The version is shown in Settings, under About.",
        ]),
    ]

    static let news: [Release] = [
        Release(version: "0.1", date: "18 November 2026", items: [
            "New: the boards list, with Pinned, Recent and Sent to PARAGON.",
            "New: a new board, blank or from a starter: Mind map, Flow, Pros and cons, Plan in steps.",
            "New: mind maps. Type an idea, Tab makes a child idea, Return makes the next idea. Branches lay themselves out and take a colour.",
            "New: shapes (box, rounded box, diamond, round) and arrows that follow when you move a shape. You can write words on an arrow.",
            "New: a small plus beside a chosen shape makes the next shape already joined.",
            "New: sticky notes in six colours, free text, and frames to group things.",
            "New: move, resize, copy, delete and undo.",
            "New: zoom and move around: pinch, two-finger scroll, or hold Space and drag.",
            "New: paste a list and it becomes a mind map.",
            "New: mark a box as To do.",
            "New: Send to PARAGON. As a note (picture plus outline), as a project (branches become headings, ideas become tasks), to do boxes to the Inbox, and a link back to the board.",
            "New: boards are kept in iCloud on all your devices, with safety copies and a Removed folder that keeps boards for 30 days.",
            "New: on the iPhone you can look at boards and jot an idea.",
            "New: Settings with How it works, What's new, PARAGON, Your boards and the version.",
        ]),
    ]
}
