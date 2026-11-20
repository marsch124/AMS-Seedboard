import SwiftUI
import SeedboardCore
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

// 0.19 (lane "maps"): bent arrows (the middle knob), Number the Branches, Move to the Other Side, the Map Look
// choice (lines, curves, boxes) and "Grow Ideas from This". The rules are in Core (Maps19.swift).

/// Every SF Symbol this lane added, in one place so a name can be swapped after a look.
enum Marks19Maps {
    static let numberBranches = "list.number"
    static let growIdeas = "lightbulb"
    static let otherSide = "arrow.left.arrow.right"
    static let straighten = "line.diagonal"
    static let mapLook = "square.grid.2x2"
}

extension BoardSession {
    // MARK: Bent arrows (13)

    /// The chosen arrow whose middle knob lies under the point (board points).
    func linkKnob(at p: CGPoint) -> UUID? {
        guard !readOnly, editing == nil, !linking, let id = selectedLink else { return nil }
        return board.knobHit(of: id, at: p, reach: Route.knobReach / Double(scale)) ? id : nil
    }

    /// While the knob is dragged (after `liveStart`): the arrow runs through the point.
    func bendLive(_ id: UUID, through p: CGPoint) {
        live { $0.bendLink(id, to: p) }
    }

    /// "Straighten": the chosen (or given) arrow runs as the plain line again. One step for Undo.
    func straightenLink(_ id: UUID? = nil) {
        guard let id = id ?? selectedLink else { return }
        _ = change { $0.straightenLink(id) }
    }

    // MARK: Maps (21, 22, 24)

    /// "Number the Branches" on and off.
    func toggleNumberBranches() {
        guard !board.placesItself else { return }
        _ = change { $0.numberBranches = $0.numberBranches == true ? nil : true }
    }

    /// "Move to the Other Side" for the chosen main branch.
    func moveToOtherSide(_ id: UUID? = nil) {
        guard let id = id ?? single?.id else { return }
        if editing != nil { commitEdit() }
        _ = change { $0.moveToOtherSide(id) }
    }

    /// "Map Look": lines, curves or boxes.
    func setMapLook(_ look: MapLook) {
        guard !board.placesItself else { return }
        _ = change { $0.setMapLook(look) }
    }

    // MARK: Grow ideas (25)

    /// "Grow Ideas from This": three related words are worked out on this device and offered on a small plate.
    func growIdeas(from id: UUID) {
        guard !readOnly, let idea = board.item(id), idea.kind == .idea else { return }
        if editing != nil { commitEdit() }
        let words = idea.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        let desk = GrowDesk.shared
        let around = [board.item(idea.parent ?? id).map(\.text), idea.parent.flatMap { _ in board.item(board.centre(of: id))?.text }]
            .compactMap { $0 }.filter { !$0.isEmpty && $0 != words }
        let offer = GrowOffer(idea: id, words: words)
        desk.offer = offer
        let have = board.childWords(of: id)
        Task {
            let found = await GrowSuggester.suggest(for: words, around: around)
            let clean = GrowIdeas.clean(found, idea: words, children: have)
            await MainActor.run {
                guard desk.offer?.id == offer.id else { return }
                desk.offer?.chips = clean
                desk.offer?.waiting = false
            }
        }
    }

    /// One suggested word becomes an idea under the idea (last), one step for Undo.
    func addGrown(_ word: String, under id: UUID) {
        _ = change { $0.addIdeas([word], under: id) }
    }
}

// MARK: The plate

struct GrowOffer: Identifiable {
    let id = UUID()
    let idea: UUID
    /// The words of the idea the offer is for.
    let words: String
    var chips: [String] = []
    var waiting = true
    /// Some chip was added: Cancel reads Done.
    var added = false
}

@MainActor
final class GrowDesk: ObservableObject {
    static let shared = GrowDesk()
    @Published var offer: GrowOffer?
}

struct GrowHost: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = GrowDesk.shared

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { desk.offer != nil }, set: { if !$0 { desk.offer = nil } }),
                      onDismiss: { session.takeKeys() }) {
            GrowSheet(session: session)
        }
    }
}

