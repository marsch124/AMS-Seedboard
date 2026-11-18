# Built in the `thinking` lane (0.5) — picks 10, 11, 12 and the paste bug

Branch `wt-thinking`. Findings 2, 3, 4 and 8 of `panel-thinking-flow.md`. Everything below is OFF on a board that places its things itself (a timeline, "Who does what"): no button, no menu line, no key.

## Pick 10 — the next note and the next shape while typing (finding 2, parts a, b, c)

**a. Tab in a sticky note.** While the words of a sticky note are typed, Tab keeps the words and makes the next note; the typing goes on in it.
- The next note has the same colour and the same size (width and height) as the one before.
- It stands 16 points to the right of it, top edges in line.
- When that place is taken (anything but a frame lies there), it goes under the FIRST note of the row instead: left edge in line with that note, 16 points under the tallest note of the row. The row = the notes standing close beside each other to the left (not more than 40 points apart, about the same height on the board). If that place is taken too, it goes further down, one note height and 16 points at a time, until a place is free.
- A next note that is left empty goes away again and leaves no trace: no step for Undo, and the note it came from is chosen. (Tab in a next note that is still empty just ends the typing and takes that empty note away.)
- Tab in a note that was typed in before (not new) does the same: next note beside it.
- Tab on a sticky note that is only chosen (not typed in) does nothing new.
- Making a next note is one step for Undo; the words typed before it are their own step, as always.

**b. The bar above the screen keyboard (iPhone, iPad).** Up to 0.4 it showed only "Done" for a note and a shape. Now:
- Sticky note: one button **Next note** (iPad) / **Next** (iPhone, narrower than 520 points), in the notes colour, mark `nextNote`; it does what Tab does (a.). Then Done at the right, as before.
- Shape: one button **Next shape** (iPad) / **Next** (iPhone), in the shapes colour, mark `nextShape`; it does what Tab does on a real keyboard: the next shape in the direction the flow runs, already joined by its arrow.
- Same look as the three idea buttons (30 high, soft plate, mark 17 and a word). VoiceOver reads "Next note" / "Next shape".
- So that the screen keyboard stays up from one note to the next (as it does for ideas), all sticky notes share one typing field on iPhone and iPad, and all shapes share one.

**c. The Mac: two clicks on empty board always make a sticky note there.** Before: only when nothing was chosen before the first click (so right after typing a note it took three clicks). Now: the first click un-chooses, the second (within 0.42 s) makes the note at that spot, whatever was chosen before.

**Not built (as the brief says):** d — two presses on empty board on iPhone and iPad still show the whole board.

## Pick 11 — turn a thing into another kind (finding 3, a to d)

**a. "Turn into".** A list with up to four lines: **Sticky note**, **Box**, **Text**, **Idea** (the kind a single chosen thing already is, is left out; with several chosen, every kind at least one of them can become is listed, and the things that already are that kind stay as they are).
- Where: in the menu of a thing (right-click on the Mac, press and hold on iPhone and iPad) as the line "Turn into" with its list; in the menu of several chosen things; and in the bar beside the chosen thing(s) behind the "…" button. The bar now always has a "…" (More) when something can be turned; before, "…" only showed when the bar was too narrow.
- What can be turned: sticky notes, texts, all flow shapes, ideas. Not frames, pictures, sketches, doors.
- What stays: the words, the To do tick, the middle of the thing (its place), the arrows, and the colour:
  - into a sticky note: the same paper when sticky notes have that colour (yellow, pink, blue, green, orange, purple); teal becomes green, red becomes pink, grey and "no colour" become yellow. An idea brings its branch's colour.
  - into a box: the same colour; into a text: the same colour name is kept (a text shows no colour).
  - into an idea: it becomes the middle idea of a small map of its own (a lone idea); a middle idea shows no colour.
- The new thing has its kind's own size (a note 150 × 110, a box 150 × 56, growing with its words as always); a shape turned into a Box keeps the size the owner gave it (the same rule as the Shape plate).
- An idea turned into something else leaves its map; the ideas under it move up to the idea it hung under and take its place among the sisters (main branches stay on its side of the map).
- The middle idea of a map that has branches cannot be turned (no "Turn into" for it); "Break into notes" is the way for a whole map.
- One step for Undo. The things stay chosen.

**b. Drag a sticky note, a box or a text onto an idea.** While ONE chosen sticky note, plain Box or text is dragged over an idea, that idea wears the dashed green frame (the one a dragged map shows). Let go: the thing goes back to where the drag began for a moment and becomes an idea under that idea, after the ideas already there. Words, To do tick and arrows stay.
- Dropped on the middle idea it is a new main branch: it keeps its colour when branches have that colour (pink, orange, teal, blue, purple, green, red); a plain yellow note or a box without colour takes the next free branch colour. Dropped on any other idea it follows that branch's colour.
- A line at the bottom says **Now an idea** with an **Undo** button, for 6 seconds (the same line as "Made its own map").
- The hand feels it (`Feel.setDown()`).
- Only one thing at a time; a diamond, a round box and the other shapes are not turned by dragging (they lie on top, as before).
- One step for Undo.

