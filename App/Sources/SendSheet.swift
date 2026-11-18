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
    /// Only the chosen idea and everything under it is sent.
    @State private var branchOnly = false

    /// The one chosen idea, when there is one: the page then offers to send just that branch.
    private var branch: Item? { session.branchToSend }
    /// What is sent: the whole board, or the chosen branch as a small map of its own.
    private var subject: Board {
        guard branchOnly, let branch, let part = session.board.branchOnly(branch.id) else { return session.board }
        return part
    }
    private var waiting: Int { ParagonExport.inboxTasks(board: subject).count }
    private var todoCount: Int { subject.items.filter(\.todo).count }

    private var canSend: Bool {
        guard model.paragonReady, !busy, !session.readOnly else { return false }
        if kind == .todos { return waiting > 0 && model.place?.outbox != nil }
        return !subject.isEmpty
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

            choice(.note, "As a note",
                   session.board.isSequence ? SequenceWords.sendNote :
                   session.board.isTimeline
                   ? "The timeline's picture and its bars with their dates. It goes to Resources, and one line in the Inbox points to it."
                   : "The board's picture and its words as a tidy outline. It goes to Resources, and one line in the Inbox points to it.")
            choice(.project, "As a project",
                   session.board.isSequence ? SequenceWords.sendProject :
                   session.board.isTimeline
                   ? "The phases become headings, the bars become tasks with their start and due day. It goes to Projects."
                   : "The branches become headings. The ideas you ticked To do become tasks; with nothing ticked, all of them do. It goes to Projects.")
            choice(.todos, "Only the to-do boxes",
                   waiting == 0 ? "No to-do boxes are waiting. Choose a box and press To do first."
                   : (waiting == 1 ? "1 to-do box goes to the Inbox as a task." : "\(waiting) to-do boxes go to the Inbox as tasks."))

            if let branch {
                BranchSwitch(words: session.branchSwitchWords(branch), on: $branchOnly)
                if branchOnly {
                    Text("Just this idea and what hangs under it is sent, with a picture of it alone. The board is not marked as sent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if kind != .todos {
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
                } else if todoCount > 0 {
                    Text(todoCount == 1 ? "The 1 to-do box becomes a task in it." : "The \(todoCount) to-do boxes become tasks in it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let sent = session.board.sent {
                HStack(spacing: 8) {
                    Text("Last sent \(Self.day.string(from: sent.when)) as a \(sent.kind): “\(sent.title)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open in PARAGON") { model.openInParagon(sent) }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Part.paragon.text)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("send.openLast")
                }
            }

            Text("Seedboard only adds something new. It never changes a note you already have; sending again makes a second note.")
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
                Button(busy ? "Sending…" : "Send") { send() }
                    .buttonStyle(FilledButton(.paragon))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSend)
                    .accessibilityIdentifier("send.send")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .onAppear {
            title = ParagonExport.noteTitle(for: session.board.title)
            if session.board.mapCentres.isEmpty, waiting > 0, session.board.items.allSatisfy({ $0.todo }) { kind = .todos }
            // For pictures: `-sendAs note|project|todos` chooses the row, `-branchOnly` switches the branch switch on.
            if let word = LaunchOptions.value(for: "-sendAs"), let wanted = SendKind(rawValue: word) { kind = wanted }
            if LaunchOptions.arguments.contains("-branchOnly"), branch != nil { branchOnly = true }
        }
        .onChange(of: branchOnly) { _, on in
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
        .buttonStyle(.plain)
        .accessibilityIdentifier("send.kind.\(value.rawValue)")
    }

    private func send() {
        busy = true
        problem = nil
        Task {
            let failure = await model.send(kind: kind, title: title, branch: branchOnly ? branch?.id : nil)
            busy = false
            if let failure {
                problem = failure
            } else {
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
