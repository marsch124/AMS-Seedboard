import SwiftUI
import SeedboardCore
import AMSIcons
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5 (the feel lane): the empty board and the first start invite. The rules are in Core (FeelRules.swift).

// MARK: The empty board

/// In the middle of an empty board: the sprout, "What is on your mind?" and three ways to begin, each in its
/// own colour. One press does what the tool does, and the invitation fades (0.15 s). Nothing here is shown
/// on a timeline or a "Who does what" board; a board that cannot be changed gets the sprout and one line.
struct EmptyInvite: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    /// The Draw tool: while it is on, the board is left clear for the Pencil or the finger.
    @ObservedObject var desk: InkDesk
    /// Words lie on the clipboard (asked without reading them, so the iPhone shows no paste banner).
    @State private var wordsCopied = EmptyInvite.wordsAreCopied()

    var body: some View {
        let kind = session.board.invitation(readOnly: session.readOnly, drawing: desk.on)
        ZStack {
            if kind != .none {
                VStack(spacing: 10) {
                    AppMarkView(.seedSprout, size: 40, colour: Part.boards.text.opacity(0.7))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    Text(kind == .starts ? "What is on your mind?" : "An empty board")
                        .font(Txt.bigRow)
                        .multilineTextAlignment(.center)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("empty.words")
                    if kind == .starts {
                        // Side by side; on a narrow iPhone one under the other.
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) { starts }
                            VStack(spacing: 8) { starts }
                        }
                        .padding(.top, 2)
                        .padding(.horizontal, -12)
                        Text(MenuWords.doubleNoteHint)
                            .font(Txt.label)
                            .foregroundStyle(.secondary)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("empty.hint")

                    }
                }
                .padding(.horizontal, 20)
                // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board.empty")
                .transition(.opacity)
            }
        }
        .animation(Feel.moves ? .easeOut(duration: 0.15) : nil, value: kind)
        .onAppear { wordsCopied = EmptyInvite.wordsAreCopied() }
        .onReceive(NotificationCenter.default.publisher(for: EmptyInvite.cameToFront)) { _ in wordsCopied = EmptyInvite.wordsAreCopied() }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in wordsCopied = EmptyInvite.wordsAreCopied() }
        #endif
    }

    @ViewBuilder
    private var starts: some View {
        start(.mindMap, .app(.seedMindMap), .mindMap)
        start(.note, .app(.seedNote), .notes)
        start(.paste, .new(.paste), .boards)
    }

    private func start(_ way: FeelRules.Start, _ glyph: Glyph, _ part: Part) -> some View {
        let outline = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button {
            run(way)
            session.takeKeys()
        } label: {
            HStack(spacing: 6) {
                GlyphView(glyph: glyph, size: Finger.on ? 18 : 17, colour: part.text)
                Text(way.word)
                    .font(Txt.label.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 10)
            .frame(height: Finger.on ? 36 : 28)
            .background(part.soft, in: outline)
            .overlay(outline.stroke(part.text.opacity(0.35)))
            .contentShape(Rectangle())
            .pressRoom(0, 4)
        }
        .buttonStyle(PressStyle(tint: part.text))
        // Pale while nothing is copied; it can still be pressed (the clipboard may have changed meanwhile).
        .opacity(FeelRules.startIsPale(way, wordsCopied: wordsCopied) ? 0.45 : 1)
        .accessibilityLabel(way.word)
        .accessibilityIdentifier(way.id)
    }

    private func run(_ way: FeelRules.Start) {
        switch way {
        case .mindMap: session.add(.idea)
        case .note: session.add(.note)
        case .paste:
            if let text = model.clipboardText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                session.paste(text)
            } else {
                model.say("Nothing to paste.", tone: .problem)
            }
        }
    }

    /// Whether words are copied — asked without reading them.
    private static func wordsAreCopied() -> Bool {
        #if os(macOS)
        return NSPasteboard.general.availableType(from: [.string]) != nil
        #else
        return UIPasteboard.general.hasStrings
        #endif
    }

    /// The app came to the front: something may have been copied elsewhere meanwhile.
    private static var cameToFront: Notification.Name {
        #if os(macOS)
        return NSApplication.didBecomeActiveNotification
        #else
        return UIApplication.didBecomeActiveNotification
        #endif
    }
}

// MARK: An empty board's card

/// On the card of a board with nothing on it: a faint sprout (22 points, 35 %) instead of the word "Empty".
struct EmptySprout: View {
    var body: some View {
        AppMarkView(.seedSprout, size: 22, colour: Part.boards.text.opacity(0.35))
            .accessibilityLabel("Empty")
    }
}

// MARK: The iPhone with no boards

/// The iPhone's list while there is no board yet: the sprout, "Plant a seed" and the starters themselves,
/// two in a row. One press makes the first board; they leave when it exists.
struct FirstSeeds: View {
    @EnvironmentObject private var model: AppModel
    let open: (UUID) -> Void

    private let columns = [GridItem(.flexible(), spacing: 8, alignment: .top), GridItem(.flexible(), spacing: 8, alignment: .top)]

    var body: some View {
        VStack(spacing: 4) {
            AppMarkView(.seedSprout, size: 40, colour: Part.boards.text)
                .accessibilityHidden(true)
            Text("Plant a seed")
                .font(Txt.big)
            Text("Every idea starts on a board.")
                .font(Txt.label)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(model.shelf.shown) { starter in
                    StarterCard(starter: starter, pick: { open(model.newBoard(from: starter)) }, ask: { model.ask($0) })
                        .accessibilityIdentifier("first.starter.\(starter.id)")
                }
            }
            .padding(.top, 10)
            // Room for the cards' faint shadow and edge.
            .padding(.horizontal, 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .padding(.top, 18)
        // Its own element with its cards inside, so each card keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("boards.first")
    }
}


/// 0.19: two quick presses on empty board make a sticky note on every device, so the hint shows everywhere.
enum MenuWords {
    #if os(macOS)
    static let doubleNoteHint = "or double-click anywhere for a sticky note"
    #else
    static let doubleNoteHint = "or tap twice anywhere for a sticky note"
    #endif
}
