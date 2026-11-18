import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5: what the hand feels, and the few shared bricks of the app's motion. ONE place, so every screen uses
// the same named moment instead of its own haptic. Nothing here is felt for plain button presses, and nothing
// while the Pencil draws.

/// The eight moments the hand feels. iPhone: the Taptic motor. Mac: the trackpad (alignment and level ticks only).
/// iPad has no motor of its own; a trackpad or a Pencil Pro passes some of it on.
enum Feel {
    /// A guide line appears while dragging or sizing. At most one per 0.12 s.
    static func caught() { tick(.catch) }
    /// A shape, note or picture starts to move.
    static func lift() { tick(.lift) }
    /// An idea dropped under another idea, a map hung on a map, a note that became an idea.
    static func setDown() { tick(.setDown) }
    /// An arrow lands on a shape.
    static func joined() { tick(.joined) }
    /// "To do" switched on (off is silent).
    static func todoOn() { tick(.todoOn) }
    /// A pinch passes life size (100 %).
    static func lifeSize() { tick(.lifeSize) }
    /// A pinch reaches the smallest or largest zoom.
    static func theEnd() { tick(.theEnd) }
    /// Send to PARAGON went through.
    static func sent() { tick(.sent) }
    /// Send to PARAGON did not go through.
    static func notSent() { tick(.notSent) }

    /// "Reduce Motion" is on in the device's settings: no glide, no landing, no fade — things jump as in 0.4.
    static var reduceMotion: Bool {
        #if os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        return UIAccessibility.isReduceMotionEnabled
        #endif
    }

    /// Screen tests and pictures: nothing moves and nothing is felt, so a picture always shows the end state.
    static let still = ProcessInfo.processInfo.arguments.contains("-sampleData")
        || ProcessInfo.processInfo.arguments.contains("-stillMotion")

    /// Whether motion may run at all right now.
    static var moves: Bool { !reduceMotion && !still }

    // MARK: The motor

    private enum Moment { case `catch`, lift, setDown, joined, todoOn, lifeSize, theEnd, sent, notSent }

    private static var lastCatch = Date.distantPast

    private static func tick(_ moment: Moment) {
        guard !still else { return }
        if moment == .catch {
            let now = Date()
            guard FeelRules.mayCatch(last: lastCatch, now: now) else { return }
            lastCatch = now
        }
        #if os(macOS)
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch moment {
        case .catch: performer.perform(.alignment, performanceTime: .now)
        case .lifeSize, .theEnd: performer.perform(.levelChange, performanceTime: .now)
        case .setDown, .joined: performer.perform(.generic, performanceTime: .now)
        case .lift, .todoOn, .sent, .notSent: break
        }
        #else
        switch moment {
        case .catch, .lifeSize: UISelectionFeedbackGenerator().selectionChanged()
        case .lift: UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        case .setDown: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        case .joined: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
        case .todoOn: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .theEnd: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
        case .sent: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .notSent: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }
}

/// The colour of the one line at the bottom (`AppModel.say`).
enum FlashTone: Equatable {
    /// Plain news: boards green.
    case good
    /// Something did not work: brick red.
    case problem
    /// It went to PARAGON: PARAGON's purple.
    case paragon

    var fill: Color {
        switch self {
        case .good: return Part.boards.fill
        case .problem: return Part.kept.fill
        case .paragon: return Look.paragonButton
        }
    }
}

/// The one small pill a line at the bottom may carry, e.g. "Open".
struct FlashAction {
    let label: String
    let run: () -> Void
}

/// What was read back from PARAGON about a board's tasks — kept on THIS device only, never in a board file, so
/// looking never changes a board and makes no iCloud traffic. (0.5 groundwork: the store and the question the
/// painter asks; the PARAGON lane fills it by reading the note.)
final class ParagonEcho: ObservableObject {
    static let shared = ParagonEcho()

    /// Board → thing → how its task stands in PARAGON's note, as it was read there (in PARAGON, done, cancelled).
    @Published private(set) var read: [UUID: [UUID: TodoState]] = [:]

    /// How every to-do thing of `board` stands: what the board itself knows (waiting, in PARAGON), with what was
    /// read back from PARAGON laid over it.
    func marks(for board: Board) -> [UUID: TodoState] {
        var marks: [UUID: TodoState] = [:]
        for item in board.items {
            if let state = board.todoState(of: item.id) { marks[item.id] = state }
        }
        // Also a thing the board itself does not know as sent (a board sent by 0.4): the note says it is a task there.
        for (id, state) in read[board.id] ?? [:] where marks[id] == .inParagon || marks[id] == nil { marks[id] = state }
        return marks
    }

    /// 0.9: board → thing → the due day PARAGON has for its task ("2026-12-05"). Read each time, never in a board.
    @Published private(set) var due: [UUID: [UUID: String]] = [:]

    /// Keeps what was read for one board (replacing what was kept before).
    func keep(_ states: [UUID: TodoState], due days: [UUID: String] = [:], for board: UUID) {
        if read[board] != states { read[board] = states }
        if (due[board] ?? [:]) != days { due[board] = days.isEmpty ? nil : days }
    }
}
