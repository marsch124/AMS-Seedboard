import SwiftUI
import SeedboardCore
import AMSIcons
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// The Starters page (0.3): every starter in its order, to rename, reorder, change and remove — the seven
// built-in ones too. And the small questions that go with it (name a new starter, rename, remove) and the
// banner over a starter that is being changed. Its colour is the home page's own starter colour (`Part.boards`).

// MARK: The window's host

/// On the whole window: the Starters page and the questions that cards and menus ask.
struct StarterHost: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $model.showStarterPage, onDismiss: { model.session?.takeKeys() }) {
                StartersPage().environmentObject(model)
            }
            .modifier(StarterAsks(ask: $model.starterAsk))
            .onReceive(NotificationCenter.default.publisher(for: starterFrontNotice)) { _ in model.reloadStarters() }
    }
}

/// The app came to the front: the shelf is read again (another device may have changed it).
private var starterFrontNotice: Notification.Name {
    #if os(macOS)
    NSApplication.didBecomeActiveNotification
    #else
    UIApplication.didBecomeActiveNotification
    #endif
}

// MARK: The questions

/// Shows the name sheet and the remove question for an ask. Used by the window and by the Starters page,
/// each with its own ask, because a sheet cannot be shown over a sheet from the window.
struct StarterAsks: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @Binding var ask: StarterAsk?

    private var naming: Binding<StarterAsk?> {
        Binding(get: {
            switch ask {
            case .save?, .rename?: return ask
            default: return nil
            }
        }, set: { if $0 == nil { ask = nil } })
    }

    private var removing: Binding<Bool> {
        Binding(get: { if case .remove? = ask { return true } else { return false } },
                set: { if !$0, case .remove? = ask { ask = nil } })
    }

    private var removeName: String {
        if case .remove(let id)? = ask { return model.shelf.starter(id)?.name ?? "" }
        return ""
    }

    func body(content: Content) -> some View {
        content
            .sheet(item: naming) { question in
                StarterNameSheet(question: question) { ask = nil }
                    .environmentObject(model)
            }
            .confirmationDialog("Remove the starter “\(removeName)”?", isPresented: removing, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if case .remove(let id)? = ask { model.removeStarter(id) }
                    ask = nil
                }
                .accessibilityIdentifier("starters.removeConfirm")
                Button("Cancel", role: .cancel) { ask = nil }
            }
    }
}

/// Name a board as a starter (Cancel, Save), or rename a starter (its name and its grey line).
private struct StarterNameSheet: View {
    let question: StarterAsk
    let done: () -> Void
    @EnvironmentObject private var model: AppModel
    @State private var name = ""
    @State private var hint = ""
    @State private var ready = false

