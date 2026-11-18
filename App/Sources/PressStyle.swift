import SwiftUI
import SeedboardCore

// 0.5: one answer to a press and to the pointer for every plain button of the app (tool tiles, bar buttons,
// zoom buttons, cards, list rows). Use `.buttonStyle(PressStyle())` wherever `.plain` stood.
//
// Three kinds of button, three looks (FeelRules has the numbers):
// - a button with NO plate of its own (a mark, a word, a list row): `PressStyle()` — a 5 % wash under the pointer;
// - a tile or a bar button with its OWN soft plate: `PressStyle(tint: part.text)` — the plate's tint goes one
//   step stronger under the pointer and doubles while pressed, exactly inside the plate's own shape;
// - a button whose plate lies outside its label, or a colour dot: `PressStyle(wash: nil)` — it only shrinks.

/// A button that answers: pressed, it shrinks to 95 % in 0.08 s and springs back in 0.18 s; with the pointer
/// over it (Mac, iPad trackpad) it shows a faint wash. It adds no padding and no shape of its own, so a
/// button looks exactly as it did with `.plain` while nothing touches it.
struct PressStyle: ButtonStyle {
    /// How far it shrinks while pressed.
    var pressed: CGFloat = FeelRules.tilePressed
    /// The wash under the pointer; `nil` = none (the button draws its own hover look).
    var wash: Color? = Color.primary.opacity(0.05)
    /// The corner of the wash.
    var corner: CGFloat = 8
    /// The button has a plate of its own: this colour (the part's own) is laid over the plate, only where the
    /// label is drawn — one step under the pointer, double while pressed. With a tint there is no wash.
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, pressed: pressed, wash: wash, corner: corner, tint: tint)
    }

    /// For pictures (DEBUG): `-pressLook over` shows every button as with the pointer over it, `-pressLook down` as pressed.
    static let forced: String? = {
        #if DEBUG
        return LaunchOptions.value(for: "-pressLook")
        #else
        return nil
        #endif
    }()

    private struct PressBody: View {
        let configuration: Configuration
        let pressed: CGFloat
        let wash: Color?
        let corner: CGFloat
        let tint: Color?
        @State private var pointer = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.colorScheme) private var scheme

        private var over: Bool { pointer || PressStyle.forced == "over" }
        private var down: Bool { configuration.isPressed || PressStyle.forced == "down" }

        var body: some View {
            let strength = FeelRules.tintStrength(pressed: down, over: over, enabled: enabled, night: scheme == .dark)
            return configuration.label
                .background {
                    if let wash, tint == nil, over, enabled {
                        RoundedRectangle(cornerRadius: corner, style: .continuous).fill(wash)
                    }
                }
                .modifier(PlateTint(tint: tint, strength: strength))
                .scaleEffect(down && Feel.moves ? pressed : 1)
                .opacity(down && !Feel.moves ? 0.7 : 1)
                .animation(Feel.moves ? (down ? .easeOut(duration: 0.08) : .spring(duration: 0.18)) : nil, value: down)
                .animation(Feel.moves ? .easeOut(duration: 0.12) : nil, value: over)
                .contentShape(Rectangle())
                .onHover { pointer = $0 }
        }
    }
}

/// Lays a colour over a button's own plate, only where the label is drawn (so it keeps the plate's exact
/// shape, and the press room round it stays clear).
private struct PlateTint: ViewModifier {
    let tint: Color?
    let strength: Double

    func body(content: Content) -> some View {
        if let tint {
            content
                .overlay { tint.opacity(strength).blendMode(.sourceAtop).allowsHitTesting(false) }
                .compositingGroup()
        } else {
            content
        }
    }
}

/// For a tile that is not a button (the Box tile answers a press and a hold itself): the same answer as
/// `PressStyle(tint:)` — the tint one step stronger under the pointer, double and 95 % while `down`.
struct TileAnswer: ViewModifier {
    let tint: Color
    var down = false
    @State private var pointer = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let pressed = down || PressStyle.forced == "down"
        let over = pointer || PressStyle.forced == "over"
        return content
            .modifier(PlateTint(tint: tint, strength: FeelRules.tintStrength(pressed: pressed, over: over, night: scheme == .dark)))
            .scaleEffect(pressed && Feel.moves ? FeelRules.tilePressed : 1)
            .animation(Feel.moves ? (pressed ? .easeOut(duration: 0.08) : .spring(duration: 0.18)) : nil, value: pressed)
            .animation(Feel.moves ? .easeOut(duration: 0.12) : nil, value: over)
            .onHover { pointer = $0 }
    }
}

/// The look of a full-colour main button (`FilledButton`, `ParagonButton`): white words on a solid plate.
/// Pressed it stays solid — 12 % darker and 97 % of its size, never see-through. One that cannot be pressed
/// yet is the same colour, only paler.
struct MainPlate: ViewModifier {
    let fill: Color
    let pressed: Bool
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        let down = (pressed || PressStyle.forced == "down") && enabled
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return content
            .background {
                // The fill is drawn first and darkened under the words, so the words stay white.
                shape.fill(fill).overlay(shape.fill(Color.black.opacity(down ? FeelRules.mainDarker : 0)))
            }
            .opacity(enabled ? 1 : 0.5)
            .scaleEffect(down && Feel.moves ? FeelRules.mainPressed : 1)
            .animation(Feel.moves ? (down ? .easeOut(duration: 0.08) : .spring(duration: 0.18)) : nil, value: down)
    }
}

extension BarAction {
    /// The colour a chip of this action wears in a bar of `tint` (To do is PARAGON's, Remove is brick red).
    func part(in tint: Part) -> Part { tone == .todo ? .paragon : (tone == .remove ? .kept : tint) }
}
