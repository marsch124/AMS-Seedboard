import SwiftUI
import SeedboardCore
import AMSIcons

// The small plate with ALL flow shapes (0.2, pick 15). It opens from the Box tile of the tool pill
// (hold the tile, or press its corner mark) to add a shape, and from "Shape" in the bar of a chosen
// shape to change it into another kind.

extension ItemKind {
    /// The hand-drawn mark of a flow shape.
    var mark: Glyph {
        switch self {
        case .round: return .app(.seedRound)
        case .oval: return .app(.seedOval)
        case .diamond: return .app(.seedDiamond)
        case .person: return .new(.person)
        case .document: return .new(.document)
        case .slanted: return .new(.slanted)
        case .store: return .new(.store)
        default: return .app(.seedBox)
        }
    }
}

/// The shape the Box tile adds: the one last picked from the plate. Kept on this device.
/// With made-up boards (`-sampleData`, pictures and tests) nothing is read or kept: it starts as a Box.
@MainActor
final class ShapeChoice: ObservableObject {
    static let shared = ShapeChoice()
    private static let key = "tool.lastShape"

    @Published private(set) var last: ItemKind

    private init() {
        last = ItemKind.boxTile(stored: LaunchOptions.sampleData ? nil : UserDefaults.standard.string(forKey: ShapeChoice.key))
    }

    func used(_ kind: ItemKind) {
        let tile = ItemKind.boxTile(stored: kind.rawValue)
        // A Diamond has its own tile: picking it leaves this one as it is.
        guard kind != .diamond, tile != last else { return }
        last = tile
        if !LaunchOptions.sampleData { UserDefaults.standard.set(tile.rawValue, forKey: ShapeChoice.key) }
    }
}

/// Shows a small plate: a pop-up on the Mac and the iPad, a low sheet on the iPhone
/// (a pop-up comes out empty there).
struct PlatePresenter<Plate: View>: ViewModifier {
    @Binding var shown: Bool
    var edge: Edge = .top
    /// The height of the sheet on the iPhone.
    var height: CGFloat = 230
    /// Called when the plate has gone, however it went.
    var closed: () -> Void = {}
    @ViewBuilder let plate: () -> Plate

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var compact: Bool {
        #if os(macOS)
        return false
        #else
        return sizeClass == .compact
        #endif
    }

    func body(content: Content) -> some View {
        content
            .popover(isPresented: Binding(get: { shown && !compact }, set: { shown = $0 }), arrowEdge: edge) {
                plate()
                    .presentationCompactAdaptation(.popover)
            }
            .sheet(isPresented: Binding(get: { shown && compact }, set: { shown = $0 }), onDismiss: closed) {
                plate()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .presentationDetents([.height(height)])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: shown) { _, now in
                // The sheet says by itself when it has gone; the pop-up does not — it is given a moment to go.
                if !now, !compact { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { closed() } }
            }
    }
}

/// The heading of a plate: its name in the part's colour, and Cancel (Escape on the Mac).
struct PlateHeading: View {
    let title: String
    let glyph: Glyph
    let part: Part
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            GlyphView(glyph: glyph, size: 17, colour: part.text)
            Text(title)
                .font(Txt.sectionTitle)
                .foregroundStyle(part.text)
            Spacer(minLength: 12)
            Button("Cancel", action: cancel)
                .buttonStyle(.plain)
                .font(Txt.label.weight(.semibold))
                .foregroundStyle(part.text)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("plate.cancel")
        }
    }
}

