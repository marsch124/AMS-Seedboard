import SwiftUI
import SeedboardCore
import UniformTypeIdentifiers
import LocalAuthentication

// 0.14, lane "boards": Join with… (idea 20), Lock with Face ID (idea 21), Open an outline file (idea 24).

/// What the menus, the cards and the window tell each other for the three ideas.
@MainActor
final class Boards14Desk: ObservableObject {
    static let shared = Boards14Desk()
    /// The board whose "Join with…" page is open.
    @Published var joining: UUID?
    /// "Open Outline…" (Mac File menu) / "Open an outline file" (iPhone, iPad): the file chooser is up.
    @Published var openingOutline = false
}

// MARK: Idea 21: the lock

enum FaceGuard {
    /// "Face ID", "Touch ID", "Optic ID", or "device code" where the device has no biometrics.
    static var word: String {
        let context = LAContext()
        var problem: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &problem)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default:
            #if compiler(>=5.9) && os(visionOS)
            return "Optic ID"
            #else
            return "device code"
            #endif
        }
    }

    /// True when the device can ask at all (it has a code or a biometric set up).
    static var canAsk: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    /// Asks the owner: Face ID, Touch ID or the device code. True when it was answered.
    static func ask(_ reason: String) async -> Bool {
        let context = LAContext()
        return await withCheckedContinuation { done in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in done.resume(returning: ok) }
        }
    }
}

extension AppModel {
    /// A locked board asks before it opens, whatever way it is reached (a card, a link, Handoff, Shortcuts, Spotlight).
    /// Returns true when the board may open now; otherwise the question is on its way and `openNow` follows.
    func openGate(_ id: UUID?) -> Bool {
        guard let id, id != openID || session == nil,
              let board = boards.first(where: { $0.id == id }), board.faceLock == true else { return true }
        Task { @MainActor in
            guard FaceGuard.canAsk else {
                say("This device has no code set up, so the board cannot be opened.", tone: .problem)
                return
            }
            if await FaceGuard.ask("Open “\(board.title)”.") {
                openNow(id)
            } else {
                say("The board stays closed.", tone: .problem)
            }
        }
        return false
    }

    /// Locks, or (after asking again) unlocks, a board.
    func setLock(_ id: UUID, on: Bool) {
        guard let board = boards.first(where: { $0.id == id }), board.canBeChanged else { return }
        Task { @MainActor in
            guard FaceGuard.canAsk else {
                say("Set up a code or \(FaceGuard.word) on this device first.", tone: .problem)
                return
            }
            if !on {
                guard await FaceGuard.ask("Unlock “\(board.title)”.") else {
                    say("The board stays locked.", tone: .problem)
                    return
                }
            }
            edit(id) { $0.faceLock = on ? true : nil }
            say(on ? "“\(board.title)” is locked. It asks for \(FaceGuard.word) to open." : "“\(board.title)” is unlocked.")
        }
    }

    // MARK: Idea 20

    /// Opens the page "Join with…" (a locked board asks first).
    func askJoin(_ id: UUID) {
        guard let board = boards.first(where: { $0.id == id }), board.canBeChanged, !board.placesItself else { return }
        guard board.faceLock == true else { Boards14Desk.shared.joining = id; return }
        Task { @MainActor in
            if await FaceGuard.ask("Join “\(board.title)” with another board.") { Boards14Desk.shared.joining = id }
        }
    }

    /// All things of `id` are laid to the right of the things on `target`; the board `id` is put away (never deleted);
    /// the joined board opens.
    func join(_ id: UUID, into target: UUID) {
        session?.commitEdit()
        let live: (UUID) -> Board? = { [self] key in
            if openID == key, let s = session { return s.board }
            return boards.first { $0.id == key }
        }
        guard let this = live(id), let base = live(target), let joined = BoardJoin.join(this, into: base) else {
            say("These boards cannot be joined.", tone: .problem)
            return
        }
        // This board goes under Put away first (it may be the open one), then the chosen board is saved and opened.
        edit(id) { PutAway.putAway(&$0) }
        if openID == target, let session {
            session.change { $0 = joined }
        } else {
            write(joined)
            open(target)
        }
        say(BoardJoin.line(joinedTitle: this.title), seconds: 6)
    }

