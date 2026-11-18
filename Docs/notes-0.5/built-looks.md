# Built: looks — picks 7, 8 and the marks of 16 (18 Nov 2026)

Phase 1 took the pictures; the owner picked: **home page = NEW** (his boards first, the starters in one strip),
**branches = B** (thick to thin, the words sit on the line), **the four to-do marks exactly as built**.
Phase 2 made the picks the real thing: no launch word, the other looks are removed.

## Pick 7 — the home page with his boards first (Mac and iPad; the only home page now)

`App/Sources/HomeView.swift` (the page), `App/Sources/HomeStrip.swift` (the strip's card `StarterStripCard`).

- **Header:** the sprout, "Plant a seed", "Every idea starts on a board." — the green "New board" button at its
  right is gone. The list's "New board" is the one green button.
- **STARTERS** (heading as before, "Edit" at the right as before), then ONE strip that slides sideways: cards
  132 points wide, 8 apart; each card is the starter's small picture (132 × 82) and its name in one line
  (subheadline, medium) — no grey line, no second line (the explanation is the pointer's help text and the screen
  reader's label). The Blank board keeps its quiet plus. A card pressed long has the same menu as before
  (Rename…, Change…, Remove…, Edit starters…). On a 1280-wide Mac window 7 cards show whole and the 8th is cut off
  at the edge, which says "there are more".
- **The Blank board is ALWAYS the first card of the strip**, even when the owner has moved it elsewhere in his
  starters (the chooser and the Starters page keep his own order). Why: on an upright iPad the list can be hidden,
  and then the home page has no green button — the strip's first card is the sure way to a new board, at one press.
  Rule in Core: `StarterShelf.strip` (Looks.swift).
- Measured (window 1280 × 800, sample boards): the starters with their heading take about **150 points** of height
  (0.4: about 360, nine cards in two rows). "PINNED" begins about 265 points under the window's top (0.4: about 475).
  **12 whole board cards** are in sight (0.4: 2 whole, 6 cut off at their pictures).
- **Pinned, Recent, Sent to PARAGON** as before.
- **A board card pressed long (right-click on the Mac)** has the list's own menu, word for word: Rename…, Pin to the
  top / Unpin, Make a copy, Save as a starter…, Colour ▸, Open in PARAGON (a sent board), Remove…. Rename asks
  "Name of the board" (Cancel / Save); Remove asks "Remove “<name>”?" — "It is kept for 30 days in the Removed
  folder." (Remove the board / Cancel). Not seen running (a menu cannot be photographed from outside); it builds.
- Identifiers: new `home.starterStrip` (the strip), `home.heading.Pinned` / `home.heading.Recent` /
  `home.heading.Sent to PARAGON` (the section headings). Kept: `home.starter.<id>` (the Blank board is
  `home.starter.blank`), `home.startersEdit`, `home.board.<title>`, `home.noMatch`, `board.none`.
  **Gone:** `empty.newBoard` (the header's button) — `Docs/SPEC.md` line 31 still names it (texts builder).
- The old home page (two rows of big starter cards) and the launch word `-homeStrip` are removed.
  `HomeUITests` now presses `home.starter.flow` where it pressed `empty.newBoard`.

## Pick 8 — mind-map branches B (the only look now)

`App/Sources/BranchLook.swift` (drawing), rule in Core `Core/Sources/SeedboardCore/Looks.swift`
(`Route.branchWeight(depth:)`, `Route.branchFoot(of:)`, `Route.branchLine(…)`).

- **Thick to thin:** the line to a main branch is 3.4 points, to the second level 2.4, to the third and deeper
  1.8 (0.4: 2.6 everywhere).
- **The words sit on the line:** the branch arrives at the foot of the idea (2 points above the bottom of its box,
  2 points under its words), runs on under the words as an underline in the branch's colour and weight, and the
  ideas under it start from the END of that underline. Lines from the middle idea still leave the middle of its side.
  On the left side of a both-sides map the underline runs the other way (right to left) and the next ideas start
  at its left end.
- Words, press areas, the chosen frame, the to-do mark, the folded idea's count dot and the dashed frame when
  something is dragged onto an idea are where they were. Seen in a picture (Garden year, two ideas chosen): the
  left side's underlines run the right way, the folded "Order seeds" shows its count dot "2" outside its words,
  the chosen frames wrap the words and their underline, the to-do ring sits after "Buy timber". The dashed drop
  frame is the idea's box 6 and 5 points larger, so the underline lies inside it (read in the code, not seen).
- One painter (`CanvasDraw.swift`), so the small pictures, the shared picture and PARAGON's picture draw B too.
- The looks "today" and A and the launch word `-branches` are removed.

## Pick 16 — the to-do marks

`App/Sources/TodoMark.swift`: ONE drawing function `TodoMark.draw(_ state:, at:, radius:, paint:, ground:, &ctx)`,
used by `CanvasDraw`, `TimelineDraw` and `SequenceDraw` in place of the three copies of the old ring.

| State | Mark | Words |
|---|---|---|
| `waiting` — to do, not sent | hollow purple ring (line 1.8), nothing inside | as they were |
| `inParagon` | full purple disc, white tick (as the ONE mark of 0.4) | as they were |
| `done` (read back from PARAGON) | full green disc, white tick | greyed |
| `cancelled` (read back) | full grey disc, white dash | greyed |

- The rule of thumb: **hollow = still only here; full = PARAGON has it, the colour says how it stands.**
- Radius 7.5 on the board, 7 on a timeline row and a "Who does what" message. Colours: purple `#6B4EA8` (the hollow
  ring's line by night `#B59CEB`), green `#2E8B57` (night `#3FA26C`), grey `#8B94A1` (night `#7A818C`). Greyed words:
  the board's faint grey; on a sticky note the dark ink at 45 %.
- A thing shows a mark when it is ticked "to do" OR the board knows it was sent (`board.todoState(of:)`).
- **What changes for a board, before anything is read back:** a to-do that was NOT sent now shows the hollow ring
  instead of the full purple ring with a tick.
- Phase 2: the small pictures (`BoardThumb.swift`) and the shared picture / PARAGON's picture
  (`BoardPicture.swift`) now get the states too (`painter.todoStates = TodoMark.marks(for: fitted)`, one line each),
  so they show the same four marks as the board.

## Launch words (for pictures; `-sampleData` last)

- `-garden` — with `-sampleData`: adds the sample mind map **"Garden year"** (21 ideas, three levels, both sides,
  one to-do "Buy timber", one folded idea "Order seeds"): `-board Garden`. (Phase 1's `-branches` did this.)
- `-marks` — with `-sampleData`: adds the sample board **"To-do marks"** (`-board marks`) and fills `ParagonEcho`
  with made-up states so all four marks show; "Build timeline" (`-board timeline`) and "Loan steps"
  (`-board Loan`) show the four as well.
- `-zoom 1.5` / `-zoom most` — the opened board at that zoom round its middle / as big as it still fits.
- `-window 1280x800` — the Mac window at that size.
- **Trap:** the Mac reads launch words in pairs. A word without a value (`-marks`, `-garden`, `-night`) must stand
  AFTER the pairs (`-board Garden -zoom most -garden -sampleData`).
- Removed: `-homeStrip`, `-branches`.

## Tests

- Rule tests: `Core/Tests/SeedboardCoreTests/Looks05Tests.swift`, 4 tests (thick to thin; the line arrives at the
  foot and runs on under the words; on the left the underline runs the other way; the strip always begins with the
  Blank board). All 298 rule tests pass.
- Screen test: `UITests/HomeStripUITests.swift` — `testTheStartersAreOneStripAbovePinnedAndTheFirstBoardsAreInSight`:
  the starters stand in one row with the Blank board first, the strip is under 160 points high and above "Pinned",
  Pinned above Recent, the first pinned board ("Summer cabin") and the first recent one ("Build timeline") are whole
  inside the window without sliding, `empty.newBoard` is gone, pressing `home.starter.blank` opens a new board.
  It skips on the iPhone (no home page there). Compiled (macOS build-for-testing), NOT run.
- Both builds green (Mac and iOS Simulator).

## Files

New: `App/Sources/HomeStrip.swift`, `BranchLook.swift`, `TodoMark.swift`, `LooksLaunch.swift`,
`Core/Sources/SeedboardCore/Looks.swift`, `Core/Tests/SeedboardCoreTests/Looks05Tests.swift`,
`UITests/HomeStripUITests.swift`.
Changed: `HomeView.swift` (the strip, the card menu, no header button, section heading identifiers — the biggest
hunk), `CanvasDraw.swift` (the branch loop; the to-do mark; greyed words), `TimelineDraw.swift`, `SequenceDraw.swift`
(the mark; greyed words), `BoardPicture.swift`, `BoardThumb.swift` (one line each), `AppModel.swift` (two lines in
`load()`), `UITests/HomeUITests.swift` (the starter press).

## Not built, not seen

- No stored field.
- Not seen running: the iPad and the iPhone (builds only), the card's press-and-hold menu, the dashed drop frame,
  the timeline and "Who does what" with the four marks. Screen tests not run (lead runs them after the join).
- `RootView`'s list menu and the home card's menu are two copies of the same words (not one shared piece).
- Marks wanted: none.

## Drive-by, left alone

- `ParagonEcho.marks(for:)` asks `board.todoState(of:)` for every thing, which itself searches the things: on a
  board of 300 things that is 90 000 steps per redraw. `TodoMark.marks(for:)` keeps the last answer; `CanvasView`
  still asks `ParagonEcho` on every redraw.
- `Docs/SPEC.md` (home page header with `empty.newBoard`, starter cards in two rows, branch line 2.6) is now out of
  date — for the texts builder.
