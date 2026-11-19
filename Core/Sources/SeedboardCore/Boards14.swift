import Foundation
import CoreGraphics

// 0.14, lane "boards": joining two boards (idea 20) and reading an OPML outline file (idea 24).

public enum BoardJoin {
    /// The gap between the chosen board's things and the things laid beside them.
    public static let gap: Double = 80

    /// True when `board` may be joined into: an ordinary board that can be changed, not put away.
    public static func canTakeIn(_ board: Board) -> Bool { board.canBeChanged && !board.placesItself }

    /// True when `board` may be the one that is joined in.
    public static func canJoinIn(_ board: Board) -> Bool { board.canBeChanged && !board.placesItself }

    /// The boards that can be chosen for "Join with…": ordinary boards that can be changed, not this one.
    public static func choices(for board: Board, in boards: [Board]) -> [Board] {
        boards.filter { $0.id != board.id && canTakeIn($0) && !$0.isPutAway }
    }

    /// The things and arrows of `joined` are laid to the RIGHT of everything on `target` (a gap between, the
    /// tops level). Arrows are kept; a thing whose identity is already on `target` gets a new one (and
    /// whatever points to it — arrows, a branch's parent — follows). Returns the changed target; `target`
    /// keeps its own name, colour and identity. A board that places itself on either side: nil.
    public static func join(_ joined: Board, into target: Board) -> Board? {
        guard canTakeIn(target), canJoinIn(joined) else { return nil }
        var out = target
        let taken = Set(target.items.map(\.id))
        var renamed: [UUID: UUID] = [:]
        for item in joined.items where taken.contains(item.id) { renamed[item.id] = UUID() }
        func fresh(_ id: UUID) -> UUID { renamed[id] ?? id }

        let there = target.bounds
        let here = joined.bounds
        let dx = (there.map { Double($0.maxX) + gap } ?? 0) - Double(here?.minX ?? 0)
        let dy = (there.map { Double($0.minY) } ?? 0) - Double(here?.minY ?? 0)

        for var item in joined.items {
            item.id = fresh(item.id)
            if let p = item.parent { item.parent = fresh(p) }
            if let f = item.from { item.from = fresh(f) }
            if let t = item.to { item.to = fresh(t) }
            item.x += dx
            item.y += dy
            out.items.append(item)
        }
        let linkIDs = Set(target.links.map(\.id))
        for var link in joined.links {
            link.from = fresh(link.from)
            link.to = fresh(link.to)
            if linkIDs.contains(link.id) { link.id = UUID() }
            out.links.append(link)
        }
        out.sentTodos += joined.sentTodos.map(fresh)
        out.sentTasks += joined.sentTasks.map { SentTask(id: fresh($0.id), words: $0.words, place: $0.place) }
        // Names of lanes etc. are in the things; the legend of the chosen board wins, the other's fills the gaps.
        if let legend = joined.legend {
            var merged = legend
            for (k, v) in target.legend ?? [:] { merged[k] = v }
            out.legend = merged
        }
        out.touch()
        return out
    }

    /// The line shown after a join.
    public static func line(joinedTitle: String) -> String { "“\(joinedTitle)” was joined in. It is under Put away." }
}

public enum OpmlOutline {
    /// Reads an OPML file: the outline elements nest as they do in the file; the text is the `text` attribute
    /// (or `title`). Returns the nodes and the document's title (`<title>` in the head), if any.
    public static func parse(_ data: Data) -> (nodes: [OutlineNode], title: String?) {
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return (reader.top, reader.title)
    }

    private final class Reader: NSObject, XMLParserDelegate {
        var top: [OutlineNode] = []
        var title: String?
        private var stack: [OutlineNode] = []
        private var inHead = false
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String] = [:]) {
            switch name.lowercased() {
            case "head": inHead = true
            case "title": text = ""
            case "outline":
                let words = (attributes["text"] ?? attributes["title"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                stack.append(OutlineNode(words))
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            switch name.lowercased() {
            case "head": inHead = false
            case "title":
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if inHead, !t.isEmpty { title = t }
            case "outline":
                guard let done = stack.popLast() else { return }
                if done.text.isEmpty && done.children.isEmpty { return }
                if stack.isEmpty { top.append(done) } else { stack[stack.count - 1].children.append(done) }
            default: break
            }
        }
    }

    /// The outline and the title for a file: OPML by its extension or its first characters, otherwise Markdown or
    /// plain text. `name` is the file's name without its ending. The title is the file's name; for a file
    /// without a usable name, its first heading (Markdown) or its `<title>` (OPML).
    public static func read(_ data: Data, fileName name: String, ext: String) -> (nodes: [OutlineNode], title: String)? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if ext.lowercased() == "opml" {
            let r = parse(data)
            guard !r.nodes.isEmpty else { return nil }
            return (r.nodes, !clean.isEmpty ? clean : (r.title ?? "Outline"))
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return nil }
        let nodes = Outline.parse(text)
        guard !nodes.isEmpty else { return nil }
        return (nodes, !clean.isEmpty ? clean : (nodes.first?.text ?? "Outline"))
    }
}
