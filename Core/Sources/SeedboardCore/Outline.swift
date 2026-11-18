import Foundation
import CoreGraphics

// Lists in, lists out: a pasted list becomes a mind map, and a board can be copied as plain text.

public struct OutlineNode: Equatable, Sendable {
    public var text: String
    public var children: [OutlineNode]
    public init(_ text: String, _ children: [OutlineNode] = []) {
        self.text = text
        self.children = children
    }
}

public enum Outline {
    /// Reads a pasted list: one entry per line; depth from leading tabs or spaces (any consistent step;
    /// a tab counts as 4 spaces); bullets and numbers are stripped; check boxes are stripped; Markdown
    /// headings count as depth 0, 1, … with following bullet lines nested under the last heading;
    /// blank lines are ignored; text is trimmed.
    public static func parse(_ text: String) -> [OutlineNode] {
        var lines: [(depth: Int, text: String)] = []
        var indents: [Int] = []
        var headingDepth: Int?

        for raw in text.components(separatedBy: .newlines) {
            var indent = 0
            var rest = Substring(raw)
            while let c = rest.first, c == " " || c == "\t" {
                indent += c == "\t" ? 4 : 1
                rest = rest.dropFirst()
            }
            let body = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
            if body.isEmpty { continue }

            if let heading = heading(in: body) {
                headingDepth = heading.level - 1
                indents = []
                if !heading.text.isEmpty { lines.append((heading.level - 1, heading.text)) }
                continue
            }

            let clean = stripMarkers(body)
            if clean.isEmpty { continue }
            while let last = indents.last, last > indent { indents.removeLast() }
            if indents.last != indent { indents.append(indent) }
            let relative = indents.count - 1
            lines.append((headingDepth.map { $0 + 1 + relative } ?? relative, clean))
        }

        // A line may go at most one step deeper than the one before it.
        var previous = -1
        for n in lines.indices {
            lines[n].depth = min(lines[n].depth, previous + 1)
            previous = lines[n].depth
        }

        var at = 0
        func read(depth: Int) -> [OutlineNode] {
            var found: [OutlineNode] = []
            while at < lines.count, lines[at].depth >= depth {
                let text = lines[at].text
                at += 1
                found.append(OutlineNode(text, read(depth: depth + 1)))
            }
            return found
        }
        return read(depth: 0)
    }

    /// True when the text has at least two non-blank lines.
    public static func isList(_ text: String) -> Bool {
        text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
    }

    /// Nested "- " bullets, two spaces per depth.
    public static func text(_ nodes: [OutlineNode]) -> String {
        var out: [String] = []
        func walk(_ list: [OutlineNode], _ depth: Int) {
            for node in list {
                out.append(String(repeating: "  ", count: depth) + "- " + node.text)
                walk(node.children, depth + 1)
            }
        }
        walk(nodes, 0)
        return out.joined(separator: "\n")
    }

    // MARK: Pieces

    private static func heading(in body: String) -> (level: Int, text: String)? {
        let hashes = body.prefix { $0 == "#" }.count
        guard hashes > 0, hashes <= 6 else { return nil }
        let after = body.dropFirst(hashes)
        guard after.isEmpty || after.first == " " || after.first == "\t" else { return nil }
        return (hashes, after.trimmingCharacters(in: .whitespaces))
    }

