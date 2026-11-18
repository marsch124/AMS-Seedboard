# Built: looks — Phase 1 (pictures first), 18 Nov 2026

Picks 7 and 8 and the marks of pick 16. Phase 1 only: the variants are behind launch words, the owner picks
from the pictures, then the picked ones become the real thing (Phase 2 — not done yet).

## The pictures (Mac debug build, window 1280 × 800, sample boards)

All in `/private/tmp/claude-501/-Users-martinschabbauer-Obsidian-Claude-Code/17034763-8459-4a3b-a9bb-13fd5828f01e/scratchpad/pics/`:

| Picture | Launch words (before `-sampleData`) | What it shows |
|---|---|---|
| `home-today.png` | *(none)* | The home page as in 0.4: 9 starter cards in two rows, his boards begin below the middle; two green "New board" buttons. |
| `home-new.png` | `-homeStrip` | Starters as one strip, Pinned and Recent in sight at once, one green button. |
| `branches-today.png` | `-branches today -board Garden -zoom most` | The sample mind map "Garden year", every branch 2.6 points. |
| `branches-A.png` | `-branches A -board Garden -zoom most` | The same map, thick to thin. |
| `branches-B.png` | `-branches B -board Garden -zoom most` | The same map, thick to thin and the words on the line. |
| `marks.png` | `-board marks -zoom most -marks` | The four to-do marks on a shape, a sticky note and an idea, by day. |
| `marks-night.png` | `-board marks -zoom most -night -marks` | The same by night. |

Every picture was looked at: nothing is cut off, all words read.

## Launch words (new)

