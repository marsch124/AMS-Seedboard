import SwiftUI
import UniformTypeIdentifiers
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Copy, cut and paste (0.2, pick 17). The rules are in SeedboardCore (`Clip`). Here: the system
// clipboard, the keys and menu lines, text dropped on the board, and Option with a drag on the Mac.
//
// Copy puts the chosen things onto the clipboard in three forms: Seedboard's own (the things and
// the arrows between them), plain words (for a text field or another app) and a picture.
// Paste takes Seedboard's own form when it is there; otherwise words become a sticky note, and a
// list becomes a mind map.

@MainActor
enum ClipBoard {
    // MARK: What can be done right now

    static func canCopy(_ session: BoardSession) -> Bool {
        session.editing == nil && !session.selection.isEmpty && !session.board.placesItself
    }

    static func canCut(_ session: BoardSession) -> Bool { canCopy(session) && !session.readOnly }

    static func canPaste(_ session: BoardSession) -> Bool {
        guard !session.readOnly, session.editing == nil, !session.board.placesItself else { return false }
        #if os(macOS)
        let types = NSPasteboard.general.types ?? []
        return types.contains(ownType) || types.contains(.string)
        #else
        return UIPasteboard.general.contains(pasteboardTypes: [Clip.type]) || UIPasteboard.general.hasStrings
        #endif
    }

    // MARK: The system clipboard

    #if os(macOS)
    private static let ownType = NSPasteboard.PasteboardType(Clip.type)
    #endif

    /// A number that changes whenever something new is put on the clipboard.
    private static var stamp: Int {
        #if os(macOS)
        return NSPasteboard.general.changeCount
        #else
        return UIPasteboard.general.changeCount
        #endif
    }

    private static func write(_ clip: Clip, picture: Data?) -> Bool {
        guard let data = clip.encoded() else { return false }
        let words = clip.text
        #if os(macOS)
        let board = NSPasteboard.general
        board.clearContents()
        var types: [NSPasteboard.PasteboardType] = [ownType, .string]
        if picture != nil { types.append(.png) }
        board.declareTypes(types, owner: nil)
        board.setData(data, forType: ownType)
        board.setString(words, forType: .string)
        if let picture { board.setData(picture, forType: .png) }
        #else
        var forms: [String: Any] = [Clip.type: data, UTType.utf8PlainText.identifier: words]
        if let picture { forms[UTType.png.identifier] = picture }
        UIPasteboard.general.setItems([forms], options: [:])
        #endif
        return true
    }

    private static func readClip() -> Clip? {
        #if os(macOS)
        return NSPasteboard.general.data(forType: ownType).flatMap(Clip.decoded)
        #else
        guard UIPasteboard.general.contains(pasteboardTypes: [Clip.type]) else { return nil }
        return UIPasteboard.general.data(forPasteboardType: Clip.type).flatMap(Clip.decoded)
        #endif
    }