    private static func stripMarkers(_ body: String) -> String {
        if body.count == 1, "-*+•–◦".contains(body) { return "" }
        guard let marker = body.range(of: #"^([-*+•–◦]|\d+[.)]|[A-Za-z]\))\s+"#, options: .regularExpression) else { return body }
        var rest = String(body[marker.upperBound...]).trimmingCharacters(in: .whitespaces)
        if let box = rest.range(of: #"^\[[ xX]\](\s+|$)"#, options: .regularExpression) {
            rest = String(rest[box.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return rest
    }
}

public extension Board {
    /// A rough size for a new idea, until the app measures the words.
    internal static func roughSize(for text: String, centre: Bool = false) -> CGSize {
        let characters = text.components(separatedBy: .newlines).map(\.count).max() ?? 0
        let width = min(260, max(60, 8.2 * Double(characters) + 16))
        return centre ? CGSize(width: width + 24, height: 46) : CGSize(width: width, height: 30)
    }

    /// A new mind map from an outline. One top node → it is the centre. Several → the centre says
    /// `title` (or "Ideas") and the top nodes are its main branches. Both sides when there are more
    /// than 4 main branches. Returns the centre.
    @discardableResult
    mutating func addMap(from nodes: [OutlineNode], title: String?, at point: CGPoint) -> UUID {
        let centreText: String
        let tops: [OutlineNode]
        if nodes.count == 1 {
            centreText = nodes[0].text
            tops = nodes[0].children
        } else {
            let t = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            centreText = t.isEmpty ? "Ideas" : t
            tops = nodes
        }
        let centre = addCentre(at: point, text: centreText)
        if let i = index(of: centre) {
            let size = Board.roughSize(for: centreText, centre: true)
            items[i].w = Double(size.width)
            items[i].h = Double(size.height)
            items[i].x = Double(point.x) - items[i].w / 2
            items[i].y = Double(point.y) - items[i].h / 2
        }
        for node in tops { addOutlineIdea(node, under: centre) }
        if let i = index(of: centre) { items[i].bothSides = children(of: centre).count > 4 }
        layoutMaps()
        return centre
    }

    /// Hangs an outline under an existing idea. Returns the new top ideas.
    @discardableResult
    mutating func addIdeas(from nodes: [OutlineNode], under id: UUID) -> [UUID] {
        let made = nodes.compactMap { addOutlineIdea($0, under: id) }
        layoutMaps()
        return made
    }

    /// One map as an outline (folded branches included).
    func outline(of centre: UUID) -> OutlineNode {
        // An idea with several lines is one line in a list.
        OutlineNode(ParagonExport.oneLine(item(centre)?.text ?? ""), children(of: centre).map { outline(of: $0.id) })
    }

    /// The whole board as plain text to copy.
    var outlineText: String {
        if isTimeline { return timelineText }
        if isSequence { return sequenceText }
        func one(_ s: String) -> String {
            let parts = s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return parts.isEmpty ? "(empty)" : parts.joined(separator: " ")
        }
        var sections: [String] = []

        let maps = mapCentres.map { Outline.text([outline(of: $0.id)]) }
        if !maps.isEmpty { sections.append(maps.joined(separator: "\n")) }

        let arrows = links.compactMap { link -> String? in
            guard let a = item(link.from), let b = item(link.to) else { return nil }
            var line = "\(one(a.text)) → \(one(b.text))"
            let words = link.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !words.isEmpty { line += " (\(one(words)))" }
            return line
        }
        if !arrows.isEmpty { sections.append((["Flow:"] + arrows).joined(separator: "\n")) }

        let notes = items.filter { $0.kind == .note || $0.kind == .text }.map { "- " + one($0.text) }
        if !notes.isEmpty { sections.append((["Notes:"] + notes).joined(separator: "\n")) }

        let joined = Set(links.flatMap { [$0.from, $0.to] })
        let loose = items.filter { $0.kind.isShape && !joined.contains($0.id) }.map { "- " + one($0.text) }
        if !loose.isEmpty { sections.append((["Shapes:"] + loose).joined(separator: "\n")) }

        return sections.joined(separator: "\n\n")
    }

    @discardableResult
    private mutating func addOutlineIdea(_ node: OutlineNode, under parent: UUID) -> UUID? {
        guard let id = addChild(of: parent, text: node.text), let i = index(of: id) else { return nil }
        let size = Board.roughSize(for: node.text)
        items[i].w = Double(size.width)
        items[i].h = Double(size.height)
        for child in node.children { addOutlineIdea(child, under: id) }
        return id
    }
}
