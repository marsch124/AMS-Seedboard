import Foundation
import CoreGraphics

// 0.11, pictures: the caption's room measured like the screen draws it (21), and a picture's found words
// as a note beside it (39).

public extension Item {
    /// How wide a line of caption is. The app installs the real measuring (the caption's own lettering) when it starts;
    /// until then (and in tests) a letter counts 6.6 points.
    nonisolated(unsafe) static var captionMeasure: (String) -> Double = { Double($0.count) * 6.6 }

    /// The caption broken into lines no wider than `width` (a word wider than that is cut where it must).
    /// The screen draws exactly these lines and the layout keeps room for exactly these lines.
    static func captionWrapped(_ words: String, width: Double) -> [String] {
        let wide = captionMeasure
        var out: [String] = []
        for paragraph in words.components(separatedBy: .newlines) {
            var line = ""
            for word in paragraph.split(separator: " ") {
                var piece = String(word)
                let tryLine = line.isEmpty ? piece : line + " " + piece
                if wide(tryLine) <= width || line.isEmpty && piece.count <= 1 { line = tryLine; continue }
                if !line.isEmpty { out.append(line); line = "" }
                while wide(piece) > width, piece.count > 1 {
                    var n = piece.count - 1
                    while n > 1, wide(String(piece.prefix(n))) > width { n -= 1 }
                    out.append(String(piece.prefix(n)))
                    piece = String(piece.dropFirst(n))
                }
                line = piece
            }
            out.append(line)
        }
        return out
    }

    /// The words found inside a picture, trimmed; empty = none (or not a picture).
    var foundWords: String { kind == .picture ? (pictureWords ?? "").trimmingCharacters(in: .whitespacesAndNewlines) : "" }
}

public extension Board {
    /// "Words to a note": a new sticky note to the right of the picture (and its caption) holding the words found in it.
    /// Refused (nil): not a picture, no words, a board that may not be changed or places things itself.
    @discardableResult
    mutating func noteWithPictureWords(_ id: UUID) -> UUID? {
        guard canBeChanged, !placesItself, let pic = item(id), pic.kind == .picture, !pic.foundWords.isEmpty else { return nil }
        let size = ItemKind.note.defaultSize
        let reach = pic.reach
        let note = add(.note, centre: CGPoint(x: reach.maxX + 24 + size.width / 2, y: pic.y + size.height / 2), text: pic.foundWords)
        return note
    }
}
