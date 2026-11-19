import SwiftUI
import Combine
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Pick 26: the app opens where the owner left. Which board was open and each board's zoom and place
// are kept in THIS device's own settings (never synced). The rules are in SeedboardCore, Remember.swift.

/// Writes down where the owner is, and brings a board back to the view it was left at.
@MainActor
final class Remember: ObservableObject {
    static let shared = Remember()

    private static let key = "seedboard.remembered"
    private var state = Remember.read()
    /// 0.11: the boards opened last, newest first, at most five (the Mac's "Open Recent", Extras11.swift).
    @Published private(set) var recent: [UUID] = Remember.read().recent
    private weak var model: AppModel?
    private weak var session: BoardSession?
    private var watches = Set<AnyCancellable>()
    private var viewWatch: AnyCancellable?
    private var leaving: [NSObjectProtocol] = []

    private static func read() -> Remembered {
        guard let data = UserDefaults.standard.data(forKey: key),
              let found = try? JSONDecoder().decode(Remembered.self, from: data) else { return Remembered() }
        return found
    }

    /// The board to open when the app starts; nil is the home page. Launch words for pictures and
    /// tests win, and a board that is gone falls back to the home page.
    static func boardToReopen(among boards: [Board]) -> UUID? {
        Reopen.board(read(), onDevice: Set(boards.map(\.id)), arguments: LaunchOptions.arguments)
    }

    /// Starts watching the app. With `-sampleData` nothing is remembered and nothing is brought back.
    func watch(_ model: AppModel) {
        guard self.model == nil, Reopen.remembers(arguments: LaunchOptions.arguments) else { return }
        self.model = model
        // The board that is open (told just before it changes; the first telling is what is open now).
        model.$session
            .sink { [weak self] new in self?.opened(new) }
            .store(in: &watches)
        // Once the boards are read, "which board is open" is exact (a board that was gone is forgotten).
        model.$loaded
            .filter { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.write() }
            .store(in: &watches)
        #if os(macOS)
        let names = [NSApplication.willResignActiveNotification, NSApplication.willTerminateNotification]
        #else
        let names = [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification]
        #endif
        leaving = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.write() }
            }
        }
    }

    private func opened(_ new: BoardSession?) {
        guard new !== session || new == nil else { return }
        // The board that is being left keeps its view.
        note()
        session = new
        viewWatch = nil
        if let new {
            if let left = Reopen.view(state, of: new.board.id, arguments: LaunchOptions.arguments) {
                new.comeBack(to: left)
            }
            // The view is written down a moment after the owner stops moving it.
            viewWatch = new.$place
                .dropFirst()
                .debounce(for: .seconds(0.6), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in self?.write() }
        }
        // Before the boards are read nothing is open yet: what was remembered must not be wiped.
        if model?.loaded == true {
            state.open = new?.board.id
            noteOpened(new?.board.id)
            save()
        }
    }

    /// The open board's view, as it stands now.
    private func note() {
        guard let session, let view = session.place.leftView else { return }
        state.note(view, of: session.board.id)
    }

    private func write() {
        guard let model, model.loaded else { return }
        note()
        state.open = model.session?.board.id
        noteOpened(state.open)
        state = state.keeping(Set(model.boards.map(\.id)))
        save()
    }

    private func noteOpened(_ id: UUID?) {
        guard let id, state.recent.first != id else { return }
        state.recent = RecentBoards.opened(id, in: state.recent)
        recent = state.recent
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Remember.key)
    }
}
