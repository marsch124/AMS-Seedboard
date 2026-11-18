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

    private var waiting: Int { ParagonExport.inboxTasks(board: session.board).count }
    private var todoCount: Int { session.board.items.filter(\.todo).count }

    private var canSend: Bool {
        guard model.paragonReady, !busy, !session.readOnly else { return false }
        if kind == .todos { return waiting > 0 && model.place?.outbox != nil }
        return !session.board.isEmpty
    }

    var body: some View {
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
                   session.board.isTimeline
                   ? "The timeline's picture and its bars with their dates. It goes to Resources, and one line in the Inbox points to it."
                   : "The board's picture and its words as a tidy outline. It goes to Resources, and one line in the Inbox points to it.")
            choice(.project, "As a project",
                   session.board.isTimeline
                   ? "The phases become headings, the bars become tasks with their start and due day. It goes to Projects."
                   : "The branches become headings, the ideas under them become tasks. It goes to Projects.")
            choice(.todos, "Only the to-do boxes",
                   waiting == 0 ? "No to-do boxes are waiting. Choose a box and press To do first."
                   : (waiting == 1 ? "1 to-do box goes to the Inbox as a task." : "\(waiting) to-do boxes go to the Inbox as tasks."))

            if kind != .todos {
                HStack(spacing: 8) {
                    Text("Name")
                        .font(Txt.label)
                        .foregroundStyle(.secondary)
                    TextField("Name of the note", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("send.title")
                }
                if todoCount > 0 {
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
        #if os(macOS)
        .frame(width: 470)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        #endif
        .onAppear {
            title = ParagonExport.noteTitle(for: session.board.title)
            if session.board.mapCentres.isEmpty, waiting > 0, session.board.items.allSatisfy({ $0.todo }) { kind = .todos }
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
            let failure = await model.send(kind: kind, title: title)
            busy = false
            if let failure {
                problem = failure
            } else {
                dismiss()
            }
        }
    }
}
