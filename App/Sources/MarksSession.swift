import SwiftUI
import SeedboardCore
import LinkPresentation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.9, "marks": what the board does for vote dots, pinning, tick lists, links and the legend (the rules are in
// SeedboardCore: Marks09.swift). Everything goes through the session's undo, except a fetched page title.

/// What the screens tell each other: the legend page is asked for.
@MainActor
final class MarksDesk: ObservableObject {
    static let shared = MarksDesk()
    @Published var legendOpen = false
}

extension BoardSession {
    /// The marks work on ordinary boards only (a timeline and a "Who does what" board place their things themselves).
    var marksOn: Bool { !readOnly && !board.placesItself }

    func vote() {
        guard marksOn, editing == nil, !selection.isEmpty else { return }
        let ids = selection
        change { $0.addDot(ids) }
    }

    func removeDot() {
        guard marksOn, editing == nil else { return }
        let ids = selection
        change { $0.removeDot(ids) }
    }

    func clearDots() {
        guard marksOn, editing == nil else { return }
        let ids = selection
        change { $0.clearDots(ids) }
    }

    func clearAllDots() {
        guard marksOn else { return }
        commitEdit()
        change { $0.clearAllDots() }
    }

    func sortByDots() {
        guard marksOn else { return }
        commitEdit()
        if change({ $0.sortByDots() }) { tell("The things with dots are in a row, most dots first.") }
    }

    func togglePinned() {
        guard marksOn, editing == nil, !selection.isEmpty else { return }
        let ids = selection
        let pin = !board.allPinned(ids)
        change { $0.setPinned(ids, pin) }
    }

    /// "Tick list": every line of the chosen notes becomes a tick line, or goes back to a plain line.
    func tickList() {
        guard marksOn, editing == nil else { return }
        let ids = selection.filter { board.item($0)?.kind == .note }
        guard !ids.isEmpty else { return }
        change(widen: ids) { board in
            for id in ids {
                guard let i = board.index(of: id) else { continue }
                board.items[i].text = TickList.turned(board.items[i].text)
            }
        }
    }

    /// A press at this board point on a tick box or on the line with the page's title: ticks the box, or opens the page.
    /// True when the press was for one of them.
    func pressMark(_ id: UUID, at p: CGPoint) -> Bool {
        guard editing == nil, !board.placesItself, let item = board.item(id) else { return false }
        if item.kind == .note, let line = TickLayout.box(of: item, at: p) {
            if marksOn { change { $0.items[$0.index(of: id)!].text = TickList.toggled(item.text, line: line) } }
            return true
        }
        if LinkLine.rect(for: item)?.contains(p) == true {
            openLink(id)
            return true
        }
        return false
    }

    func openLink(_ id: UUID) {
        guard let item = board.item(id), let url = WebAddress.url(in: item.text) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    func setLegend(_ words: [String: String]) {
        guard marksOn else { return }
        change { $0.setLegend(words) }
    }

    func setBackdrop(_ kind: Backdrop) {
        guard marksOn else { return }
        change { $0.backdropKind = kind }
    }
}

/// Fetches the title of a web page once for each address (LinkPresentation) and keeps it with the thing (`linkTitle`).
@MainActor
final class LinkTitles {
    static let shared = LinkTitles()
    /// Thing → the address a title was asked for (this run). A new address is a new ask.
    private var asked: [UUID: String] = [:]

    func refresh(_ session: BoardSession) {
        // Not on a board that cannot be changed, and not while words are typed (an unfinished address is no address).
        guard session.marksOn, session.editing == nil else { return }
        // A title whose address is gone goes with it.
        let stale = session.board.items.filter { $0.linkTitle != nil && WebAddress.first(in: $0.text) == nil }.map(\.id)
        if !stale.isEmpty {
            session.quietly { board in
                for id in stale { if let i = board.index(of: id) { board.items[i].linkTitle = nil } }
            }
            for id in stale { asked[id] = nil }
        }
        for (id, address) in session.board.linksToFetch(fetched: asked) {
            asked[id] = address
            guard let url = URL(string: address) else { continue }
            Task { await self.fetch(url, address: address, for: id, in: session, tries: 0) }
        }
    }

    private func fetch(_ url: URL, address: String, for id: UUID, in session: BoardSession, tries: Int) async {
        let provider = LPMetadataProvider()
        provider.timeout = 12
        let title = (try? await provider.startFetchingMetadata(for: url))?.title ?? ""
        store(title, address: address, for: id, in: session, tries: tries)
    }

    /// Writes the title when the thing still holds that address; waits a moment when the board is being typed in or dragged.
    private func store(_ title: String, address: String, for id: UUID, in session: BoardSession, tries: Int) {
        if session.busy && tries < 20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                MainActor.assumeIsolated { self.store(title, address: address, for: id, in: session, tries: tries + 1) }
            }
            return
        }
        session.quietly { board in
            guard let i = board.index(of: id), WebAddress.first(in: board.items[i].text) == address else { return }
            board.items[i].linkTitle = title
        }
    }
}

/// Put on the open board once (BoardView.swift): the legend page, and the titles of web addresses.
struct MarksHost: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = MarksDesk.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $desk.legendOpen, onDismiss: { session.takeKeys() }) {
                LegendPage(session: session)
            }
            .onAppear { LinkTitles.shared.refresh(session) }
            .onReceive(session.objectWillChange.debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)) { _ in
                LinkTitles.shared.refresh(session)
            }
    }
}
