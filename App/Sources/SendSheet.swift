import SwiftUI
import SeedboardCore
import AMSIcons

/// Send to PARAGON: choose what the board becomes, then Send. Cancel (or Escape) leaves everything as it is.
struct SendSheet: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    @Environment(\.dismiss) private var dismiss

    @State private var kind: SendKind = .note
    @State private var title = ""
    @State private var busy = false
    @State private var problem: String?
    /// 0.5: the hand-over went through — the Send button shows its white tick for a moment.
    /// For pictures: `-sendDone` shows the tick at once.
    @State private var done = LaunchOptions.arguments.contains("-sendDone")
    /// Only the chosen idea and everything under it is sent.
    @State private var branchOnly = false
    /// 0.9: only what lies inside the chosen frame is sent. On at first when one frame is chosen.
    @State private var frameOnly = false
    /// 0.11 (pick 27): only the things chosen on the board are sent (two or more chosen).
    @State private var chosenOnly = false

    /// What a look at the note the board became found (reading only); nil while that is not known, and for a
    /// board that was never sent as a note or a project.
    @State private var look: NoteLook?
    /// "Say where they come from": on at first, remembered on this device.
    @AppStorage("send.sayOrigin") private var sayOrigin = true
    /// "Also remind me when a bar starts" (a timeline): off each time the page opens.
    @State private var remindStarts = false

    /// The one chosen idea, when there is one: the page then offers to send just that branch.
    private var branch: Item? { session.branchToSend }
    /// 0.9: the one chosen frame, when the page can offer "Only this frame (…)".
    private var frame: Item? { session.frameToSend }
    /// A part of the board is sent (a branch or a frame), not the whole of it.
    private var partOnly: Bool { (branchOnly && branch != nil) || (frameOnly && frame != nil) || chosenActive }
    /// 0.11: how many things are chosen when the page can offer "The 3 chosen things" (two or more, no single branch or frame).
    private var chosenCount: Int? {
        guard branch == nil, frame == nil, session.selection.count >= 2, session.board.chosenOnly(session.selection) != nil else { return nil }
        return session.selection.count
    }
    private var chosenActive: Bool { chosenOnly && chosenCount != nil }
    /// The whole board (for pictures: the sample board shown as sent before, SendParts.swift).
    private var whole: Board { SendSample.board(session.board) }
    /// What is sent: the whole board, or the chosen branch as a small map of its own.
    private var subject: Board {
        if frameOnly, let frame, let part = session.board.frameOnly(frame.id) { return part }
        if chosenActive, let part = session.board.chosenOnly(session.selection) { return part }
        guard branchOnly, let branch, let part = session.board.branchOnly(branch.id) else { return whole }
        return part
    }
    private var waiting: Int { ParagonExport.inboxTasks(board: subject).count }
    private var todoCount: Int { subject.items.filter(\.todo).count }
    /// The to-do boxes that become tasks in a note: those the Inbox does not have already.
    private var todoTasks: Int { subject.items.filter { $0.todo && !subject.isInInbox($0.id) }.count }
    private var choices: SendChoices { SendChoices(sayOrigin: sayOrigin, remindStarts: remindStarts && subject.isTimeline) }
    /// The look counts for the whole board only: a branch is a small map of its own.
    private var subjectLook: NoteLook? { partOnly ? nil : look }
    /// What has become a task since the board went to PARAGON; nil when it never did (or it cannot be told).
    private var news: NewTasks? { partOnly ? nil : ParagonExport.newTasks(board: whole, look: look) }
    /// What "Add what is new" would send; nil when nothing is new.
    private var adding: LinesToSend? { partOnly ? nil : ParagonExport.addSend(board: whole, look: look, choices: choices) }

    private var canSend: Bool {
        guard model.paragonReady, !busy, !session.readOnly else { return false }
        if kind == .todos { return waiting > 0 && model.place?.outbox != nil }
        if kind == .add { return adding != nil && model.place?.outbox != nil }
        return !subject.isEmpty
    }

    /// The rows of the box "What PARAGON gets", read out of the very text Send writes, and how many things
    /// stand in it as a plain line because the Inbox has them.
    private var gets: (rows: [PreviewRow], inInbox: Int) {
        switch kind {
        case .note:
            let made = ParagonExport.noteHandover(board: subject, title: title, picture: "picture.png", now: Date(), choices: choices)
            return (ParagonExport.preview(ofNote: made.text), made.inInbox)
        case .project:
            let made = ParagonExport.projectHandover(board: subject, title: title, picture: "picture.png", now: Date(), choices: choices)
            return (ParagonExport.preview(ofNote: made.text), made.inInbox)
        case .todos:
            return (ParagonExport.preview(ofTasks: ParagonExport.inboxSend(board: subject, look: subjectLook, choices: choices).lines), 0)
        case .add:
            return (ParagonExport.preview(ofTasks: adding?.lines ?? []), 0)
        }
    }

    /// The words under "Only the to-do boxes".
    private var todosWords: String {
        if waiting == 0 {
            if todoCount == 0 { return "No to-do boxes are waiting. Choose a box and press To do first." }
            return todoCount == 1 ? "The 1 to-do box is already in PARAGON." : "All \(todoCount) to-do boxes are already in PARAGON."
        }
        return (waiting == 1 ? "1 to-do box goes to the Inbox as a task." : "\(waiting) to-do boxes go to the Inbox as tasks.")
            + " " + ParagonGate.whenTheyShow
    }

    var body: some View {
        #if os(macOS)
        page.frame(width: 470)
        #else
        // As tall as its words (it scrolls when the room is short). On the iPhone the page is full
        // height, so its title is never cut off; on the iPad it is a card just as tall as what is in it.
        ScrollView {
            page
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.large])
        .modifier(FittedPage())
        #endif
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AppMarkView(.send, size: 22, colour: Part.paragon.text)
                Text("Send to PARAGON")
                    .font(Txt.big)
                    .foregroundStyle(Part.paragon.text)
            }

            if !model.paragonReady {
                Text(model.paragonLine)
                    .font(Txt.label)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Part.notes.soft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityIdentifier("send.notReady")
            }

            if let sent = whole.sent, let adding {
                // The board already is a note or a project in PARAGON and holds new tasks: the first row, chosen.
                choice(.add, "Add what is new to “\(sent.title)”",
                       ParagonExport.addRowWords(count: adding.tasks.count, sentAs: sent.kind, noteThere: adding.notePath != nil))
            }
            choice(.note, "As a note",
                   session.board.isSequence ? SequenceWords.sendNote :
                   session.board.isTimeline
                   ? "The timeline's picture and its bars with their dates. It goes to Resources, and one line in the Inbox points to it."
                   : "The board's picture and its words as a tidy outline. It goes to Resources, and one line in the Inbox points to it.")
            if !chosenActive { choice(.project, "As a project",
                   session.board.isSequence ? SequenceWords.sendProject :
                   session.board.isTimeline
                   ? "The phases become headings, the bars become tasks with their start and due day. It goes to Projects."
                   : "The branches become headings. The ideas you ticked To do become tasks; with nothing ticked, all of them do. It goes to Projects.") }
            choice(.todos, "Only the to-do boxes", todosWords)

            if let frame {
                FrameSwitch(words: session.frameSwitchWords(frame), on: $frameOnly)
                if frameOnly {
                    Text("Just what lies inside this frame is sent, with a picture of the frame alone. The board is not marked as sent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let count = chosenCount {
                SendSwitch(words: Board.chosenWords(count), on: $chosenOnly, identifier: "send.chosenOnly")
                if chosenOnly {
                    Text("Just these things are sent, as a note or as to-dos. The board is not marked as sent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let branch {
                BranchSwitch(words: session.branchSwitchWords(branch), on: $branchOnly)
                if branchOnly {
                    Text("Just this idea and what hangs under it is sent, with a picture of it alone. The board is not marked as sent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if kind == .note || kind == .project {
                HStack(spacing: 8) {
                    Text("Name")
                        .font(Txt.label)
                        .foregroundStyle(.secondary)
                    TextField("Name of the note", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("send.title")
                }
                if kind == .project, let line = ParagonExport.projectLine(board: subject) {
                    // What becomes a task and what stays a plain line, with the counts.
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("send.projectLine")
                } else if todoTasks > 0 {
                    Text(todoTasks == 1 ? "The 1 to-do box becomes a task in it." : "The \(todoTasks) to-do boxes become tasks in it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Inbox to-dos (and new tasks that must go to the Inbox) can say which board they come from.
            if kind == .todos || (kind == .add && adding?.notePath == nil) {
                SendSwitch(words: "Say where they come from", on: $sayOrigin, identifier: "send.sayOrigin")
            }
            if subject.isTimeline {
                SendSwitch(words: "Also remind me when a bar starts", on: $remindStarts, identifier: "send.remindStarts")
            }

            let made = gets
            ParagonGetsBox(rows: made.rows, picture: chosenActive ? subject : frameOnly && frame != nil ? (frame.flatMap { session.board.frameOnly($0.id, keepFrame: true) } ?? session.board) : (branchOnly ? nil : session.board),
                           countLine: ParagonExport.countLine(made.rows, inInbox: made.inInbox))

            if let sent = whole.sent, let news,
               let line = ParagonExport.cannotFollowLine(renamed: news.renamed, moved: news.moved, since: sent.when) {
                // What cannot follow is said, not hidden.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("send.cannotFollow")
                    if kind == .add {
                        Button("Send a fresh copy") { kind = SendKind(rawValue: sent.kind) ?? .note }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Part.paragon.text)
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("send.freshCopy")
                    }
                }
            }

            if let sent = whole.sent {
                HStack(spacing: 8) {
                    Text("Last sent \(Self.day.string(from: sent.when)) as a \(sent.kind): “\(sent.title)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open in PARAGON") { model.openInParagon(sent) }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Part.paragon.text)
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("send.openLast")
                }
            }

            Text(kind == .add
                 ? "Seedboard only hands PARAGON the new lines. PARAGON puts them at the end of the tasks itself; Seedboard never changes a note you already have."
                 : "Seedboard only adds something new. It never changes a note you already have; sending again makes a second note.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let problem {
                Text(problem)
                    .font(Txt.label)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("send.problem")
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("send.cancel")
                Button { send() } label: { SendLabel(busy: busy, done: done) }
                    .buttonStyle(FilledButton(.paragon))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSend && !done)
                    .accessibilityIdentifier("send.send")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .onAppear {
            title = ParagonExport.noteTitle(for: session.board.title)
            // 0.9: with one frame chosen, only that frame is sent (the switch is on) and its words are the name.
            if let frame, !LaunchOptions.arguments.contains("-frameOff") {
                frameOnly = true
                let name = session.board.frameName(frame.id)
                if !name.isEmpty { title = ParagonExport.noteTitle(for: name) }
            }
            if session.board.mapCentres.isEmpty, waiting > 0, session.board.items.allSatisfy({ $0.todo }) { kind = .todos }
            // For pictures: `-sendAs note|project|todos` chooses the row, `-branchOnly` switches the branch switch on.
            if let word = LaunchOptions.value(for: "-sendAs"), let wanted = SendKind(rawValue: word) { kind = wanted }
            if LaunchOptions.arguments.contains("-branchOnly"), branch != nil { branchOnly = true }
            if LaunchOptions.arguments.contains("-starts") { remindStarts = true }
        }
        .task {
            // A look at the note the board became (reading only), so the page can offer "Add what is new" and
            // say where the tasks go. With it known, that row is the one chosen.
            if let sample = SendSample.look {
                look = sample
            } else if let sent = session.board.sent, let place = model.place {
                look = await Task.detached(priority: .userInitiated) { ParagonGate.look(at: sent, in: place) }.value
            }
            if adding != nil, LaunchOptions.value(for: "-sendAs") == nil, !partOnly { kind = .add }
        }
        .onChange(of: frameOnly) { _, on in
            if on, kind == .add { kind = .note }
            let whole = ParagonExport.noteTitle(for: session.board.title)
            let part = frame.map { ParagonExport.noteTitle(for: session.board.frameName($0.id).isEmpty ? session.board.title : session.board.frameName($0.id)) } ?? whole
            if title.isEmpty || title == (on ? whole : part) { title = on ? part : whole }
        }
        .onChange(of: chosenOnly) { _, on in
            // Chosen things are a small board of their own: nothing is added to the note the whole board became,
            // and they go as a note or as to-dos, not as a project.
            if on, kind == .add || kind == .project { kind = .note }
        }
        .onChange(of: branchOnly) { _, on in
            // A branch is a small map of its own: nothing is added to the note the whole board became.
            if on, kind == .add { kind = .note }
            // The name follows the switch, unless the owner has typed a name of their own.
            let whole = ParagonExport.noteTitle(for: session.board.title)
            let part = branch.map { ParagonExport.noteTitle(for: session.board.branchName($0.id)) } ?? whole
            if title.isEmpty || title == (on ? whole : part) { title = on ? part : whole }
        }
    }

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private func choice(_ value: SendKind, _ name: String, _ words: String) -> some View {
        let on = kind == value
        return Button { kind = value } label: {
            HStack(alignment: .top, spacing: 9) {
                ControlMarkView(on ? .ticked : .circle, size: 20, colour: on ? Part.paragon.text : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.body.weight(.semibold))
                    Text(words)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(on ? Part.paragon.soft : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(on ? Part.paragon.text : Color.primary.opacity(0.12), lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(corner: 10))
        .accessibilityIdentifier("send.kind.\(value.rawValue)")
    }

    private func send() {
        guard !done else { return }
        busy = true
        problem = nil
        Task {
            let failure = await model.send(kind: kind, title: title, branch: branchOnly ? branch?.id : nil,
                                             frame: frameOnly ? frame?.id : nil,
                                             chosen: chosenActive ? session.selection : nil, choices: choices)
            busy = false
            if let failure {
                problem = failure
                Feel.notSent()
            } else {
                // 0.5: felt and seen — a white tick on the button for 0.45 s, then the page closes.
                Feel.sent()
                if !Feel.still {
                    done = true
                    try? await Task.sleep(nanoseconds: UInt64(FeelRules.sendTick * 1_000_000_000))
                }
                dismiss()
            }
        }
    }
}

#if !os(macOS)
/// On the iPad a page is a card in the middle of the screen: it is made just as tall as what is in it.
private struct FittedPage: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.form.fitted(horizontal: false, vertical: true))
        } else {
            content
        }
    }
}
#endif
