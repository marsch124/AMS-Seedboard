import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.5, pick 29: the board's name in the top bar. On the Mac a click on the name opens "Name of the board"
// (the same question as More ▸ Rename…), and a right-click on it opens a small menu: Rename…, Pin to the top,
// Make a copy, Save as a starter…. The name stays the system's own title, where it always was (a title drawn by
// the app moved the buttons beside it; the system's own title menu and renaming do not answer a click on the Mac).
// On the iPad the name carries the same menu (the system's own title menu). The iPhone's top bar stays as it is.
// The More button stays as it is everywhere.

/// On the open board (`BoardView`): the board's name as the window's title, and its menu.
struct BoardTitle: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    /// Opens the question "Name of the board" (the same one as More ▸ Rename…).
    let rename: () -> Void

    /// On a starter's working copy the name is the starter's.
    private var name: String { session.starterDraft ? (model.changing?.name ?? session.board.title) : session.board.title }

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .navigationTitle(name)
            .background(TitleClicks(name: name, click: session.readOnly ? nil : { openRename() }, menu: macLines))
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .navigationTitle(name)
                .toolbarTitleMenu { lines }
        } else {
            content.navigationTitle(name)
        }
        #endif
    }

    private func openRename() {
        session.commitEdit()
        rename()
    }

    #if os(macOS)
    /// The right-click menu of the name: the same lines as `lines`, as the Mac's own menu.
    private func macLines() -> [TitleClicks.Line] {
        var out = [TitleClicks.Line(words: "Rename…", id: "title.rename", on: !session.readOnly) { openRename() }]
        if !session.starterDraft {
            out.append(.init(words: session.board.pinned ? "Unpin" : "Pin to the top", id: "title.pin") {
                model.togglePin(session.board.id)
                session.takeKeys()
            })
            out.append(.init(words: "Make a copy", id: "title.copy") {
                session.commitEdit()
                model.duplicate(session.board.id)
            })
            if !session.readOnly {
                out.append(.init(words: "Save as a starter…", id: "title.starter") {
                    session.commitEdit()
                    model.ask(.save(session.board))
                })
            }
        }
        return out
    }
    #endif

    /// The same words as in the More menu and in the list's menu.
    @ViewBuilder
    private var lines: some View {
        Button("Rename…") { rename() }
            .disabled(session.readOnly)
            .accessibilityIdentifier("title.rename")
        if !session.starterDraft {
            Button(session.board.pinned ? "Unpin" : "Pin to the top") {
                model.togglePin(session.board.id)
                session.takeKeys()
            }
            .accessibilityIdentifier("title.pin")
            Button("Make a copy") {
                session.commitEdit()
                model.duplicate(session.board.id)
            }
            .accessibilityIdentifier("title.copy")
            if !session.readOnly {
                Button("Save as a starter…") {
                    session.commitEdit()
                    model.ask(.save(session.board))
                }
                .accessibilityIdentifier("title.starter")
            }
        }
    }
}

#if os(macOS)
/// Catches a click and a right-click on the system's title in the window's top bar (the board's name).
struct TitleClicks: NSViewRepresentable {
    struct Line {
        let words: String
        let id: String
        var on = true
        let act: () -> Void
    }

    let name: String
    /// nil: the board cannot be changed, a click does nothing.
    let click: (() -> Void)?
    let menu: () -> [Line]

    func makeCoordinator() -> Clicks { Clicks() }
    func makeNSView(context: Context) -> Finder {
        let view = Finder()
        view.clicks = context.coordinator
        return view
    }

    func updateNSView(_ view: Finder, context: Context) {
        context.coordinator.click = click
        context.coordinator.menu = menu
        // The title may have been drawn anew (a new name): look again once it is there.
        DispatchQueue.main.async { view.hook() }
    }

    final class Finder: NSView {
        weak var clicks: Clicks?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.hook() }
        }

        /// Puts the two catchers on the title, once per title.
        func hook() {
            guard let clicks, let top = window?.contentView?.superview, let title = Self.title(in: top), clicks.hooked !== title else { return }
            clicks.hooked = title
            let one = NSClickGestureRecognizer(target: clicks, action: #selector(Clicks.clicked(_:)))
            let right = NSClickGestureRecognizer(target: clicks, action: #selector(Clicks.rightClicked(_:)))
            right.buttonMask = 0x2
            title.addGestureRecognizer(one)
            title.addGestureRecognizer(right)
            title.setAccessibilityIdentifier("title.name")
        }

        /// The system's title field in the top bar.
        static func title(in view: NSView) -> NSView? {
            if String(describing: type(of: view)) == "_NSToolbarTitleField" { return view }
            for inner in view.subviews { if let found = title(in: inner) { return found } }
            return nil
        }
    }

    @MainActor
    final class Clicks: NSObject {
        weak var hooked: NSView?
        var click: (() -> Void)?
        var menu: () -> [Line] = { [] }
        private var acts: [() -> Void] = []

        @objc func clicked(_ sender: NSClickGestureRecognizer) { click?() }

        @objc func rightClicked(_ sender: NSClickGestureRecognizer) {
            guard let view = sender.view else { return }
            let lines = menu()
            acts = lines.map(\.act)
            let shown = NSMenu()
            shown.autoenablesItems = false
            for (n, line) in lines.enumerated() {
                let item = NSMenuItem(title: line.words, action: #selector(picked(_:)), keyEquivalent: "")
                item.target = self
                item.tag = n
                item.isEnabled = line.on
                item.setAccessibilityIdentifier(line.id)
                shown.addItem(item)
            }
            shown.popUp(positioning: nil, at: NSPoint(x: 0, y: view.isFlipped ? view.bounds.maxY + 4 : -4), in: view)
        }

        @objc func picked(_ sender: NSMenuItem) {
            guard acts.indices.contains(sender.tag) else { return }
            acts[sender.tag]()
        }
    }
}
#endif
