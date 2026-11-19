import SwiftUI
import Combine
import SeedboardCore

// 0.5, pick 13: a door from one board to another. The rules are in SeedboardCore (Door.swift).
// Here: what the painter needs to know about the boards behind the doors (`DoorLook`), going through a
// door and back (`DoorDesk`), making doors (the page is DoorPage.swift, the card is DoorDraw.swift), and
// "Move to a new board…".

/// What the board's painter asks about the boards behind the doors: is the board here, was it removed,
/// and its small picture. Plain and used on the main thread only (like `PictureStore`), because the
/// painter is plain too.
final class DoorLook: @unchecked Sendable {
    static let shared = DoorLook()

    /// Every board in the list, by its identity.
    private(set) var boards: [UUID: Board] = [:]
    /// Boards known to lie in the Removed folder.
    var removed: Set<UUID> = []
    /// Tells the board on screen to redraw: a small picture is ready, or a door's board turned out to be removed.
    let ready = PassthroughSubject<Void, Never>()

    private struct Kept {
        let stamp: Date
        let image: CGImage?
    }
    private var pictures: [String: Kept] = [:]
    private var wanted: [String: (id: UUID, night: Bool)] = [:]
    private var watch: AnyCancellable?

    private init() {
        MainActor.assumeIsolated {
            watch = AppModel.shared.$boards.sink { [weak self] all in
                self?.boards = all.reduce(into: [:]) { $0[$1.id] = $1 }
            }
        }
    }

    /// What this door shows (`Door.face`).
    func face(of door: Item) -> Door.Face {
        let target = door.door
        return Door.face(of: door, board: target.flatMap { boards[$0] }, removed: target.map { removed.contains($0) } ?? false)
    }

    private func key(_ id: UUID, _ night: Bool) -> String { id.uuidString + (night ? "|night" : "|day") }

    /// The small picture of a door's board as it is now. Not drawn here (the painter is in the middle of a
    /// drawing): a picture that is missing or older than the board is asked for and the board redraws when
    /// it is ready; until then the older one is shown.
    func picture(of board: Board, night: Bool) -> CGImage? {
        let name = key(board.id, night)
        if let have = pictures[name], have.stamp == board.changed { return have.image }
        if wanted[name] == nil {
            wanted[name] = (board.id, night)
            DispatchQueue.main.async { MainActor.assumeIsolated { self.makePictures() } }
        }
        return pictures[name]?.image
    }

    /// The door's small picture is made ready for day AND night, so the picture that goes to PARAGON (always
    /// drawn by day) has it too, whatever the screen shows.
    func warm(_ board: Board) {
        _ = picture(of: board, night: false)
        _ = picture(of: board, night: true)
    }

    /// Draws the pictures that were asked for (the same small pictures as the home page's cards, kept there).
    @MainActor
    private func makePictures() {
        let asked = wanted
        wanted = [:]
        guard !asked.isEmpty else { return }
        if pictures.count > 80 { pictures = [:] }
        for (name, want) in asked {
            guard let board = boards[want.id] else { continue }
            // A picture that could not be drawn is remembered as none, so it is not asked for again and again.
            pictures[name] = Kept(stamp: board.changed, image: Thumbs.picture(of: board, name: board.id.uuidString, night: want.night))
        }
        ready.send()
    }
}

/// The door is asked for at this spot of the board ("Door to a board…").
struct DoorPick: Identifiable, Equatable {
    let id = UUID()
    /// Board points; nil: a free place in the middle of the view.
    var spot: CGPoint?
}

/// "Move to a new board…": these things, waiting for the new board's name.
struct MoveOutAsk: Identifiable, Equatable {
    let id = UUID()
    var things: Set<UUID>
    /// How many things move, counted with what goes along.
    var count: Int
}

/// Going through doors and back, and the two questions a door asks (which board; the new board's name).
@MainActor
final class DoorDesk: ObservableObject {
    static let shared = DoorDesk()

