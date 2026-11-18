import Foundation
import CoreGraphics

// Pictures on a board (0.3). The picture itself is a file of its own (the app's Pictures folder), written once
// and never changed; the item only names it (`Item.picture`) and keeps its place and size. These are the rules.

public extension Board {
    /// The longest side a picture is first laid at, in board points.
    static let pictureLongest: Double = 320
    /// A picture laid small (an icon, a tiny photo) is made at least this long on its longest side.
    static let pictureShortest: Double = 120

    /// The size a picture of these pixels is laid at: its shape kept, at most 320 × 320 points, and not tiny.
    static func pictureSize(forPixels pixels: CGSize) -> CGSize {
        guard pixels.width > 0, pixels.height > 0 else { return ItemKind.picture.defaultSize }
        let long = Double(max(pixels.width, pixels.height))
        let target = min(Board.pictureLongest, max(long, Board.pictureShortest))
        let k = target / long
        return CGSize(width: (Double(pixels.width) * k).rounded(), height: (Double(pixels.height) * k).rounded())
    }

    /// Lays a picture (the name of its file and its size in pixels) with its middle at the point.
    /// Refused (nil) on a timeline and on a "Who does what" board, on a board this version may not change,
    /// and for a name that is not a plain file name.
    @discardableResult
    mutating func addPicture(name: String, pixelSize: CGSize, centre: CGPoint) -> UUID? {
        guard canBeChanged, !placesItself, PictureKeeping.isPlainName(name) else { return nil }
        let size = Board.pictureSize(forPixels: pixelSize)
        var item = Item(kind: .picture)
        item.picture = name
        item.w = Double(size.width)
        item.h = Double(size.height)
        item.x = Double(centre.x) - item.w / 2
        item.y = Double(centre.y) - item.h / 2
        items.append(item)
        return item.id
    }

    /// A picture takes a new size by dragging a corner: it keeps its shape, the opposite corner stays where it is,
    /// and it never gets smaller than 44 × 28 points.
    mutating func scalePicture(_ id: UUID, to rect: CGRect) {
        guard let i = index(of: id), items[i].kind == .picture, items[i].w > 0, items[i].h > 0 else { return }
        let old = items[i].frame
        let r = rect.standardized
        var k = max(Double(r.width) / items[i].w, Double(r.height) / items[i].h)
        k = max(k, 44 / items[i].w, 28 / items[i].h)
        let w = items[i].w * k, h = items[i].h * k
        // The corner opposite the one that was dragged is the one that did not move.
        let anchorRight = abs(r.maxX - old.maxX) < abs(r.minX - old.minX)
        let anchorBottom = abs(r.maxY - old.maxY) < abs(r.minY - old.minY)
        items[i].x = anchorRight ? Double(old.maxX) - w : Double(old.minX)
        items[i].y = anchorBottom ? Double(old.maxY) - h : Double(old.minY)
        items[i].w = w
        items[i].h = h
    }

    /// Shows only a part of a picture (`part`: x, y, width, height, each 0 to 1 of the whole picture), or all of it (nil or
    /// the whole). The picture keeps its scale — a point of the picture covers as many board points as before — and the part
    /// that was shown stays exactly where it was on the board. The file is never touched, so a crop can always be changed
    /// or taken back. Refused (false) for something that is not a picture, a board this version may not change, and a part
    /// that is not four finite numbers, is smaller than 0.05 wide or high, or lies outside the picture.
    @discardableResult
    mutating func cropPicture(_ id: UUID, to part: [Double]?) -> Bool {
        guard canBeChanged, let i = index(of: id), items[i].kind == .picture, items[i].w > 0, items[i].h > 0 else { return false }
        let new: [Double]
        if let part {
            guard part.count == 4, part.allSatisfy(\.isFinite), part[0] >= -0.0001, part[1] >= -0.0001,
                  part[2] >= 0.05, part[3] >= 0.05, part[0] + part[2] <= 1.0001, part[1] + part[3] <= 1.0001 else { return false }
            let x = max(0, part[0]), y = max(0, part[1])
            new = [x, y, min(part[2], 1 - x), min(part[3], 1 - y)]
        } else {
            new = [0, 0, 1, 1]
        }
        let old = items[i].crop ?? [0, 0, 1, 1]
        // The whole picture as it lies on the board now.
        let wholeW = items[i].w / old[2], wholeH = items[i].h / old[3]
        items[i].x += (new[0] - old[0]) * wholeW
        items[i].y += (new[1] - old[1]) * wholeH
        items[i].w = new[2] * wholeW
        items[i].h = new[3] * wholeH
        items[i].crop = Item.cleanCrop(new)
        return true
    }