    // MARK: Idea 24

    /// A Markdown, text or OPML file becomes a new mind map board.
    func openOutline(_ files: [URL]) async {
        guard let file = files.first else { return }
        let read = await Task.detached(priority: .userInitiated) { () -> (nodes: [OutlineNode], title: String)? in
            let allowed = file.startAccessingSecurityScopedResource()
            defer { if allowed { file.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: file), data.count < 5_000_000 else { return nil }
            return OpmlOutline.read(data, fileName: file.deletingPathExtension().lastPathComponent, ext: file.pathExtension)
        }.value
        guard let read else {
            say("No outline was found in that file.", tone: .problem)
            return
        }
        var board = Board(title: read.title)
        board.addMap(from: read.nodes, title: read.title, at: CGPoint(x: 0, y: 0))
        add(board)
    }
}

// MARK: Menu lines

/// "Join with…" and "Lock with Face ID" / "Unlock" for a board card's menu (home page and iPhone list, right-click).
struct Boards14CardLines: View {
    @EnvironmentObject private var model: AppModel
    let board: Board

    var body: some View {
        if board.canBeChanged && !board.placesItself && !board.isPutAway {
            Button("Join with…") { model.askJoin(board.id) }
                .accessibilityIdentifier("card.join")
        }
        if board.canBeChanged {
            Button(board.faceLock == true ? "Unlock" : "Lock with \(FaceGuard.word)") {
                model.setLock(board.id, on: board.faceLock != true)
            }
            .accessibilityIdentifier("card.lock")
        }
    }
}

// MARK: The windows' hosts

/// The "Join with…" page, the outline file chooser. Attached to the window (RootView).
struct Boards14Host: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var desk = Boards14Desk.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { desk.joining != nil }, set: { if !$0 { desk.joining = nil } })) {
                if let id = desk.joining { JoinPage(boardID: id).environmentObject(model) }
            }
            .fileImporter(isPresented: $desk.openingOutline,
                          allowedContentTypes: Boards14Host.outlineTypes, allowsMultipleSelection: false) { result in
                if case let .success(files) = result { Task { await model.openOutline(files) } }
            }
    }

    static var outlineTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let opml = UTType(filenameExtension: "opml") { types.append(opml) }
        types.append(.xml)
        return types
    }
}

extension View {
    func boards14Host() -> some View { modifier(Boards14Host()) }
}

/// "Join with…": the other ordinary boards; Cancel and Join (full colour).
struct JoinPage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let boardID: UUID
    @State private var chosen: UUID?

    var body: some View {
        let paint = Paint(scheme)
        let this = model.boards.first { $0.id == boardID }
        let choices = this.map { BoardJoin.choices(for: $0, in: model.boards) } ?? []
        return VStack(spacing: 0) {
            ZStack {
                Text("Join with…")
                    .font(Txt.big)
                    .foregroundStyle(Part.boards.text)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("join.cancel")
                    Spacer()
                    Button("Join") {
                        if let chosen { dismiss(); model.join(boardID, into: chosen) }
                    }
                    .buttonStyle(FilledButton(.boards))
                    .disabled(chosen == nil)
                    .accessibilityIdentifier("join.join")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Text("The things of “\(this?.title ?? "")” are laid to the right of the board you choose. “\(this?.title ?? "")” goes under Put away.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .accessibilityIdentifier("join.hint")
            if choices.isEmpty {
                Text("There is no other board to join with.")
                    .font(Txt.label)
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .accessibilityIdentifier("join.empty")
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(choices) { board in
                            Button { chosen = board.id } label: {
                                HStack(spacing: 8) {
                                    Circle().fill(paint.line(board.colour)).frame(width: 9, height: 9)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(board.title).font(.body.weight(chosen == board.id ? .bold : .regular)).lineLimit(1)
                                        Text(board.listLine(doneThings: EchoKeeper.shared.doneThings(board)))
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if chosen == board.id {
                                        Text("Chosen").font(.caption.weight(.semibold)).foregroundStyle(Part.boards.text)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(chosen == board.id ? Look.chosenRow : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("join.row.\(board.title)")
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .accessibilityIdentifier("join.list")
            }
        }
        .frame(minWidth: 320, minHeight: 360)
        .background(paint.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("join.page")
    }
}
