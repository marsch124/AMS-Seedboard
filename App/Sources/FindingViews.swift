import SwiftUI
import Vision
import SeedboardCore

// 0.9, lane "finding": the Put away page and row, the Undo list page, and the quiet reading of the words
// inside pictures. The rules are in SeedboardCore (Finding09.swift).

// MARK: Put away

/// "Put away (3)" at the bottom of the list: a quiet row that opens the page of boards put away.
struct PutAwayRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let words = PutAway.rowWords(model.boards) {
            Button { model.showPutAway = true } label: {
                Text(words)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .padding(.top, 10)
            .accessibilityIdentifier("boards.putAway")
        }
    }
}

/// The page of boards that were put away, the one put away last first. "Bring back" is one press.
struct PutAwayPage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let open: (UUID) -> Void

    var body: some View {
        let paint = Paint(scheme)
        let boards = model.putAwayBoards
        return VStack(spacing: 0) {
            ZStack {
                Text("Put away")
                    .font(Txt.big)
                    .foregroundStyle(Part.boards.text)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(FilledButton(.boards))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("putAway.done")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            if boards.isEmpty {
                Text("Nothing is put away.")
                    .font(Txt.label)
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .accessibilityIdentifier("putAway.empty")
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(boards) { board in
                            HStack(spacing: 8) {
                                Circle().fill(paint.line(board.colour)).frame(width: 9, height: 9)
                                Button { dismiss(); open(board.id) } label: {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(board.title).font(.body).lineLimit(1)
                                        Text("Put away \(Board.ago(from: board.putAway ?? board.changed, to: Date())) · \(board.listLine(doneThings: EchoKeeper.shared.doneThings(board)))")
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PressStyle())
                                Button("Bring back") { model.unputAway(board.id) }
                                    .buttonStyle(FilledButton(.boards))
                                    .accessibilityIdentifier("putAway.bringBack.\(board.title)")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .accessibilityIdentifier("putAway.row.\(board.title)")
                        }
                    }
                }
            }
        }
        .background(paint.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("putAway.page")
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 340)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }
}

/// What a list row or card adds after the board's line when a search found it: "put away", "in a picture".
enum FoundMarks {
    static func words(_ board: Board, search: String) -> String {
        var marks: [String] = []
        if board.isPutAway { marks.append("put away") }
        if BoardSearch.way(search, board: board) == .picture { marks.append("in a picture") }
        return marks.isEmpty ? "" : " · " + marks.joined(separator: " · ")
    }
}

extension EchoKeeper {
    /// The things PARAGON's note says are done (read back on this device), for the line under a board.
    func doneThings(_ board: Board) -> Set<UUID> {
        guard let echo = echo(of: board), echo.standing == .found else { return [] }
        return Set(echo.reading.states.filter { $0.value == .done }.map(\.key))
    }
}

// MARK: Undo list

/// "Undo list": the last steps, newest first, each with a plain name and its time. A press on a step goes back
/// to just before it (all of it can be done again with Redo).
struct UndoListPage: View {
    @ObservedObject var session: BoardSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let steps = session.undoSteps()
        return VStack(spacing: 0) {
            ZStack {
                Text("Undo list")
                    .font(Txt.big)
                    .foregroundStyle(Part.arrows.text)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(FilledButton(.arrows))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("undoList.done")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            if steps.isEmpty {
                Text("Nothing to undo yet.")
                    .font(Txt.label)
                    .foregroundStyle(.secondary)
                    .padding(20)
                Spacer(minLength: 0)
            } else {
                Text("Press a step to go back to just before it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                if session.undoLetGo {
                    Text(UndoBudget.words)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier("undoList.letGo")
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            Button {
                                session.undo(steps: step.undos)
                                dismiss()
                            } label: {
                                Text(StepWords.line(step.words, at: step.time))
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("undoList.step.\(index)")
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .background(Paint(scheme).canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("undo.list")
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }
}

// MARK: Words inside pictures

/// Reads the words inside a board's pictures once, for the search: gently, a picture at a time, off the main
/// thread, never while the owner is typing or dragging. Done when a board is opened — saving the board is the
/// normal path, and every save marks the board as changed, so only an opened board is filled.
@MainActor
final class PictureWordsReader {
    static let shared = PictureWordsReader()
    private var reading: UUID?

    func start(_ session: BoardSession) {
        guard !LaunchOptions.sampleData, !session.starterDraft, !session.readOnly,
              reading == nil, !session.board.picturesToRead.isEmpty else { return }
        reading = session.board.id
        Task { [weak session] in
            // Let the board open and settle first.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            while let session, session.board.id == self.reading {
                guard !session.busy else {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }
                guard let item = session.board.picturesToRead.first(where: { !self.skipped.contains($0.id) }),
                      let name = item.picture else { break }
                let words = await Task.detached(priority: .utility) { PictureWordsReader.read(name) }.value
                guard let words else {
                    // The file is not on this device yet: tried again next time the board is opened.
                    self.skipped.insert(item.id)
                    continue
                }
                guard !session.busy else { continue }
                let id = item.id
                session.quietly { $0.setPictureWords(id, words) }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            self.skipped = []
            self.reading = nil
        }
    }

    private var skipped: Set<UUID> = []

    /// The words in the picture, or nil when the picture's file cannot be read here yet. "" = no words.
    nonisolated private static func read(_ name: String) -> String? {
        guard let image = PictureStore.shared.fullImage(name) else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil else { return "" }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: " ")
    }
}