**c. "Make a mind map".** With two or more sticky notes or texts among the chosen things, the bar has the button **Make a mind map** (mind map mark; with its words on the Mac and iPad when there is room), and the menu of several things has the line "Make a mind map".
- It opens a small question: title **The middle idea**, the line "The 4 chosen notes become the branches of one mind map round it." (with the real number), one field filled in with the board's name, **Cancel** and **Save** (Return is Save, Escape is Cancel).
- Save: the notes and texts become the main branches of ONE new mind map, in reading order (row by row from the top, each row from the left). The middle idea stands in the middle of where the notes lay. An empty field gives the middle idea "Ideas". More than four main branches: branches on both sides.
- Notes that lie in a frame that has a name hang under a main branch that carries the frame's name (in reading order inside it); that branch stands where the frame is in reading order. A frame that was chosen too and held nothing but these notes goes away; a frame that was not chosen, or holds other things, stays.
- A main branch keeps its note's colour when branches have that colour; a yellow note takes the next free branch colour.
- Words, To do ticks and arrows stay. Other chosen things (shapes, pictures, ideas) are not touched.
- One step for Undo. Afterwards the middle idea is chosen and in sight.

**d. "Break into notes".** In the menu of an idea (right-click / press and hold): **Break into notes**. The idea and every idea under it become sticky notes in one column: the top left corner where the idea stood, 16 points apart, in the order of the list (an idea, then those under it), each 150 wide and as high as its words need (110 or more), in the paper of the branch's colour (teal → green, red → pink, the middle idea → yellow). To do ticks and arrows stay. The rest of the map closes up. The notes are chosen afterwards. One step for Undo. Works on a middle idea too (the whole map becomes notes).

## Pick 12 — sort a pile of notes (finding 4, a to d)

**a. Colour for several.** With several things chosen and at least one that carries a colour (sticky note, shape, frame, an idea of a branch), the bar has **Colour** (the palette mark) — it opens the row of colour dots under the bar, as for one thing — and the menu of several things has the line "Colour" with the dots.
- The dots: when a sticky note is among them, the six papers (yellow, pink, blue, green, orange, purple); otherwise all nine colours; "No colour" first when all are shapes.
- The ring is on a dot only when ALL chosen things show that colour.
- One press colours every chosen thing that carries a colour (an idea: its whole branch); texts, pictures and sketches are left alone. One step for Undo.

**b. "Tidy".** With three or more sticky notes, shapes or texts among the chosen things, the bar has **Tidy** (mark `tidy`), after Same size; the menu of several things has "Tidy" after Same size.
- The pile becomes a neat grid where it lies: the top left corner of the pile stays; 16 points between the things; at most 5 side by side, and the rows are filled evenly (6 things lie 3 and 3; 7 lie 4 and 3; 11 lie 4, 4 and 3); reading order is kept. Every column is as wide as its widest thing, every row as high as its tallest.
- Frames, pictures, sketches and mind maps among the chosen things stay where they are. One step for Undo.

**c. "By colour".** Behind the bar's "…" and in the menu of several things (after Tidy), from three sticky notes, shapes or texts: **By colour** (mark `byColour`). One column per colour, the columns in the order of the colour dots (for notes only: yellow, pink, blue, green, orange, purple; otherwise pink, orange, teal, blue, purple, green, yellow, red, grey; things without a colour last), each column in reading order, 16 points between the things and between the columns, the top left corner of the pile stays. One step for Undo.

**d. "Choose all of this colour".** In the menu of ONE sticky note: **Choose all of this colour** — every sticky note of the board with the same paper is chosen (the board is not changed).

**Not built (as the brief says):** e — names for colours.

## The bug — pasted paragraphs became a mind map (finding 8)

