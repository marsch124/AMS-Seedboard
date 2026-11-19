import SwiftUI
import SeedboardCore
import AMSIcons

// 0.14, lane "look": Copy look / Paste look (15), the size of a free text (17), Zoom to these (19).
// (Today's date while typing, 26, is `BoardSession.insertToday` and the lines in Menus.swift and MapOrder.swift.)

/// 15: the look that "Copy look" kept. It stays on this device (not on the board, not in iCloud) until another is copied.
@MainActor
final class LookDesk: ObservableObject {
    static let shared = LookDesk()
    @Published var copied: CopiedLook?
}

extension BoardSession {
    /// "Copy look" is offered when one thing is chosen that has a look to copy.
    var canCopyLook: Bool {
        guard !board.placesItself, selection.count == 1, let id = selection.first else { return false }
        return board.lookToCopy(id) != nil
    }

    /// "Paste look" is offered when a look is kept and at least one chosen thing can take part of it
    /// (a thing is never offered its own look back when it is the only one chosen and has just been copied from).
    var canPasteLook: Bool {
        guard !readOnly, !board.placesItself, let look = LookDesk.shared.copied else { return false }
        return selection.contains { board.canTakeLook(look, $0) }
    }

    func copyLook() {
        guard canCopyLook, let id = selection.first, let look = board.lookToCopy(id) else { return }
        LookDesk.shared.copied = look
        AppModel.shared.say("Look copied", seconds: 2)
    }

    /// One undo step for all chosen things.
    func pasteLook() {
        guard canPasteLook, let look = LookDesk.shared.copied else { return }
        let ids = Array(selection)
        change(widen: Set(ids)) { board in board.pasteLook(look, on: ids) }
    }

    /// 17: the size of the chosen free texts.
    func setTextSize(_ size: String?) {
        let ids = selection
        change { board in
            for id in ids {
                guard let i = board.index(of: id), board.items[i].kind == .text else { continue }
                board.items[i].textSize = size
            }
        }
    }
}

extension BarActions {
    /// 15 and 19: "Copy look", "Paste look" and "Zoom to these" go in just before "Remove" (behind the "…" when narrow).
    func withLook(_ list: [BarAction]) -> [BarAction] {
        let session = session
        var extra: [BarAction] = []
        if session.canCopyLook {
            extra.append(act("copylook", "Copy look", .app(.seedCopy), show: .wideWord, drop: 7) { session.copyLook() })
        }
        if session.canPasteLook {
            extra.append(act("pastelook", "Paste look", .new(.paste), show: .wideWord, drop: 7) { session.pasteLook() })
        }
        if session.canZoomToChosen {
            extra.append(act("zoomchosen", "Zoom to these", .app(.seedFit), show: .wideWord, drop: 8) { session.zoomToChosen() })
        }
        guard !extra.isEmpty, !list.isEmpty else { return list }
        extra[0].gap = true
        var all = list
        let at = all.lastIndex { $0.id == prefix + "remove" } ?? all.count
        all.insert(contentsOf: extra, at: at)
        return all
    }

    /// 17: "Size" for a chosen free text: Title, Normal, Small.
    func textSizeChoice(_ item: Item, show: BarAction.Show = .word, drop: Int = 0) -> BarAction {
        let session = session
        let choices = [(TextSize.title, "title"), (nil, "normal"), (TextSize.small, "small")].map { stored, key in
            act("size.\(key)", TextSize.word(stored), .app(.seedText), on: item.textSize == stored) { session.setTextSize(stored) }
        }
        return BarAction(id: prefix + "size", word: "Size", glyph: .app(.seedText), kind: .choices(choices), show: show, drop: drop)
    }
}
