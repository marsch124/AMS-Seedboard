# Built in 0.5 — lane "pencil" (pick 30)

Branch `wt-pencil`. Both parts ship **OFF**; nothing changes for any board while they are off.

## The two constants the lead flips

Both in ONE new file, `App/Sources/PencilSwitches.swift`:

| Constant | Now | What flipping it to `true` does |
|---|---|---|
| `Finger.tidyShapesAtFirst` | `false` | The switch "Tidy shapes" is ON for an owner who has never touched it. (He can turn it on himself today, whatever this says.) |
| `Finger.scribbleOntoShapes` | `false` | Sets up "write straight onto a shape" on iPhone and iPad. While `false` nothing of it is set up at all, and there is no switch for it on screen. |

## 1. Tidy shapes — BUILT (off at first)

### What the owner sees

- In the **Draw plate** (the plate that shows while the Draw tool is on), between the colour dots and **Done**, there is a new switch with the words **Tidy shapes**.
  - Off (as it ships): soft raspberry tint, raspberry words — the same look as a pen or thickness that is not chosen.
  - On: full raspberry with white words — the same look as the chosen pen or thickness.
  - A press turns it on, another press off. It is remembered on this device (not in iCloud, not in the board).
  - On the Mac, resting the pointer on it shows: "Draw a box, an oval or a diamond and hold still for a moment: it becomes a real shape. A line from one thing to another becomes an arrow."
