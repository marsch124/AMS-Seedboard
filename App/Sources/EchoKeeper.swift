import SwiftUI
import Combine
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5, pick 16: the board shows what is sent and done. This keeps what was READ from PARAGON about each
// sent board — on THIS device only (Application Support/Echo/read.json), never in a board file, so looking
// never changes a board and makes no iCloud traffic. The reading itself is `ParagonGate.look` (ParagonLook.swift),
// what a note says is `ParagonRead` in SeedboardCore.
//
// When it looks: a sent board opens · a board has just been sent · PARAGON's notes are found (at the start)
// · Seedboard comes to the front. Always off the main thread.

@MainActor
final class EchoKeeper: ObservableObject {
    static let shared = EchoKeeper()

    /// What is known on this device about the note one board became.
    struct Kept: Codable, Equatable {
        enum Standing: String, Codable {
            /// The note was read.
            case found
            /// iCloud has not brought the note to this device yet.
            case notYet
            /// No note in PARAGON's folder holds the board's link any more.
            case gone
        }
        var standing: Standing
        /// The place Seedboard wrote the note to (`SentInfo.path`): a later Send starts afresh.
        var sentPath: String
        /// "note" or "project".
        var kind: String
        /// The note's title as it is NOW in PARAGON (after a rename there: the new one).
        var title: String
        /// Where the note was found inside PARAGON's folder.
        var path: String
        var reading: ParagonRead.Reading
        /// When the note was last read on this device; nil = never.
        var checked: Date?
    }

    /// Board → what was read. A sent board that is not in here was not checked on this device yet.
    @Published private(set) var kept: [UUID: Kept] = [:]

    private weak var model: AppModel?
    private var watches = Set<AnyCancellable>()
    private var sentWatch: AnyCancellable?
    private var front: NSObjectProtocol?
    private var busy = false
    /// Asked for while a look was running: looked at right after it.
    private var waiting: [UUID: Bool] = [:]
    private var lastPass = Date.distantPast
    private var lastWalk: [UUID: Date] = [:]

    /// Looking through all of PARAGON's notes for a note that is gone from its place: by itself at most this often.
    private static let walkEvery: TimeInterval = 600
    /// Coming to the front looks again at most this often.
    private static let passEvery: TimeInterval = 15

    /// Sample boards and the throwaway folder of debug builds keep nothing on the device.
    private static let keepsFile = !LaunchOptions.sampleData && LaunchOptions.value(for: "-paragonFolder") == nil