    /// The boards he came through (`DoorTrail`).
    @Published private(set) var trail = DoorTrail()
    /// The page "Door to a board…" is asked for.
    @Published var picking: DoorPick?
    /// "Move to a new board…" asks for the name.
    @Published var movingOut: MoveOutAsk?
    @Published var moveName = ""

    private var watch: AnyCancellable?
    /// When a board that is not in the list was last looked for in the Removed folder.
    private var asked: [UUID: Date] = [:]
    private var launchDone = false

    private init() {
        // Every board that opens, however it opens: only a walk through doors has a way back.
        watch = AppModel.shared.$openID.sink { [weak self] id in self?.trail.opened(id) }
    }

    // MARK: Through a door, and back

    /// Two presses or Return on a door: its board opens. A board that was removed gets the line with
    /// Bring back; one that has not arrived opens when it does (both as for a link from PARAGON).
    func go(through door: Item, in session: BoardSession) {
        guard let target = door.door else { return }
        let model = AppModel.shared
        guard target != session.board.id else {
            model.say("This door leads to the board you are on.")
            return
        }
        session.commitEdit()
        // A starter's working copy is not a board to come back to.
        if !session.starterDraft { trail.through(from: session.board.id, to: target) }
        if model.boards.contains(where: { $0.id == target }) {
            model.open(target)
        } else if let url = URL(string: ParagonExport.boardLink(target)) {
            model.open(url: url)
        }
    }

    /// The board "‹ name" in the top bar goes back to; nil when he did not come through a door (or that board is gone).
    var backBoard: Board? {
        guard let id = trail.back else { return nil }
        return AppModel.shared.boards.first { $0.id == id }
    }

    func goBack() {
        guard let id = trail.back else { return }
        guard AppModel.shared.boards.contains(where: { $0.id == id }) else {
            trail.forget(id)
            return
        }
        _ = trail.stepBack()
        AppModel.shared.open(id)
    }

    // MARK: Keeping the doors of the open board true

    /// The doors of the open board carry the names their boards have now (no step for Undo), and a door whose
    /// board is not in the list is looked for in the Removed folder.
    func refresh(_ session: BoardSession) {
        let model = AppModel.shared
        // A starter being changed is left alone (its doors are re-pointed when a board is made of it).
        guard !session.board.doors.isEmpty, !session.starterDraft else { return }
        let names = model.boards.reduce(into: [UUID: String]()) { $0[$1.id] = $1.title }
        session.quietly { $0.nameDoors(names) }
        let look = DoorLook.shared
        let now = Date()
        for target in Set(session.board.doors.compactMap(\.door)) { if let board = look.boards[target] { look.warm(board) } }
        for target in Set(session.board.doors.compactMap(\.door)) where names[target] == nil && !look.removed.contains(target) {
            if let last = asked[target], now.timeIntervalSince(last) < 20 { continue }
            asked[target] = now
            Task {
                let gone: Bool
                if LaunchOptions.sampleData {
                    gone = SampleKept.shared.listing(boards: model.boards).removed.contains { $0.id == target }
                } else {
                    gone = await model.store.removedDate(target) != nil
                }
                guard gone else { return }
                look.removed.insert(target)
                look.ready.send()
            }
        }
    }

    /// "Bring back" on a door whose board was removed: the board joins the list again (it is not opened),
    /// and the door shows it.
    func bringBack(_ target: UUID) {
        let model = AppModel.shared
        Task {
            if let board = await model.bringBack(removed: target) {
                DoorLook.shared.removed.remove(target)
                DoorLook.shared.ready.send()
                model.say("“\(board.title)” is back.")
            } else {
                model.say("No copy of this board is left to bring back.", tone: .problem)
            }
        }
    }

    // MARK: Launch words (for pictures and the screen test)

