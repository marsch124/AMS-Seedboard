import Foundation

// 0.14: pictures made from other things — a PDF's pages, a photo's subject lifted out.

public enum PDFPages {
    /// The most pages one drop lays on the board ("All pages").
    public static let most = 20

    /// The longest side a page is drawn at, in pixels (like every picture).
    public static let longestSide = 2048

    /// How many pages are laid: page 1 only, or every page up to `most`.
    public static func counted(total: Int, all: Bool) -> Int {
        guard total > 0 else { return 0 }
        return all ? min(total, most) : 1
    }

    /// The question for a PDF with more than one page; nil for a one-page PDF (it needs no question).
    public static func question(pages: Int) -> String? { pages > 1 ? "This PDF has \(pages) pages" : nil }

    /// The line when "All pages" had to stop at `most`; nil when all of them fit.
    public static func cutLine(total: Int) -> String? {
        total > most ? "A PDF lays \(most) pages at most. The first \(most) of \(total) are here." : nil
    }

    /// The pixel size a page of `width` × `height` points is drawn at: its long side `longestSide`, never zero.
    public static func pixels(width: Double, height: Double) -> (width: Int, height: Int) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return (1, 1) }
        let k = Double(longestSide) / max(width, height)
        return (max(1, Int((width * k).rounded())), max(1, Int((height * k).rounded())))
    }

    /// True when the bytes start like a PDF ("%PDF" within the first 1024 bytes).
    public static func looksLikePDF(_ data: Data) -> Bool {
        data.prefix(1024).range(of: Data("%PDF".utf8)) != nil
    }
}

public enum LiftOut {
    /// What is said when no subject was found.
    public static let noSubject = "No subject found in this picture"

    /// Where the lifted picture's middle goes: just beside the old picture, to its right, a gap between them.
    public static func centre(besideX x: Double, y: Double, w: Double, h: Double, newWidth: Double) -> (x: Double, y: Double) {
        (x + w + 28 + newWidth / 2, y + h / 2)
    }
}
