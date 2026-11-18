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