    private var renaming: String? { if case .rename(let id) = question { return id } else { return nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(renaming == nil ? "Save as a starter" : "Rename the starter")
                .font(Txt.sectionTitle)
                .foregroundStyle(Part.boards.text)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("starterName.field")
                .onSubmit(save)
            if renaming != nil {
                TextField("The grey line under the name", text: $hint)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("starterName.hint")
            }
            Text(renaming == nil ? "A new board can begin as a copy of this one." : "The grey line says what the starter is for.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", action: done)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("starterName.cancel")
                Button("Save", action: save)
                    .buttonStyle(FilledButton(.boards))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("starterName.save")
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 360)
        #else
        .presentationDetents([.height(renaming == nil ? 210 : 270)])
        #endif
        .onAppear {
            guard !ready else { return }
            ready = true
            switch question {
            case .save(let board): name = board.title
            case .rename(let id):
                let s = model.shelf.starter(id)
                name = s?.name ?? ""
                hint = s?.hint ?? ""
            default: break
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("starterName.sheet")
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        switch question {
        case .save(let board): model.saveAsStarter(board, name: name)
        case .rename(let id): model.renameStarter(id, name: name, hint: hint)
        default: break
        }
        done()
    }
}

// MARK: A card's press-and-hold menu

extension View {
    /// Rename…, Change…, Remove and "Edit starters…" on a starter card, wherever it is shown.
    func starterMenu(_ starter: ShelfStarter, ask: @escaping (StarterAsk) -> Void) -> some View {
        contextMenu {
            Button("Rename…") { ask(.rename(starter.id)) }
            Button("Change…") { ask(.change(starter.id)) }
            if starter.canBeRemoved { Button("Remove…", role: .destructive) { ask(.remove(starter.id)) } }
            Divider()
            Button("Edit starters…") { ask(.page) }
        }
    }
}

// MARK: The Starters page

struct StartersPage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var ask: StarterAsk?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                GlyphView(glyph: .app(.seedStarter), size: 22, colour: Part.boards.text)
                Text("Starters")
                    .font(Txt.big)
                    .foregroundStyle(Part.boards.text)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(FilledButton(.boards))
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("starters.done")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            List {
                Section {
                    ForEach(model.shelf.shown) { starter in
                        row(starter)
                            .deleteDisabled(true)
                    }
                    .onMove { from, to in
                        let list = model.shelf.shown
                        guard let i = from.first, list.indices.contains(i) else { return }
                        model.moveStarter(list[i].id, to: to > i ? to - 1 : to)
                    }
                } footer: {
                    Text("Drag a starter to move it. A new board begins as a copy of the starter you press.")
                }
                if model.shelf.missingBuiltins {
                    Section {
                        Button { model.bringBackStarters() } label: {
                            HStack(spacing: 8) {
                                GlyphView(glyph: .new(.bringBack), size: 18, colour: Part.boards.text)
                                Text("Bring back the built-in starters")
                                    .foregroundStyle(Part.boards.text)
                            }
                        }
                        .accessibilityIdentifier("starters.bringBack")
                    }
                }
            }
            .listStyle(.plain)
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .accessibilityIdentifier("starters.list")
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 500)
        #endif
        .modifier(StarterAsks(ask: $ask))
        .onAppear { model.reloadStarters() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("starters.page")
    }

    private func row(_ starter: ShelfStarter) -> some View {
        HStack(spacing: 10) {
            BoardThumb(starter: starter)
                .frame(width: 64)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(starter.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(starter.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Menu {
                Button("Rename…") { ask = .rename(starter.id) }
                    .accessibilityIdentifier("starters.rename.\(starter.id)")
                Button("Change…") { model.changeStarter(starter.id) }
                    .accessibilityIdentifier("starters.change.\(starter.id)")
                if starter.isChangedBuiltin {
                    Button("Back to the original") { model.starterBackToOriginal(starter.id) }
                        .accessibilityIdentifier("starters.original.\(starter.id)")
                }
                if starter.canBeRemoved {
                    Button("Remove…", role: .destructive) { ask = .remove(starter.id) }
                        .accessibilityIdentifier("starters.remove.\(starter.id)")
                }
            } label: {
                Text("Edit")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Part.boards.text)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Edit \(starter.name)")
            .accessibilityIdentifier("starters.more.\(starter.id)")
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Rename…") { ask = .rename(starter.id) }
            Button("Change…") { model.changeStarter(starter.id) }
            if starter.isChangedBuiltin { Button("Back to the original") { model.starterBackToOriginal(starter.id) } }
            if starter.canBeRemoved { Button("Remove…", role: .destructive) { ask = .remove(starter.id) } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("starters.row.\(starter.id)")
    }
}

// MARK: Over a starter that is being changed

/// "Changing the starter “Name”" with Cancel and Save, at the top of the board screen.
struct StarterChangeBanner: View {
    @EnvironmentObject private var model: AppModel
    @State private var discarding = false

    var body: some View {
        HStack(spacing: 8) {
            Text("Changing the starter “\(model.changing?.name ?? "")”")
                .font(Txt.label.weight(.semibold))
                .foregroundStyle(Part.boards.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button("Cancel") {
                if model.changing?.dirty == true { discarding = true } else { model.endChange() }
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("starter.change.cancel")
            Button("Save") { model.saveChange() }
                .buttonStyle(FilledButton(.boards))
                .accessibilityIdentifier("starter.change.save")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Part.boards.soft, in: Capsule())
        .overlay(Capsule().stroke(Part.boards.text.opacity(0.4)))
        .confirmationDialog("Discard the changes?", isPresented: $discarding, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { model.endChange() }
                .accessibilityIdentifier("starter.change.discard")
            Button("Keep changing", role: .cancel) {}
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("starter.change.banner")
    }
}
