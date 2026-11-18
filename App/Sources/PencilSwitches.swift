import Foundation

// The two Pencil features of 0.5 (pick 30) ship OFF: the owner is away from his Pencil until
// January, and both need a real iPad with a Pencil to tune. Flip a constant to turn one on.

extension Finger {
    /// Tidy shapes (InkTidy.swift): is the switch "Tidy shapes" in the Draw plate on before the owner
    /// has ever touched it? false: every line stays the sketch it is until he turns the switch on himself.
    static let tidyShapesAtFirst = false

    /// Writing straight onto a shape with the Pencil (ShapeScribble.swift). false: nothing of it is
    /// set up at all — the Pencil on a thing chooses and moves it, exactly as before.
    static let scribbleOntoShapes = false
}
