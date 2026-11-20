import Foundation
import CoreGraphics

// 0.19 (picks 40 and 42): a picture cut round, and a picture in a print frame. Both are only how the
// picture is SHOWN (Item.cropShape "circle", Item.printFrame true; the file is never touched), so both
// can be taken back, and one Undo takes either back.

public extension Item {
    /// The picture is shown cut round (a circle, or an oval when its box is not square).
    var isRound: Bool { kind == .picture && cropShape == "circle" }
    /// The picture is shown in a print frame.
    var isFramed: Bool { kind == .picture && printFrame == true }

    /// The white border of a print frame: 4 % of the shorter side, at least 6 points.
    static func printBorder(width: Double, height: Double) -> Double { max(6, min(width, height) * 0.04) }
    var printBorder: Double { isFramed ? Item.printBorder(width: w, height: h) : 0 }
}

public extension Board {
    /// "Round" / "Square". Round: the picture is cut round, and a box that is not square is first
    /// cropped to a square round its middle (the crop part is made narrower on its longer side; the
    /// file and the picture's scale stay), so a face stays a circle. Square: the picture is a
    /// rectangle again (the box stays as it is; Crop gives the rest back). Refused: not a picture,
    /// a board that cannot be changed, or a crop that would be left too small (< 0.05 of the picture).
    @discardableResult
    mutating func setPictureRound(_ id: UUID, _ round: Bool) -> Bool {
        guard canBeChanged, let i = index(of: id), items[i].kind == .picture else { return false }
        if round == items[i].isRound { return true }
        if round {
            let w = items[i].w, h = items[i].h
            if abs(w - h) > 0.5, w > 0, h > 0 {
                let part = items[i].shownPart
                var new = part
                if w > h {
                    new[2] = part[2] * h / w
                    new[0] = part[0] + (part[2] - new[2]) / 2
                } else {
                    new[3] = part[3] * w / h
                    new[1] = part[1] + (part[3] - new[3]) / 2
                }
                guard cropPicture(id, to: new) else { return false }
            }
            items[i].cropShape = "circle"
        } else {
            items[i].cropShape = nil
        }
        return true
    }

    /// "Print Frame": on or off.
    @discardableResult
    mutating func setPrintFrame(_ id: UUID, _ on: Bool) -> Bool {
        guard canBeChanged, let i = index(of: id), items[i].kind == .picture else { return false }
        items[i].printFrame = on ? true : nil
        return true
    }
}