    /// `-doorPage` opens "Door to a board…"; `-door <word>` lays a door to the board whose name holds the word
    /// (`-door removed`: to a removed example board, `-door away`: to a board that is nowhere);
    /// `-doorBack <word>`: as if he had come through a door from that board; `-moveOut` asks for the new board's
    /// name for what `-pick` / `-pickAll` chose, `-moveOutNow` moves it at once under the name that is offered.
    func launch(_ session: BoardSession) {
        guard !launchDone else { return }
        launchDone = true
        let model = AppModel.shared
        if let word = LaunchOptions.value(for: "-door") {
            if word == "removed", LaunchOptions.sampleData, let gone = SampleKept.shared.listing(boards: model.boards).removed.first {
                session.change { $0.addDoor(to: gone.id, name: gone.board.title, centre: session.freeSpot(near: session.visibleCentre, size: ItemKind.door.defaultSize)) }
            } else if word == "away" {
                session.change { $0.addDoor(to: UUID(), name: "Garden plan", centre: session.freeSpot(near: session.visibleCentre, size: ItemKind.door.defaultSize)) }
            } else if let board = model.boards.first(where: { $0.id != session.board.id && $0.title.localizedCaseInsensitiveContains(word) }) {
                session.addDoor(to: board)
            }
            refresh(session)
        }
        if let word = LaunchOptions.value(for: "-doorBack"),
           let from = model.boards.first(where: { $0.id != session.board.id && $0.title.localizedCaseInsensitiveContains(word) }) {
            trail.through(from: from.id, to: session.board.id)
            trail.opened(session.board.id)
        }
        if LaunchOptions.arguments.contains("-doorPage") { picking = DoorPick(spot: nil) }
        if LaunchOptions.arguments.contains("-moveOut") { session.askMoveOut() }
        if LaunchOptions.arguments.contains("-moveOutNow"), session.canMoveOut {
            session.moveOut(session.selection, named: session.board.nameForMovedOut(session.selection))
        }
    }
}

// MARK: - The board's side

extension BoardSession {
    /// Two presses or Return on a thing: when it is a door, its board opens. False: not a door.
    func goThroughDoor(_ id: UUID) -> Bool {
        guard let item = board.item(id), item.kind == .door else { return false }
        DoorDesk.shared.go(through: item, in: self)
        return true
    }

    /// A door to that board, its middle at the spot (board points; nil: a free place in the middle of the
    /// view). The door is chosen. False (with a line that says why) when this board takes no such door.
    @discardableResult
    func addDoor(to target: Board, at spot: CGPoint? = nil) -> Bool {
        guard !readOnly, !board.placesItself else {
            AppModel.shared.say("A door cannot be put on this board.", tone: .problem)
            return false
        }
        guard target.id != board.id else {
            AppModel.shared.say("A board cannot have a door to itself.", tone: .problem)
            return false
        }
        if editing != nil { commitEdit() }
        linking = false
        linkFrom = nil
        let place = spot ?? freeSpot(near: visibleCentre, size: ItemKind.door.defaultSize)
        var made: UUID?
        change { made = $0.addDoor(to: target.id, name: target.title, centre: place) }
        guard let made else { return false }
        selectedLink = nil
        selection = [made]
        reveal(made)
        DoorDesk.shared.refresh(self)
        return true
    }

    /// Words were dropped on the board. When they are a board's link (a board dragged from the list), a door
    /// to that board lands at the spot. False: ordinary words.
    func dropDoor(_ words: String, at spot: CGPoint) -> Bool {
        guard let target = Door.target(ofLink: words) else { return false }
        if let board = AppModel.shared.boards.first(where: { $0.id == target }) {
            addDoor(to: board, at: spot)
        } else {
            AppModel.shared.say("That board is not on this device.", tone: .problem)
        }
        return true
    }

    /// The things "Move to a new board…" would move now: what is chosen, when the board takes doors.
    var canMoveOut: Bool { !readOnly && !board.placesItself && editing == nil && !selection.isEmpty }

