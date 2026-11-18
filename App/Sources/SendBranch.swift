import SwiftUI
import SeedboardCore

// "Send this branch": with one idea chosen, the Send page offers to send just that idea and
// everything under it. The rule (`Board.branchOnly`) is in SeedboardCore.

/// The switch "Only the branch “Budget”" on the Send page: a row with a small drawn switch.
struct BranchSwitch: View {
    let words: String
    @Binding var on: Bool

    var body: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 8) {
                GlyphView(glyph: .new(.branch), size: 20, colour: Part.mindMap.text)
                Text(words)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Capsule()
                    .fill(on ? Part.paragon.fill : Color.primary.opacity(0.22))
                    .frame(width: 38, height: 22)
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle().fill(Color.white).padding(2)
                    }
                    .animation(.easeOut(duration: 0.12), value: on)
            }
            .padding(8)
            .background(on ? Part.paragon.soft : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(on ? Part.paragon.text : Color.primary.opacity(0.12), lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(corner: 10))
        .accessibilityLabel(words)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityIdentifier("send.branchOnly")
    }
}

extension BoardSession {
    /// The one chosen idea, when the Send page can offer "Only the branch …".
    var branchToSend: Item? {
        guard let item = single, item.kind == .idea else { return nil }
        return item
    }

    /// The words on the switch: "Only the branch “Budget”" (for a middle idea: "Only the map “…”").
    func branchSwitchWords(_ item: Item) -> String {
        var name = board.branchName(item.id)
        if name.count > 32 { name = String(name.prefix(30)).trimmingCharacters(in: .whitespaces) + "…" }
        let what = item.parent == nil ? "map" : "branch"
        return name.isEmpty ? "Only this \(what)" : "Only the \(what) “\(name)”"
    }
}
