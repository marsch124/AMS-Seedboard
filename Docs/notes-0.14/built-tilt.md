# Lane tilt — idea 14 (Tilt a note, picture or shape) — BUILT

What it does: a sticky note, a picture, a free text or a flowchart shape (box, round, diamond, oval, person, document, slanted, store) can be turned a little, like a note stuck on crooked. Not ideas of a mind map, frames, doors, sketches, tables, timeline or Who-does-what things. Stored in `Item.tilt` (degrees, clockwise, -45 to 45); straight is stored as nothing.

Ways and exact words
- Bar (Mac, iPad, iPhone): a words-only button "Tilt" beside the other buttons of the chosen thing (id `sel.tilt`, no mark). Each press: straight, then a little left (-4 degrees), then a little right (4 degrees), then straight. Lit while the thing is tilted. Behind the "..." when the bar is narrow (drop 7, goes first with Vote). Also on a choice of several things when all can be tilted.
- Right-click menu on the Mac and press-and-hold menu: a line "Tilt" (id `menu.tilt`) that opens a short list: "Straighten" (`menu.tilt.straighten`, greyed when already straight), "Lean left" (`menu.tilt.left`), "Lean right" (`menu.tilt.right`).
- iPhone and iPad: a two-finger twist with both fingers on the chosen thing (one thing chosen). It follows the fingers; the board does not slide or zoom meanwhile. Lifting within 3 degrees of straight snaps it straight. One undo step per twist.
- Every change is one undo step; only on a board that can be changed and not on Timeline / Who-does-what boards.

Drawing: the thing, its words and its picture turn round its middle (one painter, so the PDF, print and the picture for PARAGON show it turned too). Vote dots, pin, link line turn with it. The chosen frame and the grips (size knobs, plus-handles) follow it. Presses use the turned shape (Core: `Tilt.contains/rotate`, `Board.hit` and the finger-sized press area). Arrows still end on the edge of the un-turned box.

Rules in Core: `Core/Sources/SeedboardCore/Tilt14.swift` (`Tilt`, `Item.turn`, `Board.setTilt/stepTilt/tiltable`); test `Tilt14Tests` (3 tests). 512 Core tests green.
App: `App/Sources/Tilt14.swift`; small marked blocks in CanvasDraw (ghost), BoardMotion (`drawInMotion`), MarksDraw, ChosenFrame, ChosenBar (`wordOnly` chip), BarActions (`BarAction.wordOnly`, `tiltActions`), BoardSession (3 vars), TouchLayer (rotation recogniser).
Identifiers: `sel.tilt`, `menu.tilt`, `menu.tilt.straighten`, `menu.tilt.left`, `menu.tilt.right`.
No new stored field, no new screen (no screen test), no launch words.

Does NOT do: tilt ideas, frames, doors, sketches, tables, timeline or sequence things; a free "angle" slider; a twist handle on the Mac (Mac: button and menu only); a trackpad twist.
Could not see (no simulator allowed): the look when turned, the twist on a real touch screen. Known rough edges: a size knob drag on a tilted thing resizes along the straight box; typing words in a tilted thing shows the text field upright; the press area of a very small tilted thing uses the finger rule on its turned shape.
Signs: "Tilt" lit = the thing is tilted (same lit look as other bar buttons that are on).