- With the switch on:
  - **Draw a box, an oval or a diamond in ONE line, hold the tip still for a moment at the end, then lift.** The sketch becomes a real **Box**, **Oval** or **Diamond** of that size, in that place.
  - **Draw ONE line from one thing to another, hold still at the end, lift.** The sketch becomes an **arrow** from the thing where the line began to the thing where it ended (the app's ordinary arrow, right angles, with a head).
  - **One Undo gives the raw line back** (a second Undo takes the line away too). Redo makes it the shape again.
  - Lifting without the pause leaves the line the sketch it is — exactly as before. So the pause is the way to say "tidy this one".
- It works for whatever draws: the Pencil (on empty board, no tool needed), and a finger or the mouse while the Draw tool is on. So he can try it on the Mac with the mouse, without his Pencil: hold the mouse button still for a moment before letting go.
- With the switch off (as it ships) every line stays a sketch. Nothing else is different.

### The rule, with its numbers (`Core/Sources/SeedboardCore/InkShape.swift`)

The pause
- The tip must stand still for **0.4 s** at the end of the line before it lifts (the Freeform habit). While it stands it may tremble up to **6 screen points** round its place.

Which line is looked at
- Only a line that **begins a new sketch**. A line that joins the sketch he is still drawing (within 5 s and 40 points of it, as before) is never looked at, so a drawing in progress is never touched.
- Never on a timeline or a "Who does what" board, never on a board that cannot be changed.

A loop becomes a shape when all of this holds
- It is **closed**: its two ends meet within **20 %** of the diagonal of the box round the line — or one end runs a little way over the other's beginning.
- It goes round **once**: between 0.8 and 1.35 of a turn (so a little way over is fine, twice round is a scribble).
- It is at least **44 wide and 28 high** (the smallest a shape can be made). Smaller loops are handwriting.
- It **fits**: its line lies, on average, no further from the outline of a rectangle, an oval or a diamond than **3.5 %** of the shape's diagonal — AND the outline no further from the line. The best fit of the three wins.
- It may **lean up to 10 degrees**: a loop that does not fit well as drawn is tried turned back in steps of 2 degrees. The shape it becomes always stands straight.
- It does **not lie over anything that is already there** (a frame does not count). A ring drawn round a thing stays a ring — it does not become a lid over it.

What the shape is like
- Kind: Box, Oval or Diamond. Size and place: the loop's own, less the hand's wobble, in whole points.
- Colour: the colour the line was drawn in; plain ink gives the shape its own colour. The line's thickness is not kept.
- No words, on top of everything, not chosen (he can go on drawing).

A line becomes an arrow when all of this holds
- It is not a closed loop.
- It **begins at one thing and ends at another**: inside the thing, or within **14 screen points** of it. Of two things as near, the one on top is meant. Frames take no arrows; a sketch is not joined this way.
- It may bend, but not wander: no longer than **2.5 times** the straight way between its ends, and at least 12 points long.
- That arrow is not there already (the other way round is a new arrow).

What stays a sketch (each proved by a data test)
- A triangle, a house (five corners), a rectangle leaning 25 degrees, a to-and-fro scribble (also one that ends where it began), an oval drawn twice round, a spiral, a figure of eight, a straight line, a line there and back, a corner, three sides of a rectangle, a small loop as in handwriting, a loop too flat, a dot.
- A loop round something that is there. A line from a thing to nothing, from nothing to a thing, from a thing back to itself, to a frame, to a sketch. A wandering line. An arrow that is there already.

### Where this differs from the panel note (finding 8) — on purpose

- **The fit number.** The note says "mean distance to the fitted outline under 8 % of its diagonal". Measured that way, a triangle is 5 to 7 % from a rectangle and a house 3 % — both would have become boxes. So the rule asks BOTH ways (line to outline and outline to line) and the number is 3.5 %. Clean shapes come out at 0 %, wobbly and leaning ones at 1 to 2.5 %, a triangle at 6.5 % and more, a house at 3.8 %.
- **"The tip rests 0.4 s"** is built as the Freeform habit: hold still at the END of the line, then lift. It is not "wait 0.4 s after lifting".
- **"On at first"** in the note; the brief says OFF until January — built OFF.
- Added beyond the note: the lean of up to 10 degrees, "not over something that is there", the arrow that may not wander, the shape takes the line's colour.

### Known limits (to tune with a real Pencil in January)

- A loop with six or more sides is round enough to become an Oval.
- A house (five corners) is only just outside the limit (3.8 % against 3.5 %): a very wobbly one may become a Box or an Oval.
- A rectangle with round corners becomes a Box (never a Round box).
- All numbers above are first guesses; they are constants at the top of `InkShape.swift`.
- There is no picture or sound when a line is tidied — the line simply becomes the shape.

## 2. Write straight onto a shape — BUILT, OFF, never seen running

- What it does when `Finger.scribbleOntoShapes` is `true` (iPhone and iPad only): Apple's Scribble is told where the things with words lie on the board. Writing over a box with the Pencil then starts typing in it — no two presses first. The words go into the board's own typing field.
- Which things take writing (`Board.takesWriting`, data-tested): an idea, a box, a round box, a diamond, an oval, a sticky note, a text, a person, a document, a slanted box, a store. NOT a sketch (no words), a picture (its caption has its own button), a frame (it would swallow every line drawn inside it), a door, anything folded away, anything on a timeline or "Who does what" board or on a board that cannot be changed.
- The traps of the note, as built:
  - Writing against moving: when the system says the writing has begun, the Pencil's press on the thing is given up and the small shove taken back — unless the tip has already gone further than **10 screen points** from where it landed. Then it is a drag: the thing moves and the writing is dropped. Opening the thing for typing is delayed (`shouldDelayFocus`) so the drag can win first. The half-second hold menu is cancelled when writing begins.
  - The real field: after `beginEdit` the typing field is looked for every 0.05 s for at most 0.6 s (the view that holds the keys and takes text) and handed to the system.
  - While the Draw tool or the arrow tool is on, nothing is offered: the Pencil draws or joins as before.
- **Not seen running by anyone.** It compiles for iPhone and iPad; it needs a real iPad with a Pencil. Unknown until then: whether the system tells "writing has begun" early enough for the 10-point rule to feel right, whether the field is found in time, and how it feels beside "the Pencil on a thing moves it".

## Launch words (for pictures)

- `-tidyShapes` — the switch is on from the start (also with `-sampleData`).
- `-tidyDemo` (debug builds only; with `-draw`) — six lines draw themselves through the very calls a hand's line goes through, each resting half a second at its end: a wobbly rectangle, an oval, a diamond, a line from the first to the second, a triangle, a scribble. With `-tidyShapes`: a Box, an Oval, a Diamond, an arrow and two sketches. Without: six sketches.
- `-tidyDemo undo` (debug builds only) — only the rectangle draws itself, then one Undo: the raw line is back.
- Example: `… -board Sketch -draw -tidyShapes -tidyDemo -sampleData` (add `-night` after `-board Sketch` for night).
- Trap seen: started with `-ApplePersistenceIgnoreState YES` the Mac debug build showed NO window at all here; started as the brief says (without it) the window comes.

## Seen running, and not

Seen on the Mac debug build (the lines drawn by `-tidyDemo`, through the real calls, on the made-up board "Sketch ideas"; pictures in `/private/tmp/claude-501/-Users-martinschabbauer-Obsidian-Claude-Code/17034763-8459-4a3b-a9bb-13fd5828f01e/scratchpad/pencil/`):
- Switch on, day (`tidy-on.png`) and night (`tidy-on-night.png`): a Box, an arrow to an Oval, a Diamond; the triangle and the scribble stay sketches. The count line went from "2 notes · 3 sketches" to "3 shapes · 2 notes · 5 sketches".
- One Undo (`tidy-undo.png`): the raw wobbly rectangle is back ("2 notes · 4 sketches"), Redo is lit.
- Switch off (`tidy-off.png`): all six stay sketches ("2 notes · 9 sketches"); the switch shows soft.

NOT seen running:
- A real hand: no line was drawn with a mouse, a finger or the Pencil, so the 0.4 s pause was only ever a timer's. How it FEELS is unknown.
- iPhone and iPad altogether (they build; the simulators were not used, as the brief says).
- Write straight onto a shape: nothing of it.
- The two screen tests were compiled, not run.

## New identifiers

- `draw.tidy` — the switch (label "Tidy shapes", value "On" / "Off").

## Stored data

- **No new stored field. The board format is not touched.** A tidied sketch is an ordinary Box / Oval / Diamond or an ordinary arrow.
- This device only: `UserDefaults` key `ink.tidyShapes` (the switch). Not written with `-sampleData`.

## Marks wanted

- None. The switch is words only.

## Tests

- Rule tests: 11 new, in `Core/Tests/SeedboardCoreTests/Pencil05Tests.swift`.
- Screen test: `UITests/PencilUITests.swift` (2 tests: the switch is in the plate and off at first; `-tidyShapes` turns it on). Compiled, NOT run (the lead runs screen tests after the join).

## Files

New
- `Core/Sources/SeedboardCore/InkShape.swift` — the rules (tidy shapes, the rest of the tip, what takes writing).
- `Core/Tests/SeedboardCoreTests/Pencil05Tests.swift`
- `App/Sources/PencilSwitches.swift` — the two constants.
- `App/Sources/InkTidy.swift` — the switch, where it is kept, the swap step, the debug demo.
- `App/Sources/ShapeScribble.swift` — iPhone and iPad only.
- `UITests/PencilUITests.swift`

Small hunks in existing files (where the join may clash)
- `App/Sources/InkDesk.swift` — 3 lines in the class `InkDesk` (after `let wet`), 1 line in `inkBegan`, 1 in `inkMoved`, 1 at the end of `inkEnded`.
- `App/Sources/InkViews.swift` — 1 line in `DrawPlate.plate` (before the Done button).
- `App/Sources/TouchLayer.swift` — 2 lines (a property after `let hold`), 1 line at the end of `init`, and two small members (`pencilStrayed`, `giveUpPencil`) before `gestureRecognizer(_:shouldReceive:)`.

## Not built

- No picture or motion when a line becomes a shape (the motion lane owns motion; nothing was asked).
- No switch on screen for "write straight onto a shape" (the brief asks for a constant only).
- Tidy shapes does not snap while the tip is still down (Freeform shows the shape before the lift); here it happens at the lift.

## Drive-by things seen and left

- None.