    private static var file: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Echo", isDirectory: true).appendingPathComponent("read.json")
    }

    private init() {
        guard Self.keepsFile, let data = try? Data(contentsOf: Self.file),
              let read = try? JSONDecoder().decode([String: Kept].self, from: data) else { return }
        kept = read.reduce(into: [:]) { out, pair in
            if let id = UUID(uuidString: pair.key) { out[id] = pair.value }
        }
        for (id, echo) in kept where echo.standing == .found { ParagonEcho.shared.keep(echo.reading.states, for: id) }
    }

    // MARK: When it looks

    /// Starts watching the app. Called once, when the app's state is made.
    func watch(_ model: AppModel) {
        guard self.model == nil else { return }
        self.model = model
        // A board opens; while it is open, a Send (a new place in `sent`) is looked at as soon as it is there.
        model.$session
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self else { return }
                self.sentWatch = session?.$board
                    .map(\.sent)
                    .removeDuplicates()
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self, weak session] _ in
                        guard let self, let session, !session.starterDraft else { return }
                        self.look(at: [session.board], byHand: true)
                    }
            }
            .store(in: &watches)
        // PARAGON's notes are found (some seconds after the start), and the boards are read.
        model.$paragonReady.removeDuplicates().filter { $0 }.map { _ in () }
            .merge(with: model.$loaded.removeDuplicates().filter { $0 }.map { _ in () })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.lookAtAll() }
            .store(in: &watches)
        // Seedboard comes to the front.
        #if os(macOS)
        let name = NSApplication.didBecomeActiveNotification
        #else
        let name = UIApplication.didBecomeActiveNotification
        #endif
        front = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Date().timeIntervalSince(self.lastPass) >= Self.passEvery else { return }
                self.lookAtAll()
            }
        }
        #if DEBUG
        // For pictures and for trying it on a throwaway folder: `-echoEvery <seconds>` looks again by itself.
        if let every = LaunchOptions.value(for: "-echoEvery").flatMap(Double.init), every > 0 {
            Timer.publish(every: every, on: .main, in: .common).autoconnect()
                .sink { [weak self] _ in self?.lookAtAll() }
                .store(in: &watches)
        }
        #endif
    }

    /// Every sent board, the open one as it stands now.
    private func lookAtAll() {
        guard let model, model.loaded, model.place != nil else { return }
        lastPass = Date()
        var boards = model.boards
        if let open = model.session, !open.starterDraft, let i = boards.firstIndex(where: { $0.id == open.board.id }) {
            boards[i] = open.board
        }
        // What is kept for boards that are no longer here is dropped.
        let here = Set(boards.map(\.id))
        if kept.keys.contains(where: { !here.contains($0) }) {
            kept = kept.filter { here.contains($0.key) }
            save()
        }
        look(at: boards, byHand: false)
    }

    /// Reads the notes of these boards (those that were sent as a note or a project), off the main thread.
    /// `byHand`: the owner opened or sent the board — a note that is gone from its place is searched for at once.
    private func look(at boards: [Board], byHand: Bool) {
        let sent = boards.filter { $0.sent != nil }
        guard !sent.isEmpty, let model, let place = model.place else { return }
        if busy {
            for board in sent { waiting[board.id] = (waiting[board.id] ?? false) || byHand }
            return
        }
        busy = true
        let now = Date()
        let jobs: [(board: Board, sent: SentInfo, last: String?, walk: Bool)] = sent.compactMap { board in
            guard let info = board.sent else { return nil }
            let old = kept[board.id].flatMap { $0.sentPath == info.path && $0.standing == .found ? $0.path : nil }
            let walk = byHand || now.timeIntervalSince(lastWalk[board.id] ?? .distantPast) >= Self.walkEvery
            return (board, info, old, walk)
        }
        Task.detached(priority: .utility) {
            let looks = jobs.map { job in
                (job.board.id, job.sent, job.walk,
                 ParagonGate.look(for: job.board, sent: job.sent, lastFound: job.last, walk: job.walk, place: place))
            }
            await MainActor.run { self.took(looks, at: Date()) }
        }
    }

    private func took(_ looks: [(UUID, SentInfo, Bool, ParagonGate.EchoLook?)], at now: Date) {
        var new = kept
        for (id, sent, walked, look) in looks {
            let old = kept[id].flatMap { $0.sentPath == sent.path ? $0 : nil }
            switch look {
            case .found(let path, let title, let reading):
                new[id] = Kept(standing: .found, sentPath: sent.path, kind: sent.kind, title: title, path: path, reading: reading, checked: now)
            case .notHereYet:
                // What was read before stays (with the time it was read); otherwise: not checked yet.
                if old?.standing != .found {
                    new[id] = Kept(standing: .notYet, sentPath: sent.path, kind: sent.kind, title: sent.title, path: sent.path, reading: .init(), checked: nil)
                }
            case .gone:
                lastWalk[id] = now
                new[id] = Kept(standing: .gone, sentPath: sent.path, kind: sent.kind, title: old?.title ?? sent.title, path: sent.path, reading: .init(), checked: now)
            case nil:
                // Not at its place, and not searched for this time: what is kept stays as it is.
                if old == nil { new[id] = nil }
            }
            if walked, case .found = look { lastWalk[id] = nil }
        }
        if new != kept {
            let open = model?.session
            for id in Set(new.keys).union(kept.keys) where new[id]?.reading.states != kept[id]?.reading.states {
                ParagonEcho.shared.keep(new[id]?.reading.states ?? [:], for: id)
                // The open board is drawn again with its new marks.
                if open?.board.id == id { open?.objectWillChange.send() }
            }
            kept = new
            save()
        }
        busy = false
        if !waiting.isEmpty, let model {
            let asked = waiting
            waiting = [:]
            var boards = model.boards.filter { asked[$0.id] != nil }
            if let open = model.session, let i = boards.firstIndex(where: { $0.id == open.board.id }) { boards[i] = open.board }
            look(at: boards.filter { asked[$0.id] == true }, byHand: true)
            look(at: boards.filter { asked[$0.id] == false }, byHand: false)
        }
    }

    private func save() {
        guard Self.keepsFile else { return }
        let plain = kept.reduce(into: [String: Kept]()) { $0[$1.key.uuidString] = $1.value }
        guard let data = try? JSONEncoder().encode(plain) else { return }
        try? FileManager.default.createDirectory(at: Self.file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.file, options: .atomic)
    }

    // MARK: What the screens ask

    /// What is kept about the note this board became; nil when it was sent anew since, or never checked.
    func echo(of board: Board) -> Kept? {
        guard let sent = board.sent, let echo = kept[board.id], echo.sentPath == sent.path else { return nil }
        return echo
    }

    /// The small line under the board's top bar; nil for a board that is no note or project in PARAGON.
    /// `short`: without "checked 14:02", for a narrow screen.
    func line(for board: Board, now: Date = Date(), short: Bool = false) -> String? {
        guard let sent = board.sent else { return nil }
        guard let echo = echo(of: board) else {
            return ParagonRead.line(kind: sent.kind, title: sent.title, found: 0, done: 0, checked: nil)
        }
        if short, echo.standing == .found {
            let name = "\(echo.kind == "project" ? "Project" : "Note") “\(echo.title)”"
            return [name, ParagonRead.doneWords(found: echo.reading.found, done: echo.reading.done)].compactMap { $0 }.joined(separator: " · ")
        }
        return ParagonRead.line(kind: echo.kind, title: echo.title, found: echo.reading.found, done: echo.reading.done,
                                checked: echo.standing == .notYet ? nil : echo.checked.map { ParagonRead.checkedWords($0, now: now) },
                                gone: echo.standing == .gone)
    }

    /// " · 5 of 13 done" for the board's card and row, after "Changed …"; empty when there is nothing to say.
    func doneTail(_ board: Board) -> String {
        guard let echo = echo(of: board), echo.standing == .found,
              let words = ParagonRead.doneWords(found: echo.reading.found, done: echo.reading.done) else { return "" }
        return " · " + words
    }

    /// True when the note can be opened in PARAGON (it is not known to be gone).
    func canOpen(_ board: Board) -> Bool {
        board.sent != nil && echo(of: board)?.standing != .gone
    }

    /// The title to open in PARAGON for what was sent as `info`: the title of the note that was FOUND (also after a
    /// rename in PARAGON), else the title it was sent under.
    func titleToOpen(_ info: SentInfo) -> String {
        guard let board = model?.boards.first(where: { $0.sent == info }), let echo = echo(of: board),
              echo.standing == .found else { return info.title }
        return echo.title
    }
}
