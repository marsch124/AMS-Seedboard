# Built in the feel lane (0.5) — picks 2, 4, 5, 6 and the eight rough edges (panel-premium-feel 2, 4, 5, 6, 10)

Everything below is what the owner sees or feels, with the exact words and numbers. Rules live in Core
(`Core/Sources/SeedboardCore/FeelRules.swift`) with ONE data test file (`Core/Tests/SeedboardCoreTests/Feel05Tests.swift`,
9 tests). New app files: `EmptyBoard.swift`, `FeelLooks.swift`, `FeelMoments.swift`. One screen test: `UITests/FeelUITests.swift`
(compiles; NOT run — the lead runs screen tests after the join). No stored field added, no new mark needed.

## 2. The hand feels what happens
The eight moments of `Feel.swift` are now called where things happen. iPhone: the Taptic motor. Mac: the trackpad
(guide line = Apple's "alignment" tick; life size and the end = "level change"; set down and joined = a soft generic tick).
iPad has no motor of its own. Nothing is felt while the Pencil draws, nothing for plain buttons, nothing with `-sampleData`.
- **Catch** — a guide line appears while dragging, sizing, or dragging out the "+" of a shape (at most once in 0.12 s; only when a NEW guide appears, not while one stays).
- **Lift** — a shape, note, picture or chosen group starts to move (iPhone: light, 0.6); also an idea after its hold, and a bar on a "Who does what" board (these replace the old direct haptics).
- **Set down** — a map dropped on an idea of another map hangs there; a dragged idea lands under another idea or between two sisters (rigid, 0.7). Nothing when it springs back or is torn off.
- **Joined** — an arrow is made between two shapes (arrow tool, "+" dropped on a shape, two presses); an arrow's end is dragged onto ANOTHER shape (rigid, 0.8). Moving an end round its own shape is not felt.
- **To do on** — "To do" switched on (also for messages on a "Who does what" board). Off is silent.
- **Exactly 100 %** — a pinch (two fingers, an iPad trackpad, the Mac trackpad) passes life size, from either side. Not on a timeline (it has no life size).
- **The end** — a pinch reaches the smallest (20 %) or largest (300 %) zoom, once; pushing on is not felt again.
- **Sent / Not sent** — Send to PARAGON went through (success) / did not (error).

## 4. Buttons show the press; the pointer is noticed
One style, `PressStyle`, on every plain button; three looks:
- **Tile or bar button with its own soft plate** (tool tiles, the Box tile, timeline and "Who does what" tools and bars, the bar beside a chosen thing, shape plate, lanes, Draw plate, the mind map's key bar, the empty board's three buttons): pressed → 95 % size in 0.08 s, springs back in 0.18 s; its own colour is laid over its plate so the tint doubles (6 % → about 12 % by day, 12 % → about 24 % by night); pointer over it (Mac, iPad trackpad) → one step stronger (half of that), in 0.12 s.
- **Button without a plate** (list rows, Home row, Settings, Cancel and Edit words, zoom and Undo buttons, search's clear mark, menu rows, back arrow): pressed → 95 %; pointer over → a 5 % wash, 8 corner.
- **Button with a plate outside its label, or a colour dot** (colour dots, Undo / Bring back / Open pills, the shape corner): pressed → 95 % only. The close mark on the brick-red "kept" bar gets a white 18 % wash.
- **Full-colour main buttons** (`FilledButton`, `ParagonButton` = Send, Save, New board…): pressed they stay solid, 12 % darker, 97 % size — never see-through any more (before: 75 % see-through). One that cannot be pressed yet is the same colour at 50 %.
- **Home cards** (board cards and starter cards): pressed → 97 %. Pointer over → the edge turns boards green at 60 % and the shadow goes from 6 % / radius 2 to 12 % / radius 6, in 0.12 s. On the iPad the cards also take Apple's own "lift" pointer effect.
With Reduce Motion a pressed button does not shrink; it goes to 70 % for the moment of the press instead.

## 5. Send feels like a hand-over
- Send pressed → "Sending…" → on success the Send button shows a white hand-drawn tick on purple for 0.45 s (the button keeps its width), the hand feels success, then the page closes. A failure is felt as an error and the page stays with its red line, as before.
- The line that follows is PARAGON purple (#6B4EA8 day, #7F62C6 night), the white send mark in front, the same words as before ("“Summer cabin” is in PARAGON under Projects."), and a small **Open** pill at its end (white words on white 22 %) that opens the new note in PARAGON. It stays **6 s** (other lines 4 s).
- "Only the to-do boxes" makes no note: the line is purple for 6 s with NO "Open" ("3 on the way to the PARAGON Inbox. They show the next time PARAGON opens.").
- Identifiers: `board.flash` (the words, kept), `board.flashAction` (the "Open" pill), `send.done` (the tick).

## 6. The empty board and the first start invite
- **Empty board** (not a timeline, not "Who does what", Draw tool off): in the middle the sprout mark (40 pt, boards green 70 %), the line **"What is on your mind?"**, under it three buttons in their own colours with mark and word: **Mind map** (pink), **Sticky note** (amber), **Paste a list** (green). 36 high on iPhone / iPad, 28 on the Mac, side by side (one under another if the iPhone is too narrow). "Paste a list" is pale (45 %) while no words are copied — asked without reading the clipboard, so the iPhone shows no paste banner; pressed anyway with nothing copied it says "Nothing to paste." in red. One press does what the tool does; the invitation fades in 0.15 s. The Mac adds the quiet line **"or double-click anywhere for a sticky note"**. While the Draw tool is on the board stays clear. A board from a newer Seedboard (cannot be changed here) shows only the sprout and "An empty board".
  Identifiers: `board.empty` (kept, now a container), `empty.words`, `empty.mindmap`, `empty.note`, `empty.paste`, `empty.hint` (Mac).
- **iPhone with no boards**: instead of the grey line "No boards yet. Press New board." the list shows the sprout (40 pt), **"Plant a seed"**, the small line **"Every idea starts on a board."** and his starters themselves (the home page's starter cards, two in a row). One press makes the first board; they leave when it exists. Mac and iPad keep their home page (and the old grey line in the side list). Identifiers: `boards.first`, `first.starter.<starter id>`.
- **Empty board's card** on the home page: a faint sprout (22 pt, 35 %) instead of the word "Empty".

## 10. The eight rough edges
1. **Send by night**: the Send button in the top bar stands by itself, off the bar's shared glass (iOS 26 / macOS 26 `sharedBackgroundVisibility(.hidden)`), so its purple is its own #7F62C6 by night, not a paler wash. **Not seen on a device by night** — needs one look on iPhone, iPad and Mac.
2. The "not in iCloud" dot is amber always (it was white on the chosen row).
3. The list's colour dots follow day and night, like the cards.
4. The line at the bottom is drawn at the window's level whenever no open board is in sight (home page, the iPhone's list), so **"Board removed. It is kept for 30 days in the Removed folder."** is seen. Inside an open board it stays above the tools. Never both at once.
5. Tones: problems are brick red, PARAGON purple, the rest green. Red now: "Nothing to paste.", "The picture could not be made.", "That could not be read as a picture." / "N could not be read as pictures.", "A picture cannot be put on this board.", "These things were copied in a newer Seedboard. Update the app to paste them.", "This board was made by a newer Seedboard. Update the app to copy it.", "That board is not on this device yet. It opens when it arrives.", "That board could not be brought back: no copy of it is left.", a board that cannot be saved (the save warning), a timeline join that was refused ("These two are joined already.", "A phase is a heading: join the bars under it.", "That would go round in a ring."). Green stay: copied, "is back", starters saved / removed, bars moved along, "Joined. …", "The board's words are copied.", "Board removed. …".
6. Messages arrive by sliding up 8 points and fading in (0.18 s) and leave by fading (0.25 s): the line at the bottom, the Undo notice, the arrow tool's banner at the top.
7. The press-and-hold menu fades in and grows from 96 % (0.12 s); it closes by fading (0.10 s).
8. The small Undo and zoom boxes (also the timeline's zoom box) wear the bar's own shadow (black 10 %, radius 5, 2 down).
All motion is off with Reduce Motion, with `-sampleData` and with `-stillMotion` (things are simply there).

## Launch words (DEBUG pictures; `-sampleData` LAST)
- `-emptyBoard` — opens a new empty board (the invitation). E.g. `-emptyBoard -sampleData`, night: `-emptyBoard -night -sampleData`.
- `-noBoards` — starts with no board at all (the iPhone's first start; on Mac / iPad the home page with no boards).
- `-say good|problem|paragon` — shows the line at the bottom for 60 s in that colour; `paragon` with its "Open" pill. With `-board <word>` it shows inside that board, without it at the window's level.
- `-pressLook over|down` — every button drawn as with the pointer over it / as pressed (cards too).
- `-sendDone` with `-send` — the Send button shows its tick at once.

## Pictures taken (Mac debug build, sample boards)
In `/private/tmp/claude-501/-Users-martinschabbauer-Obsidian-Claude-Code/17034763-8459-4a3b-a9bb-13fd5828f01e/scratchpad/feel/`:
`empty-day.png`, `empty-night.png` (the invitation), `say-paragon.png` (purple line with "Open" in a board), `say-home.png`
("Board removed. …" at the window's level over the home page), `look-over.png`, `look-down.png`, `home-over.png` (pointer and
press looks), `mac-top.png`, `iphone-top.png`, `ipad-night-top.png`. Seen on the Mac: invitation, purple line with Open, the
window-level line.

## What was NOT seen running
- No haptic was felt (needs an iPhone and a Mac trackpad); the iPad's lift pointer effect; Send's colour by night in the top bar on any device; the slide / fade timings on a device. Screen test `FeelUITests` not run.

## Drive-by things seen and left
- The iPhone's line at the window's level sits 54 points above the bottom to clear the list's last row; if the `thumb` lane moves search and "+" to the bottom, that number must follow (`WindowFlash` in `FeelLooks.swift`).
- `Feel.swift`'s catch spacing now asks `FeelRules.mayCatch` (one hunk), so the tested rule is the one that runs.

## Files where the join may clash
`BoardView.swift` (empty-board block replaced, the flash block replaced by `FlashLine()`, toolbar: Send moved into `OffGlassItem`, three `.animation`), `RootView.swift` (window line overlay, `FirstSeeds`, dot colours), `HomeView.swift` (card pointer, empty sprout, card press), `AppModel.swift` (`feelLaunch()`, tones, `sayHandedOver`), `SendSheet.swift` (Send button only), `CanvasView.swift` (haptics), `PressStyle.swift`, `Theme.swift` / `Look.swift` (main buttons), many one-line `PressStyle(tint:)` / `PressStyle(wash: nil)` swaps.