/// All eight flow shapes, four in a row: the mark with its name under it.
struct ShapePlate: View {
    let title: String
    /// The kind the chosen shape has now (shown in full colour); nil when a new shape is added.
    var chosen: ItemKind?
    /// Each tile's identifier is this and the kind's stored name ("plate.shape.person").
    let prefix: String
    let pick: (ItemKind) -> Void
    let cancel: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlateHeading(title: title, glyph: .app(.seedBox), part: .shapes, cancel: cancel)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 60), spacing: 6), count: 4), spacing: 6) {
                ForEach(ItemKind.flowShapes, id: \.self) { kind in
                    let on = kind == chosen
                    Button { pick(kind) } label: {
                        VStack(spacing: 2) {
                            GlyphView(glyph: kind.mark, size: 26, colour: on ? .white : Part.shapes.text)
                            Text(kind.word)
                                .font(Txt.pill)
                                .foregroundStyle(on ? Color.white : Color.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(on ? Part.shapes.fill : Part.shapes.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(kind.word)
                    .accessibilityIdentifier(prefix + kind.rawValue)
                }
            }
        }
        .padding(12)
        .frame(width: plateWidth)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plate.shapes")
    }

    /// A fixed width in a pop-up; the whole width of the sheet on the iPhone.
    private var plateWidth: CGFloat? {
        #if os(macOS)
        return 344
        #else
        return sizeClass == .compact ? nil : 344
        #endif
    }
}

/// The Box tile of the tool pill. A press adds the shape last picked (a Box at first) and the tile
/// shows that shape's mark. Holding the tile, or a press on the small mark in its corner, opens the
/// plate with all shapes.
struct ShapeTool: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var choice = ShapeChoice.shared
    /// For pictures: `-plate shapes` opens the plate at once.
    @State private var shown = LaunchOptions.value(for: "-plate") == "shapes"
    /// The shape picked from the plate: it is added when the plate has gone, so the typing can begin.
    @State private var picked: ItemKind?
    @Environment(\.toolSide) private var side

    var body: some View {
        let kind = choice.last
        let name = kind == .box ? "Box (B)" : kind.word
        ZStack(alignment: .bottomTrailing) {
            GlyphView(glyph: kind.mark, size: ToolSize.mark(side), colour: Part.shapes.text)
                .frame(width: side, height: side)
                .background(Part.shapes.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    session.add(kind)
                    session.takeKeys()
                }
                .onLongPressGesture(minimumDuration: 0.4) { shown = true }
                .help("\(name) — hold for all shapes")
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(name)
                .accessibilityAction {
                    session.add(kind)
                    session.takeKeys()
                }
                .accessibilityAction(named: "All shapes") { shown = true }
                .accessibilityIdentifier("tool.box")

            Button { shown = true } label: {
                CornerMark()
                    .fill(Part.shapes.text)
                    .frame(width: 7, height: 7)
                    .padding(3)
                    .frame(width: 18, height: 18, alignment: .bottomTrailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // On the iPhone the corner is too small for a finger: it only shows that there is more (hold the tile).
            .allowsHitTesting(ShapeTool.cornerTakesPresses)
            .help("All shapes")
            .accessibilityLabel("All shapes")
            .accessibilityIdentifier("tool.shapes")
        }
        .modifier(PlatePresenter(shown: $shown, edge: .top, closed: {
            if let kind = picked {
                picked = nil
                choice.used(kind)
                session.add(kind)
            }
            session.takeKeys()
        }) {
            ShapePlate(title: "Add a shape", prefix: "plate.shape.", pick: { kind in
                picked = kind
                shown = false
            }, cancel: { shown = false })
        })
    }

    private static var cornerTakesPresses: Bool {
        #if os(macOS)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom != .phone
        #endif
    }
}

/// The small filled corner that says "there is more behind this tile".
struct CornerMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// How a button in the bar of a chosen thing looks (the same as the bar's own buttons).
struct BarChip: View {
    let word: String
    let glyph: Glyph
    let part: Part
    var on = false

    var body: some View {
        HStack(spacing: 4) {
            GlyphView(glyph: glyph, size: 15, colour: on ? .white : part.text)
            Text(word)
                .font(Txt.pill)
                .foregroundStyle(on ? Color.white : Color.primary)
        }
        .padding(.horizontal, 8)
        .frame(height: Finger.chipHeight)
        .background(on ? part.fill : part.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .pressRoom(0, 4)
    }
}

/// "Shape" in the bar of a chosen shape: one button that opens the plate, to change it into any kind.
struct ShapeChip: View {
    @ObservedObject var session: BoardSession
    let item: Item
    /// For pictures: `-plate shape` (with `-pick`) opens the plate at once.
    @State private var shown = LaunchOptions.value(for: "-plate") == "shape"

    var body: some View {
        Button { shown = true } label: {
            BarChip(word: "Shape", glyph: item.kind.mark, part: .shapes, on: shown)
        }
        .buttonStyle(.plain)
        .help("Change it into another shape")
        .accessibilityIdentifier("sel.shape")
        .modifier(PlatePresenter(shown: $shown, edge: .bottom, closed: { session.takeKeys() }) {
            ShapePlate(title: "Change the shape", chosen: item.kind, prefix: "sel.shape.", pick: { kind in
                session.setKind(kind)
                shown = false
            }, cancel: { shown = false })
        })
    }
}
