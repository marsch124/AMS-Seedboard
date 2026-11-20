import SwiftUI
import SeedboardCore
import AMSIcons

// Seedboard 0.19, lane "list": swipe a row, the line where a search found its words, Sort on the Recent card,
// the Due soon card, "2 late" in red, Colour… and Send to PARAGON… on a row's menu, pull down to make a board
// from the clipboard, and the thin done bar. The rules are in Core (List19.swift); no stored field is new.

/// Every SF Symbol this lane added, in one place (so a name can be swapped after a look).
enum Marks19List {
    static let sort = "arrow.up.arrow.down"
    static let pin = "pin"
    static let unpin = "pin.slash"
    static let putAway = "archivebox"
    static let colour = "paintpalette"
    static let sendToParagon = "paperplane"
    static let picked = "checkmark"
}

// MARK: Sort (pick 3)

/// The Recent card's order, kept on this device only.
enum ListSort19 {
    static let key = "list.sort"
    static func current(_ raw: String) -> BoardSort { BoardSort(rawValue: raw) ?? .changed }
}

/// The one small "Sort" menu on the Recent card: Last changed, Date made, Name.
struct SortMenu19: View {
    @AppStorage(ListSort19.key) private var raw = BoardSort.changed.rawValue

    var body: some View {
        let now = ListSort19.current(raw)
        Menu {
            ForEach(BoardSort.allCases, id: \.self) { sort in
                Button { raw = sort.rawValue } label: {
                    if sort == now { Label(sort.word, systemImage: Marks19List.picked) } else { Text(sort.word) }
                }
                .accessibilityIdentifier("boards.sort.\(sort.rawValue)")
            }
        } label: {
            Label("Sort", systemImage: Marks19List.sort)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Part.boards.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Sort, \(now.word)")
        .accessibilityIdentifier("boards.sort")
    }
}

// MARK: Colours for the board's dot (pick 6)

enum ListColours19 {
    /// The board colours except purple (purple means PARAGON); red is not among them (red means late).
    static var names: [String] { Palette.boards.filter { $0 != "purple" && $0 != "red" } }
}

// MARK: A row's or card's press-and-hold lines (picks 6 and 45)

/// "Colour…" and "Send to PARAGON…" for the press-and-hold menu of a board row (list) or card (home page).
struct BoardMenuLines19: View {
    @EnvironmentObject private var model: AppModel
    let board: Board

    var body: some View {
        if board.canBeChanged {
            Menu {
                ForEach(ListColours19.names, id: \.self) { name in
                    Button { model.setColour(board.id, name) } label: {
                        if board.colour == name { Label(name.capitalized, systemImage: Marks19List.picked) } else { Text(name.capitalized) }
                    }
                }
            } label: {
                Label("Colour…", systemImage: Marks19List.colour)
            }
            .accessibilityIdentifier("card.colour")
            if !board.isPutAway {
                Button { model.sendFromList(board) } label: {
                    Label("Send to PARAGON…", systemImage: Marks19List.sendToParagon)
                }
                .accessibilityIdentifier("card.send")
            }
        }
    }
}

extension AppModel {
    /// Opens the board and then its Send page (the same page as from inside the board). Refused for a board this
    /// version may not change (read-only).
    func sendFromList(_ board: Board) {
        guard board.canBeChanged else {
            say("This board was made by a newer Seedboard. Update the app to send it.", tone: .problem)
            return
        }
        open(board.id)
        let id = board.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.openID == id, let session = self.session else { return }
            session.commitEdit()
            self.showSend = true
        }
    }
}

// MARK: The line where the words were found (pick 2)

struct FoundLine19: View {
    let board: Board
    let search: String

    var body: some View {
        if let found = board.foundLine(search) {
            Text(Self.attributed(found))
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .accessibilityIdentifier("boards.found.\(board.title)")
        }
    }

    static func attributed(_ line: FoundLine) -> AttributedString {
        var out = AttributedString()
        for piece in line.pieces {
            var part = AttributedString(piece.text)
            if piece.bold { part.inlinePresentationIntent = .stronglyEmphasized }
            out.append(part)
        }
        return out
    }
}

// MARK: The line with "2 late" in red (pick 5)

/// The board's one small line, with its "N late" (timeline boards) in red. Red = late only.
struct LineText19: View {
    let board: Board
    let doneThings: Set<UUID>
    var prefix = ""
    var suffix = ""

    var body: some View {
        let line = board.listLine(doneThings: doneThings)
        let late = board.lateThings(doneThings: doneThings)
        var text = AttributedString(prefix)
        let parts = line.components(separatedBy: " · ")
        for (n, part) in parts.enumerated() {
            if n > 0 { text.append(AttributedString(" · ")) }
            var piece = AttributedString(part)
            if late > 0, part == "\(late) late" { piece.foregroundColor = .red }
            text.append(piece)
        }
        text.append(AttributedString(suffix))
        return Text(text)
    }
}

// MARK: The thin done bar (pick 8)

/// A thin green bar on a faint track: the share of done things (to-dos done + timeline bars and milestones done).
/// Hidden when the board has no such thing. Green = done.
struct DoneBar19: View {
    let board: Board
    let doneThings: Set<UUID>
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let share = board.doneShare(doneThings: doneThings) {
            let fraction = Double(share.done) / Double(share.total)
            GeometryReader { box in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.10))
                    Capsule().fill(Paint(scheme).line("green")).frame(width: box.size.width * fraction)
                }
            }
            .frame(height: 3)
            .padding(.vertical, 2)
            .accessibilityElement()
            .accessibilityLabel("\(share.done) of \(share.total) done")
            .accessibilityIdentifier("boards.doneBar.\(board.title)")
        }
    }
}