- Words from elsewhere (Paste ⌘V, the menu's Paste, words dragged in from another app, the Shortcuts action "New board from text") are a list only when (a) at least one line begins like a list — a list mark (- * + • – ◦), a number ("1." or "1)"), a letter with a bracket ("a)"), a tick box ("[ ]", "[x]"), a heading mark ("#"), or an indent (a tab, or two spaces or more) — or (b) every line is short: 80 letters at most. A list becomes a mind map, as before.
- Anything else with two lines or more (paragraphs) is now ONE Text thing with its lines kept (a text wraps at 360 points). Before: a mind map called "Ideas" with whole paragraphs as branches.
- One line is one sticky note, as before.
- With one idea chosen nothing changed: the lines hang under it.
- More → "Paste a list as a mind map" (and Board ▸ Paste a List as a Mind Map, ⇧⌘V) always makes a map from two lines or more, paragraphs too.

## Launch words (for pictures; `-sampleData` last)

- `-makeMap` — with `-pickAll <words>`: opens the question "The middle idea".
- `-think <step>` — does one step with what `-pick` / `-pickAll` chose, 0.8 s after the board shows: `tidy`, `byColour`, `map` (Make a mind map with the board's name), `note` | `box` | `text` | `idea` (Turn into), `break` (Break into notes), `sameColour` (Choose all of this colour), `next` (types in the picked sticky note and makes the next note).
- Already there and useful here: `-pickAll "good thing,bad thing"` on `-board Spain` (four notes in two named frames), `-more` (opens the bar's "…" list), `-colours` (opens the colour dots), `-menu` (opens the menu of what is picked).

## New identifiers

- Bar: `sel.tidy`, `sel.colour` (now also for several), `sel.makeMap`, `sel.turn` and `sel.byColour` (behind `sel.overflow`), `sel.turn.note`, `sel.turn.box`, `sel.turn.text`, `sel.turn.idea`; the dots for several keep `colour.<name>` and `colour.none`.
- Menus: `menu.turn` (+ `menu.turn.note|box|text|idea`), `menu.tidy`, `menu.byColour`, `menu.colour` (several; its dots `menu.colour.<name>`), `menu.makeMap`, `menu.sameColour`, `menu.breakNotes`.
- The question: `makeMap.field` (the buttons are found by their words, Cancel and Save, as in "Name of the board").
- Keyboard bar: `board.key.nextNote`, `board.key.nextShape`.

## Marks

Used from the groundwork's stand-ins: `nextNote`, `nextShape`, `turnInto`, `tidy`, `byColour`, `breakNotes`. "Make a mind map" uses the mind map mark, "Choose all of this colour" the select-all mark, Colour the palette. No further mark wanted.

## Stored data

Nothing new is stored. No new field, no new kind; the format stays 5.

## Tests

- Rule tests: `Core/Tests/SeedboardCoreTests/Thinking05Tests.swift`, 11 tests (next note; turn into; an idea leaves its map; a note dropped on an idea; make a mind map; break into notes; colour for several; tidy; by colour; choose all of this colour; paragraphs stay one text). All 305 rule tests pass.
- Screen test (written, compiles for the Mac, NOT run): `UITests/ThinkingUITests.swift` — two notes of "Summer cabin" chosen, "Make a mind map" (in the bar, or behind "…" on a narrow screen), the field holds "Summer cabin", Save, the count goes from "12 ideas · 5 shapes · 2 notes" to "15 ideas · 5 shapes".

## Where the code is

- New: `Core/Sources/SeedboardCore/Thinking.swift` (all rules), `App/Sources/Thinking.swift` (the session's steps, the bar and menu pieces, the question, the keyboard-bar buttons, the launch words), the two test files.
- Small hunks in existing files: `Outline.swift` (`isList` is the new rule; new `hasSeveralLines`, `kindForWords`), `Clip.swift` (`addWords`: one line), Core `Outside.swift` (`Outside.board`: one line), `BoardSession.swift` (two lines at the top of `commitEdit`; one word in `paste`), `CanvasView.swift` (Tab in the field: 2 lines; the drag: 2 lines; two clicks: 1 condition), `MapOrder.swift` (`fieldIdentity`: 2 lines; `keyboardBar`: an `else`), `BarActions.swift` (four one-line calls: `severalBar()`, `withTurnInto`, `severalMenu`, `singleMenu`), `ChosenBar.swift` (the colour row for several; buttons with `drop >= 99` always go behind "…"; `ThinkingHost` on `BoardExtras`).

## Seen running / not seen

- Seen on the Mac (debug build, sample boards): on "Trip to Spain" with the four notes chosen the bar reads "4 chosen · Line up · Even gaps · Same size · Tidy · Colour · Make a mind map · Duplicate · … | To do · Remove"; `-think map` made the map "Trip to Spain" with the branches "Pros" (A good thing ×2) and "Cons" (A bad thing ×2), the two frames stayed (they were not chosen), the list says "7 ideas"; `-think tidy` laid the four notes in one row, 16 apart, at the pile's top left corner.
- NOT seen running: Tab / "Next note" / "Next shape", the keyboard bar (iPhone and iPad), the drag onto an idea, Turn into, Break into notes, By colour, Colour for several, Choose all of this colour, the question page itself, the paste of paragraphs. They are proved by the rule tests and both builds only. The screen test was compiled, not run.

## Left alone on purpose / seen on the way

- The Mac's Board menu (Line Up, Even Gaps, Same Size) did not get Tidy, By Colour or Make a Mind Map: the brief names the bar and the menus only. Easy to add if wanted (three lines in `BoardCommands`).
- `CanvasView.lastTapBare` is still written but no longer read (left in place to keep the hunk small).
- An empty new IDEA that goes away at the end of typing still leaves a step for Undo (0.4 behaviour, not touched); the next NOTE leaves none.
- Words dragged in from another app (`ClipBoard.swift:207`, the `safety` lane's file) look for a free place the size of a sticky note when they are paragraphs; the Text that lands is wider (up to 360). Harmless (it may touch a neighbour); a one-word change if wanted (`Outline.kindForWords(words).defaultSize`).
- The empty board's hint still says "paste a list to get a mind map" — still true.