    private static func readWords() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.hasStrings ? UIPasteboard.general.string : nil
        #endif
    }

    // MARK: Copy, cut, paste

    /// Copies the chosen things with the arrows between them. True when something was copied.
    @discardableResult
    static func copy(_ session: BoardSession, say: Bool = true) -> Bool {
        guard canCopy(session) else { return false }
        let clip = session.board.clip(of: session.selection)
        guard !clip.isEmpty, write(clip, picture: BoardPicture.png(of: clip.asBoard())) else { return false }
        // A paste right onto the copied things is set off, so it does not hide them.
        BarDesk.shared.copied(stamp: stamp, from: clip.bounds.map { CGPoint(x: $0.midX, y: $0.midY) })
        let count = session.selection.count
        if say { AppModel.shared.say(count == 1 ? "Copied. Paste it here or in another board." : "\(count) things copied. Paste them here or in another board.") }
        return true
    }

    /// Copies the chosen things and takes them off the board (one step for Undo).
    static func cut(_ session: BoardSession) {
        guard canCut(session), copy(session, say: false) else { return }
        // They are gone from here: the first paste lands exactly where it is asked for.
        BarDesk.shared.copied(stamp: stamp, from: nil)
        session.deleteSelection()
    }

    /// Pastes what is on the clipboard. `spot` (board points): where it was asked for — the pressed
    /// spot of a menu; nil: under the pointer when it is over the board, else a free place near the
    /// middle of the view.
    static func paste(_ session: BoardSession, at spot: CGPoint? = nil) {
        guard !session.readOnly, session.editing == nil, !session.board.placesItself else { return }
        // Asked for at a spot: exactly there, and 28 further each time the same is pasted there again.
        // Otherwise: a free place near the middle of the view.
        let asked = spot ?? BarDesk.shared.pointer.map { session.toBoard($0) }
        func place(_ size: CGSize) -> CGPoint {
            if let asked { return BarDesk.shared.pasteSpot(stamp: stamp, at: asked) }
            return session.freeSpot(near: session.visibleCentre, size: size)
        }
        let chosenIdea = session.single.flatMap { $0.kind == .idea ? $0.id : nil }

        if let clip = readClip() {
            guard clip.canBePasted else {
                AppModel.shared.say("These things were copied in a newer Seedboard. Update the app to paste them.")
                return
            }
            var made: Set<UUID> = []
            if let chosenIdea, clip.isOnlyIdeas {
                // Ideas pasted with an idea chosen hang under it.
                session.change { made = $0.paste(clip, under: chosenIdea) }
            } else {
                let spot = place(clip.bounds?.size ?? ItemKind.note.defaultSize)
                session.change { made = $0.paste(clip, at: spot) }
            }
            guard !made.isEmpty else { return }
            session.selectedLink = nil
            session.selection = made
            if let first = made.first { session.reveal(first) }
            return
        }

        guard let words = readWords(), !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AppModel.shared.say("Nothing to paste.")
            return
        }
        if chosenIdea != nil {
            // A list pasted with an idea chosen hangs under it, as before.
            session.paste(words)
        } else {
            land(words, at: place(Outline.isList(words) ? CGSize(width: 300, height: 200) : ItemKind.note.defaultSize), in: session)
        }
    }

    /// Words from elsewhere become a sticky note, a list a mind map, at the spot (board points).
    private static func land(_ words: String, at spot: CGPoint, in session: BoardSession) {
        var made: UUID?
        session.change { made = $0.addWords(words, at: spot) }
        guard let made else { return }
        session.selectedLink = nil
        session.selection = [made]
    }

    // MARK: Dropped words

    /// Words dragged in from another app (Safari, Notes …) land where they are dropped.
    static func drop(_ providers: [NSItemProvider], at location: CGPoint, into session: BoardSession) -> Bool {
        guard !session.readOnly, !session.board.placesItself,
              let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { words, _ in
            guard let words = words as? String else { return }
            Task { @MainActor in
                session.commitEdit()
                land(words, at: session.toBoard(location), in: session)
                session.takeKeys()
            }
        }
        return true
    }

    // MARK: The keys

    /// ⌘C, ⌘X and ⌘V on the board when no menu line took them. False: not one of the three, or nothing to do.
    static func key(_ letter: String, _ session: BoardSession) -> Bool {
        switch letter.lowercased() {
        case "c": return copy(session)
        case "x":
            guard canCut(session) else { return false }
            cut(session)
            return true
        case "v":
            guard canPaste(session) else { return false }
            paste(session)
            return true
        default:
            return false
        }
    }
}

extension BoardSession {
    /// ⌘C, ⌘X, ⌘V typed on the board (`CanvasView.handleKey`).
    func clipKey(_ letter: String) -> Bool { ClipBoard.key(letter, self) }

