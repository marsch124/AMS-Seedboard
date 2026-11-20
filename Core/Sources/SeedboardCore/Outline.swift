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

    /// True when the text is a list (0.5): two lines or more that are not empty, and either one of them begins
    /// like a list (a list mark, a number, a tick box, a heading mark or an indent) or every line is short
    /// (80 letters at most). Paragraphs are not a list: they stay one text.
    public static func isList(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return false }
        if lines.contains(where: beginsLikeAList) { return true }
        return lines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).count <= shortLine }
    }

    /// The longest line that still counts as a short one.
    public static let shortLine = 80

    /// True when the text has at least two lines that are not empty (what counted as a list up to 0.4; still the
    /// rule for "Paste a list as a mind map", which always makes a map).
    public static func hasSeveralLines(_ text: String) -> Bool {
        text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
    }

    /// The kind of the one thing words become when they are no list: several lines are one Text with its
    /// lines kept, one line is a sticky note.
    public static func kindForWords(_ text: String) -> ItemKind { hasSeveralLines(text) ? .text : .note }

    /// The line begins like a line of a list: with an indent (a tab, or two spaces or more), a heading mark,
    /// a list mark, a number or a tick box.
    static func beginsLikeAList(_ line: String) -> Bool {
        if line.hasPrefix("\t") || line.hasPrefix("  ") { return true }
        let body = line.trimmingCharacters(in: .whitespaces)
        if heading(in: body) != nil { return true }
        if body.range(of: #"^\[[ xX]\](\s+|$)"#, options: .regularExpression) != nil { return true }
        return body.range(of: #"^([-*+•–◦]|\d+[.)]|[A-Za-z]\))\s+"#, options: .regularExpression) != nil
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

        // 0.19: a board that numbers its branches copies them with their numbers ("2. Food"), as on the board.
        let numbers = branchNumbers()
        let maps = mapCentres.map { centre -> String in
            var node = outline(of: centre.id)
            for (n, kid) in children(of: centre.id).enumerated() {
                if let number = numbers[kid.id], node.children.indices.contains(n) { node.children[n].text = "\(number). " + node.children[n].text }
            }
            return Outline.text([node])
        }
        if !maps.isEmpty { sections.append(maps.joined(separator: "\n")) }

        let arrows = links.compactMap { link -> String? in
            guard let a = item(link.from), let b = item(link.to) else { return nil }
            func name(_ i: Item) -> String { i.kind == .picture ? ParagonExport.pictureName(of: i) : one(i.text) }
            var line = "\(name(a)) → \(name(b))"
            let words = link.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !words.isEmpty { line += " (\(one(words)))" }
            return line
        }
        if !arrows.isEmpty { sections.append((["Flow:"] + arrows).joined(separator: "\n")) }

        // A named frame is a heading: "Pros:" with the things in it; what lies in no such frame stands under "Notes:".
        // Both in reading order (SendFrames.swift).
        let notes = ParagonExport.framed(self) { $0.kind == .note || $0.kind == .text || $0.kind == .picture || ($0.kind == .table && !TableRules.words($0.cells).isEmpty) }
        func noteLine(_ i: Item) -> String {
            if i.kind == .note, TickList.hasTicks(i.text) { return TickList.bullets(i.text).joined(separator: "\n") }
            if i.kind == .table { return TableRules.lines(i.cells).joined(separator: "\n") }   // 0.14
            return "- " + (i.kind == .picture ? ParagonExport.pictureName(of: i) : one(i.text))
        }
        if !notes.loose.isEmpty { sections.append((["Notes:"] + notes.loose.map(noteLine)).joined(separator: "\n")) }
        for group in notes.groups { sections.append(([group.name + ":"] + group.things.map(noteLine)).joined(separator: "\n")) }

        let joined = Set(links.flatMap { [$0.from, $0.to] })
        let loose = items.filter { $0.kind.isShape && !joined.contains($0.id) }.map { "- " + one($0.text) }
        if !loose.isEmpty { sections.append((["Shapes:"] + loose).joined(separator: "\n")) }

        // 0.5: the boards this one has doors to, by name.
        let doorNames = doors.map { "- " + one($0.text) }
        if !doorNames.isEmpty { sections.append((["Doors:"] + doorNames).joined(separator: "\n")) }

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
