# Built: thumb — pick 31, the thumb row

18 Nov 2026. Branch `wt-thumb`. Phase 1 put the new layout behind a launch word for two pictures; Martin picked
the NEW layout (search and the round green "+" at the bottom; the app's own row on every iOS version; "Settings"
and the version stay the last line). Phase 2 (this file) makes it THE iPhone layout. There is no launch word.

## What is built — what Martin sees

**On the iPhone only** (the iPhone itself, in its narrow layout). **Mac and iPad are exactly as in 0.4**: there the
green "New board" button and the "Search boards" field stay at the top of the list, also in a narrow iPad window.

- The green **"New board"** button and the **"Search boards"** field are no longer at the top of the boards list.
  The list (Pinned, Recent, Sent to PARAGON) starts right under the title "Seedboard".
- At the **bottom**, between the last board row and the line with "Settings" and the version number, sits ONE
  row, the thumb row:
  - a thin dividing line over the row (it takes the place of the line that was over "Settings");
  - left: the search field, **44 points tall**, round at both ends (a capsule), the faint grey ground of the old
    field (6 % of the text colour), the hand-drawn green magnifier (18 points) and the same words
    **"Search boards"**. A press anywhere on the field starts typing (not only on its words). When something is
    typed, the hand-drawn round "x" (19 points) at its right end empties it, as before;
  - right, 10 points beside it: a **round "+" button, 44 points across, in the boards' full green**
    (`Part.boards.fill`), with the white hand-drawn plus (22 points). It has no words; VoiceOver reads
    "New board". Pressed, it gets 12 % darker and 97 % of its size (never see-through);
  - room around the row: 12 points left and right, 8 above, 4 below (8 below while typing, over the keyboard).
- **"+"** opens the same page "New board" opened before: the Starters page coming up from the bottom
  (same heights, same choices, same result — the new board opens). It also works with the keyboard up
  (the keyboard goes away and the Starters page comes up).
- **Search** works as before (the same words find the same boards, the same line "No board has these words").
- **While typing in the search**, the keyboard comes up and the thumb row rides on top of it, so the field and
  "+" stay in reach; the "Settings" line steps aside for that time and comes back when typing ends
  (Search key on the keyboard, or the keyboard goes away).
- **"Settings" and the version number** stay the very last line of the page.
- **An empty list** (no boards at all) now says **"No boards yet. Press + below."** on the iPhone
  (Mac and iPad keep "No boards yet. Press New board."). Only the words changed here; the `feel` lane replaces
  the iPhone's empty list with starter cards — at the join its version wins, only the words matter.
- **Night:** the field's ground is a faint grey on black, the "+" keeps the boards' green, the line over the row
  is the night line (seen).
- With the 12 sample boards all 12 rows fit on the iPhone 18 Pro above the row (before: 11 and a cut 12th).

## Launch words

- None new; `-thumbRow` is gone. For pictures: `-sampleData` (the row is always there on the iPhone),
  `-search cabin -sampleData` fills the field at the bottom, `-night -sampleData` for the night look.

## Identifiers

- `boards.thumbRow` — the row (a container; its children stay findable).
- `boards.new` — the round "+" on the iPhone (on Mac and iPad: the green "New board" at the top, as before).
- `boards.search`, `boards.searchClear` — the field and its "x" (the same identifiers on every device).
- Existing screen tests that press `boards.new` (Draw, Typing, Bar, Timeline, Touch, Shapes, Seedboard) or type
  into `boards.search` / press `boards.searchClear` (Home) find them unchanged: same identifiers, and "+" opens the
  same Starters page with the same `starter.*` identifiers. Checked by reading, not run.

## Screen test

- NEW `UITests/ThumbUITests.swift`, `testSearchAndPlusSitUnderTheThumbOnTheIPhone` (iPhone only; skipped on
  iPad and Mac). It locks his pick: `boards.search` and `boards.new` lie in the lower quarter of the screen, wholly
  above the "Settings" line (`boards.settings`), the "+" right of the field and at least 44 points; no board row in
  sight starts below them; after a press on the search the "Settings" line is gone and, when an on-screen keyboard
  shows, the field and "+" sit above it and "+" can be pressed. **Run once on "Seedboard iPhone 18 Pro": passed
  (19 s).**

## Code

- `App/Sources/ThumbRow.swift`: `ThumbRow` (with `onThisDevice` = the iPhone itself), `ThumbSearchField`
  (tells the list when it is typed in), `RoundFilledButton`, `View.goneWhile(_:)`. `LaunchOptions.thumbRow` removed.
- `App/Sources/RootView.swift`, small hunks in `BoardList`: `thumbRow` (= `phone` and the iPhone itself) and
  `searching`; `if !thumbRow {` … `}` around the old "New board" button and search field (lines inside NOT
  re-indented); the empty-list words; `ThumbRow(…)` in place of the `Divider()` over the Settings line;
  `.goneWhile(thumbRow && searching)` on the Settings line.
- No stored field, no new rule (so no new data test), no new mark, nothing in `project.yml`.

## Decisions taken

- The app's own row on every iOS version, not Apple's bottom search bar (his pick).
- A narrow iPad window keeps the top layout ("Mac and iPad exactly as they are").
- A big iPhone turned on its side, where the list becomes a side column, keeps the top layout in that column.

## Looked at (simulator "Seedboard iPhone 18 Pro", `-sampleData`)

Pictures in `/private/tmp/claude-501/-Users-martinschabbauer-Obsidian-Claude-Code/17034763-8459-4a3b-a9bb-13fd5828f01e/scratchpad/pics/`:
`p2-day.png`, `p2-night.png`, `p2-keyboard-night.png` (typing "cab": Summer cabin + Sketch ideas, row on the
keyboard, Settings gone), `p2-starters-night.png` ("+" pressed with the keyboard up → Starters page).
Also seen: the Search key ends typing and "Settings" comes back.

## NOT seen

- VoiceOver, a small iPhone (SE size), an iPhone on its side.
- Mac and iPad were built, not looked at (the row cannot appear there).

## Drive-by problems seen and left

- none
