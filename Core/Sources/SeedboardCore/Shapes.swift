import Foundation
import CoreGraphics

// How a flow shape takes its size from its words, and what changing its kind does to it.

public enum ShapeFit {
    /// The widest a shape grows by itself. Wider is the owner's doing.
    public static func widest(_ kind: ItemKind) -> Double {
        switch kind {
        case .diamond: return 340
        case .oval: return 320
        case .person: return 220
        case .slanted: return 330
        default: return 300
        }
    }

    /// The width the words may take inside something this wide.
    public static func wordsWidth(_ kind: ItemKind, w: Double) -> Double {
        switch kind {
        case .diamond: return max(w * 0.56, 50)
        case .oval: return max(w * 0.72, 50)
        case .note, .frame: return max(w - 20, 50)
        case .person, .document, .slanted, .store: return max(Double(ShapeOutline.textBox(kind, CGRect(x: 0, y: 0, width: w, height: 400)).width), 50)
        default: return max(w - 24, 50)
        }
    }

    /// The height a shape needs for words this high.
    public static func height(_ kind: ItemKind, words: Double) -> Double {
        switch kind {
        case .diamond: return words * 2 + 20
        case .oval: return words * 1.4 + 16
        case .person, .document, .slanted, .store: return ShapeOutline.height(kind, words: words)
        default: return words + 22
        }
    }

    /// The size a shape takes so its words fit. It never shrinks. With `widen` (the words are being
    /// typed, or the kind was just changed) it grows wider first — just as wide as is needed, up to
    /// `widest` — and only then taller. Without it the width is the owner's and only the height grows.
    /// `wordsHeight` says how high the words are when they may be this wide.
    public static func size(_ kind: ItemKind, w: Double, h: Double, widen: Bool, wordsHeight: (Double) -> Double) -> (w: Double, h: Double) {
        func need(_ width: Double) -> Double { height(kind, words: wordsHeight(wordsWidth(kind, w: width))) }
        var width = w
        let most = widest(kind)
        if widen, kind.isShape, w < most, need(w) > h {
            if need(most) > h {
                width = most
            } else {
                var low = w, high = most
                while high - low > 2 {
                    let mid = (low + high) / 2
                    if need(mid) <= h { high = mid } else { low = mid }
                }
                width = high.rounded(.up)
            }
        }
        return (width, max(h, need(width)))
    }
}

public extension Board {
    /// Changes the kind of a flow shape. The middle, the words and the colour stay, and so does the
    /// size the owner gave it; only a shape still at its kind's own size takes the new kind's own size.
    mutating func setKind(_ id: UUID, to kind: ItemKind) {
        guard let i = index(of: id), items[i].kind.isShape, kind.isShape, items[i].kind != kind else { return }
        let centre = items[i].centre
        let own = items[i].kind.defaultSize
        let untouched = items[i].w == Double(own.width) && items[i].h == Double(own.height)
        items[i].kind = kind
        if untouched {
            items[i].w = Double(kind.defaultSize.width)
            items[i].h = Double(kind.defaultSize.height)
            items[i].x = Double(centre.x) - items[i].w / 2
            items[i].y = Double(centre.y) - items[i].h / 2
        }
    }
}
