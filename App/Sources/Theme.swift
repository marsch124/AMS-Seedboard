import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The parts of Seedboard. Each has its own colour for headings and marks, one shade for day, a lighter one for night.
enum Part: String, CaseIterable {
    case boards, mindMap, shapes, arrows, notes, text, frames, paragon
    /// The timeline board: its tools, its Today button, its Dates page.
    case timeline
    /// The "Who does what" board: its Who tool, its Answer and Colour buttons.
    case sequence

    private typealias RGB = (Double, Double, Double)

    private var shades: (day: RGB, night: RGB)? {
        switch self {
        case .boards: return (hex(0x2E8B57), hex(0x5FBF8A))
        case .mindMap: return (hex(0xA8388F), hex(0xE27FC8))
        case .shapes: return (hex(0x2B67C9), hex(0x7FAEF5))
        case .arrows: return (hex(0x4A5565), hex(0xA9B4C4))
        case .notes: return (hex(0xB77A08), hex(0xF0BE50))
        case .frames: return (hex(0x178378), hex(0x5CCBBE))
        case .paragon: return (hex(0x6B4EA8), hex(0xB59CEB))
        case .timeline: return (hex(0xC4551F), hex(0xF59A66))
        case .sequence: return (hex(0x5C7A12), hex(0xB5D95A))
        case .text: return nil   // ink: the primary text colour
        }
    }

    private func hex(_ v: Int) -> RGB {
        (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }

    /// For words and marks: the strong shade by day, the lighter by night.
    var text: Color {
        guard let s = shades else { return .primary }
        return Theme.dynamic(day: s.day, night: s.night)
    }

    /// For a full-colour button or tile with white on top: the same strong shade day and night.
    var fill: Color {
        guard let s = shades else { return Color(red: 0.12, green: 0.13, blue: 0.15) }
        return Color(red: s.day.0, green: s.day.1, blue: s.day.2)
    }

    /// A soft background tint of the part's colour.
    var soft: Color {
        guard let s = shades else { return Theme.dynamic(day: (0.94, 0.94, 0.95), night: (0.17, 0.175, 0.19)) }
        let day = (0.94 + s.day.0 * 0.06, 0.94 + s.day.1 * 0.06, 0.94 + s.day.2 * 0.06)
        let night = (0.12 + s.night.0 * 0.12, 0.12 + s.night.1 * 0.12, 0.12 + s.night.2 * 0.12)
        return Theme.dynamic(day: day, night: night)
    }
}

enum Theme {
    static func text(_ part: Part) -> Color { part.text }
    static func fill(_ part: Part) -> Color { part.fill }
    static func soft(_ part: Part) -> Color { part.soft }

    static func dynamic(day: (Double, Double, Double), night: (Double, Double, Double)) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { look in
            let c = look.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? night : day
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? night : day
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #endif
    }

    /// The plate behind a note or a panel.
    static var plate: Color {
        dynamic(day: (0.955, 0.96, 0.97), night: (0.17, 0.175, 0.19))
    }
}

/// The full-colour main button. Never grey: a button that cannot be pressed yet is the same colour, only paler.
struct FilledButton: ButtonStyle {
    let part: Part
    @Environment(\.isEnabled) private var enabled

    init(_ part: Part) { self.part = part }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(part.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
            .contentShape(Rectangle())
    }
}

/// A part-coloured heading for a list section.
struct PartHeader: View {
    let title: String
    let part: Part
    init(_ title: String, _ part: Part) { self.title = title; self.part = part }
    var body: some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(part.text)
            .textCase(nil)
    }
}

/// One type scale for the whole app: Apple's text styles on iPhone and iPad; the Mac's are small (body 13),
/// so page titles there take a step up while lists keep Apple's sizes.
enum Txt {
    #if os(macOS)
    static let pageTitle = Font.title.weight(.bold)
    static let note = Font.callout
    static let pill = Font.subheadline.weight(.medium)
    static let display = Font.system(.title, design: .rounded).weight(.bold)
    #else
    static let pageTitle = Font.largeTitle.weight(.bold)
    static let note = Font.footnote
    static let pill = Font.caption.weight(.medium)
    static let display = Font.system(.largeTitle, design: .rounded).weight(.bold)
    #endif
    static let cardTitle = Font.headline
    static let sectionTitle = Font.headline
    static let label = Font.subheadline
    static let value = Font.body
    static let big = Font.title2.weight(.bold)
    static let bigNumber = Font.system(.title2, design: .rounded).weight(.bold)
    static let bigRow = Font.title3.weight(.semibold)
    static let bigPill = Font.subheadline.weight(.semibold)
}
