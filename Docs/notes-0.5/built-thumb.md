# Built: thumb — pick 31, the thumb row (phase 1: pictures first)

18 Nov 2026. Branch `wt-thumb`. Phase 1 only: the new layout exists behind a launch word so Martin can compare
two pictures. Without the launch word the app is exactly as in 0.4. Nothing here is for the texts builder yet:
What's new, How it works and the specification get their words only after his pick (phase 2).

## What is built

**Only on the iPhone layout** (the narrow layout, `phone == true`) and **only with the launch word `-thumbRow`**:

- The green **"New board"** button and the **"Search boards"** field are gone from the top of the boards list.
  The list (Pinned, Recent, Sent to PARAGON) starts right under the title "Seedboard".
- At the **bottom** of the list, above the line with "Settings" and the version number, sits ONE row, the thumb row:
  - a thin dividing line over the row (it takes the place of the line that was over "Settings");
  - left: the search field, **44 points tall**, round at both ends (a capsule), the same faint grey ground
    as today's field (6 % of the text colour), the hand-drawn green magnifier (18 points) and the same words
    **"Search boards"**. When something is typed, the hand-drawn round "x" (19 points) at its right end empties it,
    as today;
  - right, 10 points beside it: a **round "+" button, 44 points across, in the boards' full green**
    (`Part.boards.fill`, day `#2E8B57`), with the white hand-drawn plus (22 points). It has no words; VoiceOver
    reads "New board". Pressed, it gets 12 % darker and 97 % of its size (never see-through);
  - room around the row: 12 points left and right, 8 above, 4 below.
- "+" opens the same page as "New board" does today: the Starters page coming up from the bottom
  (same heights, same choices, same result — the new board opens).
- The search works as before (it is the same search words, the same line "No board has these words").
- "Settings" and the version number stay where they are, as the last line of the page.

**Mac and iPad: nothing changed**, with or without the launch word (the row is only made when the list is in
its iPhone layout).

## Launch words

- `-thumbRow` — the iPhone's list with the thumb row. Example for pictures:
  `xcrun simctl launch <simulator> com.schabbauer.AMSSeedboard -thumbRow -sampleData` (`-sampleData` last).
- `-thumbRow -search cabin -sampleData` also works (the existing `-search <word>` fills the field at the bottom).

## Identifiers

- `boards.thumbRow` — the row (a container; children stay findable).
- `boards.new` — the round "+" (the same identifier as today's "New board" button, which is not on screen then).
- `boards.search`, `boards.searchClear` — the field and its "x" (the same identifiers as today's field).

## Code

- NEW `App/Sources/ThumbRow.swift`: `LaunchOptions.thumbRow`, `ThumbRow`, `ThumbSearchField`, `RoundFilledButton`.
- `App/Sources/RootView.swift`, four small hunks in `BoardList`: the property `thumbRow` (= `phone` and the
  launch word); `if !thumbRow {` … `}` around today's "New board" button and search field (the lines inside are
  NOT re-indented, to keep the hunk small); `if thumbRow { ThumbRow(…) } else { Divider() }` in place of the
  `Divider()` over the Settings line.
- No stored field, no new rule (so no new data test), no new mark, nothing in `project.yml`.

## Decisions I took (the lead or Martin may want otherwise)

- **The app's own row, not Apple's bottom search bar.** The panel note names Apple's own bottom search for
  iOS 26 (`DefaultToolbarItem(kind: .search, placement: .bottomBar)`) and a hand-made row for iOS 17–18. I built
  the hand-made row for EVERY iOS version: Apple's bar brings Apple's stock magnifier and its glass look, which
  breaks the rule "hand-drawn marks only", and one row that looks the same on every iPhone is simpler to lock
  with a screen test.
- **"Settings" and the version stay the very last line**, the thumb row sits right above it. So nothing else he
  placed moves; the row is still well inside the thumb's reach.

## Pictures

In `/private/tmp/claude-501/-Users-martinschabbauer-Obsidian-Claude-Code/17034763-8459-4a3b-a9bb-13fd5828f01e/scratchpad/pics/`,
simulator "Seedboard iPhone 18 Pro", by day, the same sample boards in both:

- `thumb-today.png` — `-sampleData`
- `thumb-new.png` — `-thumbRow -sampleData`

Seen in the pictures (both looked at): the same 12 sample boards; today 11 whole rows fit and the 12th is cut
by the Settings line, with the row all 12 fit; the row sits between the list and the "Settings" line, well clear
of the home indicator (its middle is about 92 points above the screen's lower edge on the iPhone 18 Pro).

## NOT built (phase 2, after his pick)

- Making it the real layout (no launch word) or taking it out.
- The ONE screen test that locks where search and "+" sit.
- The line of an empty list still says "No boards yet. Press New board." — with the row it should name the "+".
- While the keyboard is up, the "Settings" line rises with the row; hiding it while typing would give the list
  more room.

## NOT seen running

- The keyboard up over the row (typing into the search at the bottom), the Starters page coming up from "+",
  the night look, a small iPhone, VoiceOver.
- The Mac and the iPad were built, not looked at (the code cannot reach them: `phone` is false there).

## Drive-by problems seen and left

- none