    /// The names of the picture files this board uses.
    var pictureNames: Set<String> { Set(items.compactMap { $0.kind == .picture ? $0.picture : nil }) }

    /// Pictures are on the board (for the count line).
    var pictureCount: Int { items.filter { $0.kind == .picture }.count }
}

/// Which picture files may go. A file is let go only when NO board names it — not the boards, not the removed
/// ones, not the safety copies or earlier versions — AND it is older than 30 days. In doubt, it stays.
public enum PictureKeeping {
    public static let keepDays: Double = 30

    /// A plain file name: letters, digits, dot, dash and underscore; no folder, no hidden file.
    public static func isPlainName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 100, !name.hasPrefix("."), !name.contains("..") else { return false }
        return name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }
    }

    /// A fresh name for a new picture file: `<UUID>.jpg`.
    public static func freshName(_ id: UUID = UUID()) -> String { id.uuidString + ".jpg" }

    /// The files to delete. `files`: each file in the Pictures folder with its date (nil when it could not be read).
    /// `named`: every name any board, removed board, safety copy or earlier version uses.
    /// `complete`: false when some kept copy could not be read — then nothing is deleted.
    public static func deletable(files: [(name: String, date: Date?)], named: Set<String>, now: Date = Date(), complete: Bool = true) -> [String] {
        guard complete else { return [] }
        let limit = now.addingTimeInterval(-keepDays * 86_400)
        return files.compactMap { file in
            guard isPlainName(file.name), !named.contains(file.name), let date = file.date, date < limit else { return nil }
            return file.name
        }
    }
}

// MARK: Crop and caption

public extension Item {
    /// The least a crop may show, as a part of the picture's width or height.
    static let cropLeast: Double = 0.05

    /// A stored crop made safe: not four finite numbers, or a part smaller than 0.05 wide or high, gives nil; a part that
    /// reaches outside the picture is cut back to the picture; the whole picture is nil.
    static func cleanCrop(_ raw: [Double]?) -> [Double]? {
        guard let raw, raw.count == 4, raw.allSatisfy(\.isFinite) else { return nil }
        let x = min(max(raw[0], 0), 1), y = min(max(raw[1], 0), 1)
        let w = min(raw[2], 1 - x), h = min(raw[3], 1 - y)
        guard w >= cropLeast, h >= cropLeast else { return nil }
        if x == 0, y == 0, w == 1, h == 1 { return nil }
        return [x, y, w, h]
    }

    /// The part of the picture that is shown (the whole picture when it is not cropped).
    var shownPart: [Double] { Item.cleanCrop(crop) ?? [0, 0, 1, 1] }

    /// The gap between a picture and its caption, and the height of one line of it (the caption is 12 points high).
    static let captionGap: Double = 6
    static let captionLine: Double = 15

    /// The words of a caption, trimmed; empty = no caption. Only a picture has one.
    var captionWords: String { kind == .picture ? text.trimmingCharacters(in: .whitespacesAndNewlines) : "" }

    /// How many lines the caption takes under a picture this wide: a careful guess (the screen wraps the real words), so
    /// the room kept for it is never too small.
    static func captionLines(_ words: String, width: Double) -> Int {
        let perLine = max(4, Int((width / 6.6).rounded(.down)))
        var lines = 0
        for paragraph in words.components(separatedBy: .newlines) {
            var used = 0
            var count = 1
            for word in paragraph.split(separator: " ") {
                let n = word.count
                if used == 0 { used = n } else if used + 1 + n <= perLine { used += 1 + n } else { count += 1; used = n }
                while used > perLine { count += 1; used -= perLine }
            }
            lines += count
        }
        return max(lines, 1)
    }

    /// The room of the caption under the picture: 6 points below it, as wide as the picture. nil without a caption.
    var captionFrame: CGRect? {
        let words = captionWords
        guard !words.isEmpty else { return nil }
        let lines = Item.captionLines(words, width: w)
        return CGRect(x: x, y: y + h + Item.captionGap, width: w, height: Double(lines) * Item.captionLine + 2)
    }

    /// The picture and its caption together: what it needs room for.
    var reach: CGRect { captionFrame.map { frame.union($0) } ?? frame }
}