    /// "Move to a new board…": asks for the new board's name (DoorPage.swift shows the question).
    func askMoveOut() {
        guard canMoveOut else { return }
        let things = selection
        DoorDesk.shared.moveName = board.nameForMovedOut(things)
        DoorDesk.shared.movingOut = MoveOutAsk(things: things, count: board.movingOut(things).count)
    }

    /// The chosen things move to a new board with this name; a door is left in their place and chosen.
    /// The new board is written before the things leave this one, so they are on the device at every moment.
    /// One step for Undo on this board (the things come back, the door goes; the new board is put away, 0.14).
    func moveOut(_ things: Set<UUID>, named name: String) {
        guard !readOnly, !board.placesItself else { return }
        if editing != nil { commitEdit() }
        let model = AppModel.shared
        let title = Door.freeName(name, taken: model.boards.map(\.title))
        let colour = Palette.boards[model.boards.count % Palette.boards.count]
        var left = board
        guard let moved = left.moveToNewBoard(things, title: title, colour: colour) else { return }
        model.write(moved.board)
        guard change({ $0 = left }) else { return }
        movedOut[moved.door] = (moved.board.id, moved.board.title)
        selectedLink = nil
        selection = [moved.door]
        reveal(moved.door)
        DoorDesk.shared.refresh(self)
        tell("Moved to the new board “\(title)”")
    }
}

extension AppModel {
    /// A new, empty board that joins the list WITHOUT being opened (the board a new door leads to): its own
    /// colour, and a name no other board has.
    func plantBoard(named name: String) -> Board {
        var board = Starter.blank.board()
        board.title = Door.freeName(name, taken: boards.map(\.title))
        board.colour = Palette.boards[boards.count % Palette.boards.count]
        write(board)
        return board
    }
}

// MARK: - The bar and the menus

extension BarActions {
    private func doorLine(_ key: String, _ word: String, _ glyph: Glyph, show: BarAction.Show = .icon,
                          gap: Bool = false, _ run: @escaping () -> Void) -> BarAction {
        let session = session
        return BarAction(id: prefix + key, word: word, glyph: glyph, kind: .press { run(); session.takeKeys() }, show: show, gap: gap)
    }

    /// A chosen door, in its bar and its menu: "Open" (its board opens, as with two presses or Return), and
    /// "Bring back" when its board was removed.
    func doorLines(_ item: Item) -> [BarAction] {
        let session = session
        var all = [doorLine("open", "Open", .new(.door), show: .word) { _ = session.goThroughDoor(item.id) }]
        if case .removed = DoorLook.shared.face(of: item), let target = item.door {
            all.append(doorLine("bringBack", "Bring back", .new(.bringBack), show: .word) { DoorDesk.shared.bringBack(target) })
        }
        return all
    }

    /// The menu of a chosen door: Open, (Bring back,) the three clipboard lines it was handed, Arrow from here,
    /// Move to a new board….
    func doorMenu(_ item: Item, _ clip: [BarAction]) -> [BarAction] {
        let session = session
        var all = doorLines(item)
        var lines = clip
        if !lines.isEmpty { lines[0].gap = true }
        all += lines
        all.append(doorLine("arrow", "Arrow from here", .app(.seedArrow), gap: true) {
            session.commitEdit()
            session.linking = true
            session.linkFrom = item.id
        })
        all += moveOutLines()
        return all
    }

    /// "Move to a new board…" in the menu of what is chosen.
    func moveOutLines() -> [BarAction] {
        let session = session
        guard session.canMoveOut else { return [] }
        return [doorLine("moveOut", "Move to a new board…", .new(.door), gap: true) { session.askMoveOut() }]
    }

    /// "Door to a board…" in the menu of empty board: the door will lie at the pressed spot.
    func doorMenuLines(at spot: CGPoint) -> [BarAction] {
        let session = session
        guard !session.readOnly, !session.board.placesItself else { return [] }
        return [doorLine("door", "Door to a board…", .new(.door)) { DoorDesk.shared.picking = DoorPick(spot: spot) }]
    }
}