    /// The Mac: a drag of things was let go with Option held — a copy of what was dragged lands
    /// there (a frame with what lies in it, a map with its ideas, the arrows between them) and the
    /// things themselves go back to where they were. One step for Undo. False: not an Option-drag.
    func dropCopy() -> Bool {
        #if os(macOS)
        guard NSEvent.modifierFlags.contains(.option), !readOnly, !board.placesItself else { return false }
        // Where the drag has taken things; then they go back, and what moved is known.
        let there = board.items.reduce(into: [UUID: CGPoint]()) { $0[$1.id] = $1.frame.origin }
        liveEnd(keep: false)
        var moved: Set<UUID> = []
        var way = CGSize.zero
        for item in board.items {
            guard let to = there[item.id] else { continue }
            let step = CGSize(width: to.x - item.frame.minX, height: to.y - item.frame.minY)
            guard abs(step.width) > 0.5 || abs(step.height) > 0.5 else { continue }
            if moved.isEmpty { way = step }
            moved.insert(item.id)
        }
        guard !moved.isEmpty else { return true }
        var copies: Set<UUID> = []
        change { copies = $0.duplicate(moved, by: way) }
        // The copies are chosen (not the ideas that hang under a copied idea).
        let tops = copies.filter { id in board.item(id).map { $0.kind != .idea || $0.parent == nil } ?? false }
        if !tops.isEmpty {
            selectedLink = nil
            selection = tops
        }
        return true
        #else
        return false
        #endif
    }
}

/// On the drawing surface (`CanvasView`): the Mac's Edit ▸ Cut, Copy and Paste reach the board while
/// it has the keys (while words are typed they belong to the words, as everywhere); and words
/// dragged in from another app land where they are dropped.
struct ClipKeys: ViewModifier {
    @ObservedObject var session: BoardSession

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .onCommand(#selector(NSText.copy(_:)), perform: ClipBoard.canCopy(session) ? { ClipBoard.copy(session) } : nil)
            .onCommand(#selector(NSText.cut(_:)), perform: ClipBoard.canCut(session) ? { ClipBoard.cut(session) } : nil)
            .onCommand(#selector(NSText.paste(_:)),
                       perform: !session.readOnly && session.editing == nil && !session.board.placesItself ? { ClipBoard.paste(session) } : nil)
            #endif
            .onDrop(of: [UTType.plainText, UTType.utf8PlainText, UTType.text], isTargeted: nil) { providers, location in
                ClipBoard.drop(providers, at: location, into: session)
            }
    }
}

/// Edit ▸ Cut, Copy, Paste on an iPad (or iPhone) with a keyboard. The Mac keeps the system's own
/// three lines — the board answers them through `ClipKeys` — so Delete and Select All stay as they are.
struct ClipCommands: Commands {
    @FocusedObject private var session: BoardSession?

    var body: some Commands {
        #if os(macOS)
        EmptyCommands()
        #else
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") { act(#selector(UIResponderStandardEditActions.cut(_:))) { ClipBoard.cut($0) } }
                .keyboardShortcut("x", modifiers: .command)
            Button("Copy") { act(#selector(UIResponderStandardEditActions.copy(_:))) { ClipBoard.copy($0) } }
                .keyboardShortcut("c", modifiers: .command)
            Button("Paste") { act(#selector(UIResponderStandardEditActions.paste(_:))) { ClipBoard.paste($0) } }
                .keyboardShortcut("v", modifiers: .command)
        }
        #endif
    }

    #if !os(macOS)
    /// On the board: the board's own step. Anywhere else (words being typed, a name field, the
    /// Send page): the key is passed to the text field that has the keys.
    private func act(_ selector: Selector, _ onBoard: (BoardSession) -> Void) {
        if let session, MenuDesk.shared.surfaceHasKeys(session) {
            onBoard(session)
        } else {
            UIApplication.shared.sendAction(selector, to: nil, from: nil, for: nil)
        }
    }
    #endif
}
