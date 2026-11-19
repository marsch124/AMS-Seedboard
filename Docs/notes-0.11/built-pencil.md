# Built: pencil lane (picks 31, 36, 37, 38)

Everything also works with a finger or the mouse on the Draw plate. Nothing new is saved in a board (format stays 7).

## 1. What's new
- 31 Read this: before, "Make typed" turned a sketch into a text thing and the drawing was gone. Now a chosen sketch also has "Read this": the words found come up as a yellow sticky note 16 points to the right of the sketch, and the sketch stays. One Undo takes the note away. No words found: the line "No words found in this sketch".
- 36 Rubber size: before, the rubber showed a ring while rubbing, with no word. Now the ring has its size under it: Small, Medium or Large (ring reach 20 / 40 / 80 points on screen as already set).
- 37 Ruler: new "Ruler" button on the Draw plate puts a 360-point straight edge in the middle of the board; drag its middle dot to move it, turn it with two fingers on the middle dot or by dragging the round dot at its end. A line drawn within 16 screen points of the edge along its whole way comes out as one straight line laid on the edge. It is not saved and goes when the Draw tool is left.
- 38 Fade drawing: new "Fade" button on the Draw plate: all pencil lines (sketches and marks on pictures, not saved) show at 30 % until pressed again. When the plate is closed a small line "Pencil lines are faded" with a Show button brings them back.

## 2. How it works
- Choose a sketch, press "Read this" in the bar: the words it finds appear on a sticky note beside it. The sketch stays as it is. (Make typed still replaces the sketch.)
- Rubber: while you rub, the ring shows how far the rubber reaches and its word (Small, Medium, Large); change the size on the Draw plate.
- Ruler: Draw plate, Ruler. Move it by its middle dot, turn it with two fingers or with the dot at its end. Draw along it and the line snaps straight onto it. Press Ruler again to take it away. It is only a helper: it is never saved and never part of the picture.
- Fade: Draw plate, Fade makes all pencil lines pale (30 %) so notes on top can be read; press again (or "Show" in the small line after Done) to bring them back. It only changes how the board looks, nothing is saved.

## 3. Spec
- Core `Pencil11.swift`: `Ruler` (centre, angle radians, length; `start`, `end`, `snapped(_:reach:)`, `Ruler.screenReach = 16`, `defaultLength = 360`), `Board.addReadNote(besideDrawing:words:)` (yellow note, x = drawing.x + w + 16, y = drawing.y; nil for no words / not a drawing / board cannot change / places itself).
- `snapped`: nil unless 2+ finite points, every point within reach of the ruler's line, and the snapped length >= 4; else [start foot, end foot].
- App: `Ruler11.swift` (`RulerLayer`, `BoardSession.toggleRuler`), `InkDesk.ruler: Ruler?`, `InkDesk.fade: Bool`, `Fade.opacity = 0.3` (InkDraw.swift), `BoardPainter.inkOpacity`, `BoardSession.readThis` (InkWords.swift), bar action id `ink.readthis` (word "Read this", mark of Make typed).
- Identifiers: `draw.ruler`, `draw.fade`, `draw.fadeLine`, `draw.fadeOff`, `ruler.move`, `ruler.turn`, `ink.readthis`.
- Snapping is applied in `InkDesk.inkEnded` before thinning (pressure dropped for a snapped line). Fade is cleared never by leaving the tool; ruler is cleared by `InkDesk.leave()`.
- Shared files touched (small): CanvasView.swift (2 lines: inkOpacity, RulerLayer), CanvasDraw.swift (1 var), BarActions.swift (new action + 2 calls), InkViews.swift (plate buttons, fade line, ring word), InkDraw.swift, InkDesk.swift, InkWords.swift.

## 4. Pictures
`-sampleData -board sketch -draw` (Draw plate with Ruler and Fade); with `-rubber -rubberSize large` for the rubber plate. Read this: choose a sketch on a sample board, bar shows "Read this" (reading needs a real Mac/device to judge). Ruler/fade states are not launch options.

## 5. Not done / doubts
- No new hand-drawn marks: Ruler and Fade are word buttons; "Read this" reuses the Make typed mark.
- Rubber ring shows only while rubbing (no hover ring on the Mac).
- Ruler snaps only lines whose whole way lies near the edge; a line that starts near and wanders off stays as drawn. Not tried on a real Pencil/iPad. The Mac menu bar has no "Read this" line (bar only).
- Ruler length is fixed at 360 points of screen (no resize); the end handle only turns.
