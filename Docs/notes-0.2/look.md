# Notes for 0.2 — builder "look" (picks 6 and 8)

## 1. What's new

### Pick 6 — calmer colours
- **Send to PARAGON is purple.** Before: the button at the top right was the same solid green as "New board" and the chosen board, so three green blocks fought for the eye. Now: it is PARAGON's purple (#6B4EA8 by day, a lighter #7F62C6 by night), still a full-colour main button with white words. Everything that leads to PARAGON is purple.
- **The chosen board in the list is a soft tint.** Before: a solid green bar with white words and a white dot. Now: a soft green tint (14 % green by day, 20 % by night), the name in bold green, the board's own colour dot kept. "New board" is the only solid green in the list.
- **Starter boards come coloured.** Before: Flow and Plan in steps were all white boxes. Now: in Flow the Start is green, the decision purple, the three steps blue, the "Yes" arrow green and the "No" arrow red; in Plan in steps the five boxes are blue over their yellow notes. Pros and cons keeps its green and red columns with green and pink notes; Mind map keeps its four coloured branches.
- **Shapes lie a little above the board.** Before: flat. Now: by day every box, round box, diamond and oval has a faint shadow (6 % black, 1 point down). None by night.
- **Sticky notes stay bright at night.** Before: at night a yellow note turned olive (#6B5A1E) and a pink one maroon (#6B3048), with light words. Now: all 6 note colours stay bright paper with dark ink at night, only a little dimmer than by day (yellow #D9BC55, pink #D98AA8, blue #86AEDD, green #86C79A, orange #DDA066, purple #B39AE0). The words being typed on a note are dark at night too.
- **All 9 shape, branch and arrow colours were checked by night** (see Spec): every one is readable; none had to change.
- **A ring shows the colour in use.** Before: the colour row gave no hint which colour a thing has. Now: a 2-point ring sits round the dot of the colour in use (also round "No colour").

### Pick 8 — a home page with pictures
- **A home page instead of "Choose a board"** (Mac and iPad). Before: the big area beside the list showed a mark, "Choose a board" and one button — about 80 % empty; on the iPad at night it was pure black beside a charcoal board. Now: a row of 5 starter cards, each with a real small drawing of that starter, its name and its one-line hint; below them the boards as cards under "Pinned", "Recent" and "Sent to PARAGON" — each with the board's small picture, its colour dot, its name and "Changed 2 days ago" in plain words. One press opens a board or starts a new one. The page has the board's own background by day and by night.
- **Search over the boards list** (Mac, iPad, iPhone). Before: none. Now: a "Search boards" field under "New board" finds boards by their name AND by the words written on them (ideas, shapes, notes, text, frames and the words on arrows). Every word typed must be there; upper/lower case and accents do not matter; the start of a word is enough. The cards on the home page follow the search too. Nothing found: one plain line, "No board has these words".
- **iPhone list.** Before: name and "5 shapes · 5 notes". Now: each row also shows the board's small picture at the right, and the second line starts with when it was changed: "Changed 2 days ago · 5 shapes · 5 notes".
- **The big "New board" button offers the starters.** Before: the button on the empty page skipped the choice and made a blank board (the list's own button asked). Now: both open the same choice.
- **The starter choice is cards with drawings.** Before: a list of 5 rows with a small mark each. Now: the same 5 cards as on the home page — 3 in a row in the pop-up on Mac and iPad, 2 in a row on the page that comes up on the iPhone.
- **Small pictures cost nothing after the first time.** Each is drawn once per version of a board (once for day, once for night) and kept in memory. Measured: 12 pictures drawn for 5 starters + 7 boards, and 0 more while the home page, the search, the chooser and the list were shown again and again.

## 2. How it works (guide text)

**The home page (Mac and iPad).** When no board is open you see the home page. On top are the ways to begin — Blank board, Mind map, Flow, Pros and cons, Plan in steps — each as a card with a small drawing of what you get. Press a card and the new board opens. Below are your boards as cards: Pinned first, then Recent, then Sent to PARAGON. Each card shows a small picture of the board, its colour dot, its name and when you last changed it ("Changed yesterday"). Press a card to open the board. The "New board" button at the top right offers the same starters.

**The iPhone.** The list of boards is the home. Every row shows the board's small picture at the right and, under the name, when it was changed and what is on it.

**Finding a board.** Type into "Search boards" above the list. Seedboard looks in the names of your boards and in every word written on them — so "timber" finds the board with the note "Check timber prices in May". Type two words and only boards with both are shown. The round cross at the right of the field (on the Mac also Escape) empties the search and brings every board back. If nothing fits you read "No board has these words".

**New board.** Press "New board" (in the list or on the home page) and pick a card: the drawing shows what the board starts with. Flow and Plan in steps come coloured — change any colour with Colour in the bar.

**Colours.** Press Colour for a chosen shape, note, branch, frame or arrow: the row of colour dots opens and a ring marks the colour it has now. Sticky notes keep their bright paper at night. The purple "Send to PARAGON" button at the top right is the way to PARAGON.

## 3. Spec

### Colours (pick 6)
- `Look.paragonButton`: #6B4EA8 day, #7F62C6 night; white words (contrast 6.4 : 1 day, 4.7 : 1 night). Button style `ParagonButton` (same shape as `FilledButton`: semibold body, padding 12 × 6, corner 8, 50 % when it cannot be pressed). Used by `board.send` in the top bar (`BoardView`). File `App/Sources/Look.swift`.
- `Look.chosenRow`: #2E8B57 at 14 % (day), #5FBF8A at 20 % (night), corner 8. Chosen row: name `.body` bold in `Part.boards.text`, second line `.secondary`, dot in the board's colour (9 pt). Not chosen: unchanged.
- Starters (`Core/…/Starters.swift`): Flow — "Start" (round) `green`, "Decision?" (diamond) `purple`, "Step", "Do it", "Think again" (boxes) `blue`; arrow "Yes" `green`, arrow "No" `red`, the two plain arrows no colour. Plan in steps — 5 boxes `blue`, 5 notes `yellow`, arrows no colour. Pros and cons and Mind map unchanged. Test: every colour a starter uses is in `Palette.names`.
- Shape shadow (`CanvasDraw.drawItem`, kinds box/round/diamond/oval): by day `.shadow(color: black 6 %, radius: 2, x: 0, y: 1)` under the fill only (the outline is drawn without it). By night none. The mind-map centre, notes (own shadow, unchanged), text and frames are not touched.
- Night note paper (`Paint.notes`, second value): yellow #D9BC55, pink #D98AA8, blue #86AEDD, green #86C79A, orange #DDA066, purple #B39AE0. Ink on a note is `Paint.noteInk` (0.12, 0.14, 0.19) by day and by night — in the drawing and in the field while typing (`CanvasView.itemField`, `darkInk = true`). Contrast of the ink on the night papers: 6.0 : 1 (pink) to 8.3 : 1 (yellow).
- Night check of the 9 palette colours (pink, orange, teal, blue, purple, green, yellow, red, grey), unchanged values: light ink on the tinted shape fill 9.3–11.6 : 1; outline/branch/arrow colour on the board 7.4–11.1 : 1; outline on its own fill 5.5–6.7 : 1.
- Colour row ring (`InUseRing`, `Look.swift`): `Circle().stroke(Color.primary 85 %, lineWidth: 2)` round the 22 pt dot with a 3 pt gap (32 pt across in all), takes no room of its own; the dot also gets the "selected" trait for VoiceOver. Which colour is in use is the Core rule `Board.colourInUse(of:)`: a shape or arrow its own colour ("" = No colour), an idea its branch's colour, a plain note `yellow`, a plain frame `teal`.

### Home page (pick 8)
- `HomeView` (`App/Sources/HomeView.swift`) is the detail of the window when no board is open (it replaces `NoBoard`; identifier `board.none` kept, with its children contained). Background `Paint(scheme).canvas`, ignoring safe areas. Content: padding 16 × 12, at most 1120 pt wide.
- Header: sprout mark 30 pt, "Start a thought" (`Txt.big`), "Every idea starts on a board." (`Txt.label`, secondary); at the right the full-colour green "New board" button, identifier `empty.newBoard` (kept) — opens `StarterPicker` as a pop-up (regular width) or a page from the bottom (compact width).
- Cards lie in a grid of columns 150–210 pt wide, 10 pt apart. Card: plate `Paint.plate`, edge `Paint.edge` 1 pt, corner 11, by day the same faint shadow as a shape; picture on top (1.6 : 1), a 1 pt edge line, words below with padding 8 × 6.
  - `StarterCard`: picture of the starter's own board (`Thumbs.board(of:)`), name (`.body` medium, 1 line), hint (`.caption`, secondary, 2 lines reserved). The empty starter shows a quiet green plus (26 pt). Identifier on the home page `home.starter.<rawValue>`; in the chooser `starter.<rawValue>` (kept).
  - `BoardCard`: picture, 9 pt colour dot + name (`.body` medium, 1 line), `board.changedWords()` (`.caption`, secondary). An empty board's picture says "Empty". Identifier `home.board.<title>`.
- Sections: "PINNED", "RECENT" (not pinned, not sent), "SENT TO PARAGON" (purple) — the same three groups and heading style as the list. With a search, the cards are the found boards; nothing found → "No board has these words" (identifier `home.noMatch`).
- `StarterPicker` (same file; replaces the old list of rows in `RootView.swift`): heading "Start with", the starter cards in a grid inside a scroll view. Pop-up: 3 cards per row, each 150 pt (Mac) / 160 pt (iPad) wide, 8 pt apart; the pop-up's size is worked out from the number of starters (5 starters → 2 rows; 486 × 360 pt on the Mac). iPhone page: columns 150–240 pt (2 per row), detents 78 % of the screen and full height. It has no per-starter switch any more: a new `Starter` case appears by itself.
- iPhone row (`BoardList.row`, when the window is compact — `phone: true`, decided in `RootView` from the window's own size class): second line `"<changedWords> · <countLine>"`, at the right `RowPicture` (60 pt wide, 1.6 : 1, corner 6, 1 pt edge). Mac and iPad rows keep `countLine` only and no picture.

### Small pictures
- `Thumbs` (`App/Sources/BoardThumb.swift`): draws a board with `BoardPainter` (no handles) into 240 × 150 pt at 2× (480 × 300 pixels) on `Paint.canvas`, the whole board centred with 12/10 pt room, never bigger than 60 % of its real size. Lettering is fitted first, as for the PARAGON picture.
- Kept in memory only (`NSCache`, at most 160 pictures or 48 MB). Key: the board's identity (or `starter.<rawValue>`) + day/night; the entry carries the board's `changed` time — a different time means a new picture, which replaces the old one. `Thumbs.drawn` counts real drawings.
- `BoardThumb` (the view) reads the kept picture while drawing the page; when there is none it draws it in a `.task` after the page is up and shows the previous picture meanwhile. Hidden from VoiceOver.

### Search
- `SearchField` (`HomeView.swift`), under "New board" in `BoardList`: search mark (`Glyph.new(.search)`, 16 pt, green), plain field "Search boards" (identifier `boards.search`), clear button (round cross, identifier `boards.searchClear`, only when not empty); background primary 6 %, corner 8, padding 8 × 5. iPhone/iPad: no auto-capitals, no auto-correction, Search key. Mac: Escape empties it.
- The text lives in `RootView` (`@State search`) and is given to the list and to the home page. Not stored.
- Rule (Core, `Home.swift`): `BoardSearch.find(_ query:in:)` / `Board.holds(_:)`. The query is cut into words at spaces; a board is found when EVERY word is contained in `readableText` = the title + every item's text + every arrow's text. Compared without case and without accents; a word may be part of a longer word. An empty query finds every board; the order of the boards is kept.
- List: the three sections show the found boards; nothing found (and there are boards) → "No board has these words" (identifier `boards.noMatch`).

### "Changed …" in plain words
- Rule (Core): `Board.changedWords(now:calendar:)` = "Changed " + `Board.ago(from:to:calendar:)`: under 1 minute or ahead of now → "just now"; under 60 minutes → "1 minute ago" / "N minutes ago"; same calendar day → "1 hour ago" / "N hours ago"; 1 day → "yesterday"; 2–6 days → "N days ago"; 7–13 → "last week"; 14–59 → "N weeks ago"; 60–364 → "N months ago" (days / 30); then "a year ago" / "N years ago".

### Stored fields
- None added, format untouched. New boards made from Flow and Plan in steps simply carry colour names that 0.1 already knows.

### Tests
- Core, new file `HomeTests.swift`, 4 tests: search by name and by words; changed words; starters come coloured; colour in use. Core now runs 94 tests (was 90), all green.

### Identifiers (new)
`boards.search`, `boards.searchClear`, `boards.noMatch`, `home.starter.<rawValue>`, `home.board.<title>`, `home.noMatch`. Kept: `board.none`, `empty.newBoard`, `boards.new`, `starter.<rawValue>`, `boards.row.<title>`, `colour.<name>`, `colour.none`, `board.colours`, `board.send`.

## 4. For the lead

- **Launch arguments for pictures:** plain `-sampleData` shows the home page on Mac and iPad (7 boards as cards, 5 starter cards) and the list with pictures on the iPhone. New: `-search <word>` fills the search field (e.g. `-search timber` → only "Summer cabin"; `-search zzz` → "No board has these words"). Coloured starters: `-board Packing` (Flow) and `-board Garage` (Plan in steps). Night notes: `-board Summer -night`. The ring: `-board Summer -pick Worth`, then press Colour (no launch option opens the colour row — it is state inside the selection bar, which is another builder's).
- **Screen test:** `UITests/HomeUITests.swift`, one test (`testHomeShowsCardsAndSearchFindsABoardByAWordOnIt`): starter and board cards on the home page (Mac/iPad), "timber" finds "Summer cabin" and hides "Trip to Spain", "No board has these words", clear brings all back, the home page's New board opens the starters. Written and compiled (`build-for-testing` on the Mac: succeeded), not run.
- **Merging:**
  - `RootView.swift`: `NoBoard` and the old `StarterPicker` are deleted (now `HomeView` / `StarterPicker` in `HomeView.swift`). If another builder added a case to the old picker's `mark(_:)` / `part(_:)` switches, drop those lines — the cards need none. `BoardList` got two new arguments (`search:`, `phone:`). In `row`, my lines are: the dot's fill, the name's weight + colour, the second line's text + colour, `if phone { RowPicture… }` after the `Spacer`, the removed `.foregroundStyle(chosen ? white : primary)` and the background. The "not in iCloud yet" dot fits anywhere in the `HStack` (best right after the name's `VStack`, before the `Spacer`).
  - `CanvasDraw.swift`: three hunks — the night values of `Paint.notes`, `Paint.noteInk` (new static) used for the note's words, and `var body = ctx` + shadow before the shape's fill in `drawItem` (the B7 builder's diamond change is in `Lettering.fit`, not here).
  - `CanvasView.swift`: one line (`darkInk = true`). `BoardView.swift`: the Send button's style (1 line) and the ring in `colourRow` (3 lines). `Starters.swift`: 4 small hunks in `.flow` and `.steps`.
- **Timeline and other new kinds of board:** the small pictures are drawn in ONE place, `Thumbs.draw` in `BoardThumb.swift`, with `BoardPainter`. If a timeline (or sequence) board is drawn by its own painter, call it there, otherwise its card shows only what `BoardPainter` draws. The search reads `items` and `links` — a new kind that keeps its words elsewhere (bars, messages) must be added to `Board.readableText` in `Core/…/Home.swift`.
- **ICON-WANTED:** none new. `Glyph.new(.search)` is used (stand-in `seedFit` until the magnifying glass is drawn). The clear button uses the library's existing `closeCircle`; the empty starter's plus the existing `add`.
- **Left open — needs a decision:**
  1. There is no way back to the home page on Mac and iPad once a board is open (as in 0.1, where the empty page was only seen at launch). Recommended: a small "Home" row on top of the list (sprout mark) that closes the open board — `model.open(nil)` already does it. Not built: it was not in the brief and changes how the list is used. Pick 26 (reopen the last board) would make the home page even rarer without it.
  2. Board cards on the home page have no press-and-hold menu (Rename, Pin, Colour, Remove) — those stay in the list. Easy to add once pick 18 (menus) is merged.
  3. On the iPhone the search field sits under "New board", above the list — the same order as on Mac and iPad.
- **Checked without the app:** I drew the home page, the list (chosen row, iPhone rows, search, no result), the starter chooser (pop-up and iPhone page), the three coloured starters, all palette colours and the colour row by day and by night with the app's own views in a faceless helper tool (no window on screen, no simulator). What that cannot show and only the real app / a real device can prove: the purple Send button inside the real top bar (Mac toolbar, iPad and iPhone glass bar); the pop-up's arrow and size on the iPad; the height of the starter page on a small iPhone (it scrolls if 3 rows do not fit); whether the Mac puts the cursor into the search field at launch (harmless: an opened board takes the keys itself); scrolling feel of the home page with 50+ boards; Dynamic Type at the largest sizes on the cards (the hint is cut after 2 lines).
