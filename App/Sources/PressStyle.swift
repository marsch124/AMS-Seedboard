import SwiftUI

// 0.5: one answer to a press and to the pointer for every plain button of the app (tool tiles, bar buttons,
// zoom buttons, cards, list rows). Use `.buttonStyle(PressStyle())` wherever `.plain` stood.

/// A button that answers: pressed, it shrinks to 95 % in 0.08 s and springs back in 0.18 s; with the pointer
/// over it (Mac, iPad trackpad) it shows a faint wash. It adds no padding and no shape of its own, so a
/// button looks exactly as it did with `.plain` while nothing touches it.
struct PressStyle: ButtonStyle {
    /// How far it shrinks while pressed.
    var pressed: CGFloat = 0.95
    /// The wash under the pointer; `nil` = none (the button draws its own hover look).
    var wash: Color? = Color.primary.opacity(0.05)
    /// The corner of the wash.
    var corner: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, pressed: pressed, wash: wash, corner: corner)
    }

    private struct PressBody: View {
        let configuration: Configuration
        let pressed: CGFloat
        let wash: Color?
        let corner: CGFloat
        @State private var over = false
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .background {
                    if let wash, over, enabled {
                        RoundedRectangle(cornerRadius: corner, style: .continuous).fill(wash)
                    }
                }
                .scaleEffect(configuration.isPressed && Feel.moves ? pressed : 1)
                .opacity(configuration.isPressed && !Feel.moves ? 0.7 : 1)
                .animation(Feel.moves ? (configuration.isPressed ? .easeOut(duration: 0.08) : .spring(duration: 0.18)) : nil,
                           value: configuration.isPressed)
                .contentShape(Rectangle())
                .onHover { over = $0 }
        }
    }
}