- `-homeStrip` — the new home page (without it the home page is exactly as in 0.4).
- `-branches A` / `-branches B` — the two new branch looks (any other word, e.g. `-branches today`, keeps 0.4's look).
  With `-sampleData` the word also adds the sample mind map **"Garden year"** (21 ideas, three levels, both sides,
  one to-do): `-board Garden`.
- `-marks` — with `-sampleData`: adds the sample board **"To-do marks"** (`-board marks`) and fills `ParagonEcho`
  with made-up states so all four marks show; the sample timeline (`-board timeline`) and "Loan steps"
  (`-board Loan`) show the four as well.
- `-zoom 1.5` — the opened board at that zoom round its middle; `-zoom most` — as big as the whole board still fits.
- `-window 1280x800` — the Mac window at that size.
- **Trap:** the Mac reads launch words in pairs. A word without a value (`-marks`, `-homeStrip`, `-night`) must stand
  AFTER the pairs (`-board marks -marks -sampleData`); `-marks -board marks` brings up no window at all.

## Pick 7 — the home page with his boards first (`-homeStrip`)

`App/Sources/HomeStrip.swift` (new): `HomeStripPage`, `StarterStripCard`.

- **Header:** the sprout, "Plant a seed", "Every idea starts on a board." — the green "New board" button at its right
  is gone. The list's "New board" is the one green button.
- **STARTERS** (heading as today, "Edit" at the right as today), then ONE strip that slides sideways: cards
  132 points wide, 8 apart; each card is the starter's small picture (132 × 82) and its name in one line
  (subheadline, medium) — no grey line, no second line of explanation (the explanation is the pointer's help text and
  the screen reader's label). The Blank board keeps its quiet plus. A card pressed long has the same menu as today
  (Rename…, Change…, Remove…, Edit starters…). On a 1280-wide Mac window 7 cards show whole and the 8th is cut
  off at the edge, which says "there are more".
- Measured in the two pictures (window 1280 × 800): the starters with their heading take about **150 points** of
  height (0.4: about 360, nine cards in two rows). "PINNED" begins about 265 points under the window's top
  (0.4: about 475). **12 whole board cards** are in sight (0.4: 2 whole, 6 cut off at their pictures).
- **Pinned, Recent, Sent to PARAGON** as today.
- **A board card pressed long (right-click on the Mac)** has the list's own menu, word for word: Rename…, Pin to the
  top / Unpin, Make a copy, Save as a starter…, Colour ▸, Open in PARAGON (a sent board), Remove…. Rename asks
  "Name of the board" (Cancel / Save); Remove asks "Remove “<name>”?" — "It is kept for 30 days in the Removed
  folder." (Remove the board / Cancel). Not seen running (a menu cannot be photographed from outside); it builds.
- New identifier: `home.starterStrip` (the strip). Kept: `home.starter.<id>`, `home.startersEdit`,
  `home.board.<title>`, `home.noMatch`, `board.none`. **Gone in this look:** `empty.newBoard` (the header's button).

To decide with the owner: on an upright iPad the list can be hidden, and then no green button is on the home page;
a new board is still one press away (the strip's first card, "Blank board").

## Pick 8 — mind-map branches (`-branches A` / `-branches B`)

`App/Sources/BranchLook.swift` (new): `BranchLook.today / .weights / .onLine`, `weight(depth:)`, `path(…)`.

- **A — thick to thin:** the line to a main branch is 3.4 points, to the second level 2.4, to the third and deeper
  1.8 (0.4: 2.6 everywhere). Nothing else changes.
- **B — A, and the words sit on the line:** the branch line arrives at the foot of the idea (2 points above the
  bottom of its box, which is 2 points under its words), runs on under the words as an underline in the branch's
  colour and weight, and the ideas under it start from the END of that underline. The lines from the middle idea
  still leave the middle of its side. Words, press areas, the chosen frame, the to-do mark and the folded dot are
  where they were.
- Same painter as the live board, so the small pictures, the shared picture and the picture for PARAGON follow.

## Pick 16 — the to-do marks (built for real, no launch word)

`App/Sources/TodoMark.swift` (new): ONE drawing function `TodoMark.draw(_ state:, at:, radius:, paint:, ground:, &ctx)`,
used by `CanvasDraw`, `TimelineDraw` and `SequenceDraw` in place of the three copies of the old ring.

| State | Mark | Words |
|---|---|---|
| `waiting` — to do, not sent | hollow purple ring (line 1.8), nothing inside | as they were |
| `inParagon` | full purple disc, white tick (as the ONE mark of 0.4) | as they were |
| `done` (read back from PARAGON) | full green disc, white tick | greyed |
| `cancelled` (read back) | full grey disc, white dash | greyed |

- The rule of thumb: **hollow = still only here; full = PARAGON has it, the colour says how it stands.**
- Radius 7.5 on the board, 7 on a timeline row and a "Who does what" message, as before. Colours: purple
  `#6B4EA8` (the hollow ring's line by night `#B59CEB`), green `#2E8B57` (night `#3FA26C`), grey `#8B94A1`
  (night `#7A818C`). Greyed words: the board's faint grey; on a sticky note the dark ink at 45 %.
- A thing shows a mark when it is ticked "to do" OR the board knows it was sent (`board.todoState(of:)`), so a sent
  branch's ideas carry the full purple mark too.
- **What changes for a board today, before anything is read back:** a to-do that was NOT sent now shows the hollow
  ring instead of the full purple ring with a tick (visible in every picture, also `branches-today.png`).
- The timeline and "Who does what" painters ask `TodoMark.marks(for: board)` themselves (what the board knows +
  `ParagonEcho`), worked out once per change, so no new field was added to `TimelinePainter` / `SequencePainter`.
- Not done here: the shared picture, the picture for PARAGON and the small pictures do not hand `todoStates` to
  `BoardPainter`, so on an ordinary board they show "sent" things only as far as `item.todo` says (hollow ring).
  One line (`painter.todoStates = TodoMark.marks(for: board)`) in `BoardPicture.swift` / `BoardThumb.swift` would
  fix it — those files belong to other lanes.

## Files

New: `App/Sources/HomeStrip.swift`, `BranchLook.swift`, `TodoMark.swift`, `LooksLaunch.swift`.
Small hunks: `HomeView.swift` (the body chooses the look; `CardPlate` is no longer private), `CanvasDraw.swift` (the
branch loop; the to-do mark; greyed words), `TimelineDraw.swift` (the mark in the name column; greyed name),
`SequenceDraw.swift` (the mark on a message; greyed words), `AppModel.swift` (two lines in `load()`).

## Not built, not seen

- Phase 2 (after the owner's picks): the picked looks without launch words, the others removed, the screen test that
  locks the pick, `RootView`'s menu and the card's menu from one shared piece.
- No stored field, no Core rule, so no new rule test. No screen test yet (Phase 2).
- Not seen running: the iPad and the iPhone (builds only), the card's press-and-hold menu, the timeline and
  "Who does what" with the four marks (they build and use the same drawing; no picture was taken).
- Marks wanted: none.

## Drive-by, left alone

- `ParagonEcho.marks(for:)` asks `board.todoState(of:)` for every thing, which itself searches the things: on a
  board of 300 things that is 90 000 steps per redraw. `TodoMark.marks(for:)` keeps the last answer; `CanvasView`
  still asks `ParagonEcho` on every redraw.
