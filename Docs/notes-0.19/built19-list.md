# Built 0.19 — lane "list" (branch wt19-list)

Files: Core/Sources/SeedboardCore/List19.swift (rules), App/Sources/List19.swift (views, SF Symbols enum `Marks19List`),
edits in App/Sources/RootView.swift (the list) and HomeView.swift (home cards). No new stored field. Tests: Core/Tests/.../List19Tests.swift (5 tests), UITests/List19UITests.swift (written, compiled, not run).

## 1 Swipe a row (iPhone, iPad only)
Rows are not in a List, so a swipe of my own (`RowSwipe19`): swipe right shows a blue button "Pin" (symbol pin) or "Unpin" (pin.slash); swipe left shows a grey-slate button "Put away" (archivebox). Short swipe (over 44 pt) leaves the button open (88 pt wide) to press; long swipe (over 150 pt) does it at once; a tap on the row while open closes it. Uses model.togglePin / model.putAway (put away says its usual line). Not offered on put-away boards or boards the app may not change. VoiceOver actions "Pin"/"Unpin"/"Put away". Ids: boards.swipePin.<title>, boards.swipeAway.<title>. Before: only the press-and-hold menu. Mac: no swipe.
Not seen: the feel on a device; on iPad the row's drag-to-door (onDrag) may fight a quick sideways swipe.

## 2 Search shows the found line
Under the name, small grey line = the first line (of a thing, an arrow, or words read in a picture) holding most of the wanted words; found words bold; cut round the first hit to about 70 characters with "…". Not shown when only the name matched, or for Face-ID-locked boards. Row and home card (Mac too). Id boards.found.<title>. Core: Board.foundLine(_:) -> FoundLine (pieces with bold flag).

## 3 Sort on the Recent card
Small menu "Sort" (symbol arrow.up.arrow.down) at the top right inside the Recent card, shown when it holds 2+ boards: "Last changed" (default, as before), "Date made", "Name" (A–Z, no case/accents); a tick marks the current. Kept per device in UserDefaults key `list.sort`. The home page's Recent grid follows the same order. Ids boards.sort, boards.sort.changed/made/name. Core: BoardSort.

## 4 Due soon card
Card "Due soon" (key dueSoon, folds like the others, own part colour = Timeline orange) at the top of the list, above Pinned, when a board's due day is today..+7 days or already past; none = no card; hidden while searching; put-away boards left out. Rows: dot + name, right: "today", "tomorrow", "in 3 days" (grey) or "1 day late"/"3 days late" (red). Nearest/latest first. Press opens the board. Ids boards.card.dueSoon, boards.due.<title>. Core: DueSoon.entries / DueSoonEntry. Home page (iPad/Mac detail) has no Due soon card (the brief says the list) — say if wanted.

## 5 "2 late" in red on timeline rows
The existing line already said "5 things · 1 done · 2 late"; now only the "2 late" part is red (LineText19), on rows and home cards. Count = Core timeline rule (timelineProgress.late), new wrapper Board.lateThings. Id boards.line.<title>.

## 6 Colour…
Press-and-hold row/card menu: "Colour…" (paintpalette) opens a submenu green, pink, orange, blue, teal (no purple, no red); tick on the current. Before: "Colour" with all of Palette.boards incl. purple. Hidden on read-only boards. Existing setColour (undo-less list action as before). Id card.colour.

## 7 Pull down to make a board from the clipboard (iPhone, iPad)
Pull the list down: small line "Release to make a board from the clipboard" fades in (id boards.pullLine); released past 70 pt (about 60 pt is enough) the clipboard text becomes a new mind map via Outline.parse + addMap (one top line = centre and name; several top lines = centre and board "From the clipboard"), saved and opened like any new board. Empty clipboard: line "Nothing on the clipboard to make a board from." (problem tone) and nothing is made. Core: ClipboardBoard.board(from:).
Not seen / risk: release is detected by a drag gesture ending while the pull is past the line (iOS 17 target, no scroll-phase API); needs trying on a device. iOS may ask "Allow Paste".

## 8 Thin done bar
3 pt capsule under the name (above the small line), green fill (the app's done green) on a 10 % track; share = (to-do boxes done in PARAGON + timeline bars/milestones done) / (all such things); hidden when none. VoiceOver "3 of 8 done". Id boards.doneBar.<title>. Core: Board.doneShare(doneThings:). Rows and home cards.

## 45 Send to PARAGON…
Press-and-hold menu "Send to PARAGON…" (paperplane): opens the board, then the existing Send page (SendSheet) after 0.5 s. Not on put-away boards; refused with "This board was made by a newer Seedboard. Update the app to send it." if the board cannot be changed. For a Face-ID-locked board the unlock comes first and the Send page does not follow (user presses Send). Id card.send.

Mac: 2, 3, 4, 5, 6, 8, 45 in the sidebar list; 2, 5, 6, 8, 45 and the Recent order also on the home cards. 1 and 7 touch only.
Left out: nothing, except Due soon on the home-page grid.
Signs: pin / pin.slash / archivebox swipe buttons (blue = Pin, slate = Put away); thin green bar = share done (green = done); red "N late" / "N days late" = late (red = late only); Sort symbol = order of Recent.