// MARK: Due soon (pick 4)

/// The rows of the Due soon card: a board whose due day is within 7 days (today included), or already past it
/// ("3 days late" in red).
struct DueSoonRows19: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let entries: [DueSoonEntry]
    let open: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entries, id: \.boardID) { entry in
                if let board = model.boards.first(where: { $0.id == entry.boardID }) {
                    Button { open(board.id) } label: {
                        HStack(spacing: 8) {
                            Circle().fill(Paint(scheme).line(board.colour)).frame(width: 9, height: 9)
                            Text(board.title).font(.body).foregroundStyle(Color.primary).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(entry.words)
                                .font(.caption)
                                .foregroundStyle(entry.late ? Color.red : Color.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("boards.due.\(board.title)")
                }
            }
        }
    }
}

// MARK: Swipe a row (pick 1) — iPhone and iPad

#if os(iOS)
/// Swipe right = Pin / Unpin, swipe left = Put away. The row is not in a `List`, so this is an Apple-like swipe of
/// its own: a coloured button with symbol and word shows under the row; a short swipe leaves it there to press,
/// a long swipe does it at once.
struct RowSwipe19: ViewModifier {
    let board: Board
    let pin: () -> Void
    let putAway: () -> Void

    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    @State private var horizontal: Bool?

    private let reveal: CGFloat = 88
    private let commit: CGFloat = 150
    private var allowed: Bool { board.canBeChanged && !board.isPutAway }

    func body(content: Content) -> some View {
        if !allowed {
            content
        } else {
            ZStack {
                actions
                content
                    .offset(x: offset)
                    .allowsHitTesting(settled == 0)
                    .overlay {
                        if settled != 0 { Color.clear.contentShape(Rectangle()).offset(x: offset).onTapGesture { close() } }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .simultaneousGesture(drag)
            .accessibilityAction(named: board.pinned ? "Unpin" : "Pin") { pin() }
            .accessibilityAction(named: "Put away") { putAway() }
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            if offset > 0 {
                button(board.pinned ? "Unpin" : "Pin", board.pinned ? Marks19List.unpin : Marks19List.pin, Part.shapes.fill,
                       id: "boards.swipePin.\(board.title)") { close(); pin() }
                    .frame(width: offset)
                Spacer(minLength: 0)
            } else if offset < 0 {
                Spacer(minLength: 0)
                button("Put away", Marks19List.putAway, Part.arrows.fill,
                       id: "boards.swipeAway.\(board.title)") { close(); putAway() }
                    .frame(width: -offset)
            }
        }
    }

    private func button(_ word: String, _ symbol: String, _ colour: Color, id: String, press: @escaping () -> Void) -> some View {
        Button(action: press) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text(word).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colour)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func close() { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0; settled = 0 } }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { v in
                if horizontal == nil { horizontal = abs(v.translation.width) > abs(v.translation.height) * 1.5 }
                guard horizontal == true else { return }
                offset = max(-260, min(260, settled + v.translation.width))
            }
            .onEnded { v in
                defer { horizontal = nil }
                guard horizontal == true else { return }
                let end = settled + v.translation.width
                if end > commit { close(); pin() }
                else if end < -commit { close(); putAway() }
                else if end > 44 { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = reveal; settled = reveal } }
                else if end < -44 { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = -reveal; settled = -reveal } }
                else { close() }
            }
    }
}

// MARK: Pull down to make a board from the clipboard (pick 7) — iPhone and iPad

private struct PullKey19: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// A zero-height marker at the top of the list's content; its place says how far the list is pulled down.
struct PullMarker19: View {
    var body: some View {
        GeometryReader { box in
            Color.clear.preference(key: PullKey19.self, value: box.frame(in: .named("list19Scroll")).minY)
        }
        .frame(height: 0)
        .accessibilityHidden(true)
    }
}

struct PullToMake19: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @State private var rest: CGFloat?
    @State private var pull: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: "list19Scroll")
            .scrollBounceBehavior(.always)
            .onPreferenceChange(PullKey19.self) { y in
                if rest == nil { rest = y }
                pull = max(0, y - (rest ?? y))
            }
            .simultaneousGesture(DragGesture(minimumDistance: 10).onEnded { _ in
                guard pull >= ClipboardBoard.pullDistance * 0.85 else { return }
                make()
            })
            .overlay(alignment: .top) {
                if pull > 24 {
                    Text(ClipboardBoard.release)
                        .font(.caption)
                        .foregroundStyle(Part.boards.text)
                        .opacity(min(1, Double(pull - 24) / Double(ClipboardBoard.pullDistance - 24)))
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("boards.pullLine")
                }
            }
    }

    private func make() {
        if let board = ClipboardBoard.board(from: UIPasteboard.general.string) {
            model.add(board)
        } else {
            model.say(ClipboardBoard.nothing, tone: .problem)
        }
    }
}
#endif

extension View {
    /// Swipe right = Pin / Unpin, swipe left = Put away (iPhone and iPad; the Mac does not swipe).
    @ViewBuilder
    func rowSwipe19(_ board: Board, pin: @escaping () -> Void, putAway: @escaping () -> Void) -> some View {
        #if os(iOS)
        modifier(RowSwipe19(board: board, pin: pin, putAway: putAway))
        #else
        self
        #endif
    }

    @ViewBuilder
    func pullToMake19() -> some View {
        #if os(iOS)
        modifier(PullToMake19())
        #else
        self
        #endif
    }
}
