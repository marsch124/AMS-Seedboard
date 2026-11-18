import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Colours of the calmer look (0.2): PARAGON's purple button and the soft tint of the chosen board.
enum Look {
    private typealias RGBA = (Double, Double, Double, Double)

    private static func dynamic(day: RGBA, night: RGBA) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { look in
            let c = look.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? night : day
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? night : day
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
        #endif
    }

    private static func hex(_ v: Int, _ alpha: Double = 1) -> RGBA {
        (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255, alpha)
    }

    /// The fill of a button that leads to PARAGON: its purple by day, a lighter one by night. White words on both.
    static let paragonButton = dynamic(day: hex(0x6B4EA8), night: hex(0x7F62C6))

    /// Behind the chosen board in the list: a soft green tint, so "New board" stays the only solid green there.
    static let chosenRow = dynamic(day: hex(0x2E8B57, 0.14), night: hex(0x5FBF8A, 0.20))
}

/// The full-colour button that leads to PARAGON. Never grey: one that cannot be pressed yet is only paler.
struct ParagonButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Look.paragonButton, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
            .contentShape(Rectangle())
    }
}

/// A 2-point ring round the colour that is in use, in the colour row.
struct InUseRing: ViewModifier {
    let on: Bool

    func body(content: Content) -> some View {
        content
            // The ring lies outside the dot, with a small gap, and takes no room of its own.
            .overlay(Circle().stroke(Color.primary.opacity(0.85), lineWidth: 2).padding(-4).opacity(on ? 1 : 0))
            .accessibilityAddTraits(on ? .isSelected : [])
    }
}