struct GrowSheet: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = GrowDesk.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GlyphView(glyph: .symbol(Marks19Maps.growIdeas), size: 20, colour: Part.mindMap.text)
                Text("Grow Ideas from This")
                    .font(Txt.big)
                    .foregroundStyle(Part.mindMap.text)
                Spacer(minLength: 0)
            }
            if let offer = desk.offer {
                Text(offer.words)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if offer.waiting {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Thinking on this device…").font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("grow.waiting")
                } else if offer.chips.isEmpty {
                    Text(offer.added ? "That is all for this one." : "No suggestions for this one.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("grow.none")
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { chips(offer) }
                        VStack(alignment: .leading, spacing: 8) { chips(offer) }
                    }
                    Text("Press a word to add it as an idea under this one.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Button((desk.offer?.added ?? false) ? "Done" : "Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("grow.cancel")
                Spacer()
                if let offer = desk.offer, !offer.chips.isEmpty {
                    Button("Add All") { addAll(offer) }
                        .buttonStyle(FilledButton(.mindMap))
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("grow.addAll")
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 380)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(250)])
        #endif
    }

    @ViewBuilder private func chips(_ offer: GrowOffer) -> some View {
        ForEach(Array(offer.chips.enumerated()), id: \.element) { n, word in
            Button { add(word, offer) } label: {
                Text(word)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Part.mindMap.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Part.mindMap.text.opacity(0.12)))
                    .overlay(Capsule().stroke(Part.mindMap.text.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("grow.chip.\(n)")
        }
    }

    private func add(_ word: String, _ offer: GrowOffer) {
        session.addGrown(word, under: offer.idea)
        desk.offer?.chips.removeAll { $0 == word }
        desk.offer?.added = true
    }

    private func addAll(_ offer: GrowOffer) {
        for word in offer.chips { session.addGrown(word, under: offer.idea) }
        dismiss()
    }
}

// MARK: Where the words come from — on this device only; nothing is sent away

enum GrowSuggester {
    /// Related words for an idea. Apple's on-device language model when the device has it ready; otherwise the
    /// nearest words of the idea's language from the system's word list (NaturalLanguage). Empty: nothing found.
    static func suggest(for idea: String, around: [String]) async -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let found = await fromModel(idea, around: around)
            if !found.isEmpty { return found }
        }
        #endif
        return await Task.detached(priority: .userInitiated) { fromWordList(idea) }.value
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func fromModel(_ idea: String, around: [String]) async -> [String] {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return [] }
        let session = LanguageModelSession(instructions: """
            You help someone grow a mind map. Reply with exactly five short related ideas, one per line, \
            each one to three words, no numbers, no bullets, no explanations. \
            Write them in the same language as the idea.
            """)
        var prompt = "Idea: \(idea)"
        if !around.isEmpty { prompt += "\nIt sits in a map about: \(around.joined(separator: ", "))" }
        do {
            let reply = try await session.respond(to: prompt)
            return reply.content.split(whereSeparator: \.isNewline).map(String.init)
        } catch {
            return []
        }
    }
    #endif

    /// The nearest words in the idea's language (its longest word when the idea is a phrase).
    static func fromWordList(_ idea: String) -> [String] {
        let recogniser = NLLanguageRecognizer()
        recogniser.processString(idea)
        var languages: [NLLanguage] = []
        if let found = recogniser.dominantLanguage { languages.append(found) }
        if !languages.contains(.english) { languages.append(.english) }
        let tokens = idea.split(whereSeparator: { !$0.isLetter }).map { String($0).lowercased() }
        let tries = ([idea.lowercased()] + tokens.sorted { $0.count > $1.count }).filter { !$0.isEmpty }
        for language in languages {
            guard let words = NLEmbedding.wordEmbedding(for: language) else { continue }
            for word in tries {
                let near = words.neighbors(for: word, maximumCount: 14).map(\.0)
                    .filter { $0.allSatisfy { $0.isLetter || $0 == " " || $0 == "-" } }
                if !near.isEmpty { return near.map { $0.prefix(1).uppercased() + $0.dropFirst() } }
            }
        }
        return []
    }
}
