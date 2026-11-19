import Foundation

// 0.11, pick 28: a box ticked on a board ticks its task in PARAGON.
// Seedboard still only ADDS to PARAGON's waiting list (`capture-outbox.jsonl`); it never opens or changes a PARAGON
// file. The line has no `id` and no `text`, so a PARAGON older than build 341 cannot read it and skips it (it is
// never filed as a new Inbox task); build 341 ticks the ONE open task with exactly those words.

public extension ParagonExport {
    /// One "this was ticked on the board" line of the waiting list.
    struct DoneLine: Codable, Equatable, Sendable {
        public var kind = "seedboardDone"
        /// The task's words exactly as they were sent (`SentTask.words`).
        public var words: String
        /// The board's title, for PARAGON's log only.
        public var board: String
        /// `SentTask.inbox` or `SentTask.note`.
        public var place: String
        /// For `note`: the note's place in PARAGON's folder, e.g. "Projects/Summer cabin.md".
        public var path: String?
        public var when: Date

        public init(words: String, board: String, place: String, path: String? = nil, when: Date) {
            self.words = words
            self.board = board
            self.place = place
            self.path = path
            self.when = when
        }
    }

    /// The lines as they go into the file: JSON, one per line, dates as ISO 8601 (like `waitingData`).
    static func doneData(_ lines: [DoneLine]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = Data()
        for line in lines {
            data.append(try encoder.encode(line))
            data.append(0x0A)
        }
        return data
    }
}

public extension Board {
    /// The things that were not done in `old` and are done now (a bar or milestone marked done) AND became a
    /// PARAGON task (`sentTasks`, with their words): one line each. Unticking gives none. A thing that never
    /// went to PARAGON gives none. A task that went into a note needs that note's place (`sent`); without it
    /// there is nothing PARAGON could find, so no line.
    func doneLines(since old: Board, now: Date) -> [ParagonExport.DoneLine] {
        var out: [ParagonExport.DoneLine] = []
        for item in items where item.isDone {
            guard old.item(item.id)?.isDone != true, let task = sentTask(item.id) else { continue }
            let words = task.words.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty else { continue }
            if task.place == SentTask.note {
                guard let path = sent?.path, !path.isEmpty else { continue }
                out.append(ParagonExport.DoneLine(words: words, board: title, place: task.place, path: path, when: now))
            } else {
                out.append(ParagonExport.DoneLine(words: words, board: title, place: task.place, when: now))
            }
        }
        return out
    }
}
