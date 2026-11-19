# 0.14 lane calendar: built ideas 1, 2, 3, 4, 5, 6, 13

No new stored field. Shared files touched (small, one place each): AppModel.swift (`waitingThing`, `openLinked`, `boardsStillArriving`), BarActions.swift (`withCopyLink`, one line in `thingMenu`, one in `bar()`), BoardSession.swift (`thingToShow` + two `landWaitingThing()` calls in `placeIfNeeded`), BoardStore.swift (`gathered`, `stillArriving`). BoardMenu.swift was NOT changed (the menu line comes through `thingMenu`).

## 1. A calendar day opens the right board
A link `seedboard://board/<board>/item/<thing>` now reads the board from the FIRST part (Core `BoardLink.id`). Calendar days (already written with such links) open their board. Not done: nothing else changed for plain `seedboard://board/<id>` links.

## 13. A link to one single thing
- Words: bar button and menu line "Copy link to this". After a press the line at the bottom says "Link copied. It opens this board at this thing."
- Where: the bar beside ONE chosen thing on an ordinary board (idea, note, text, frame, picture, sketch, door, shape) in front of Remove; behind the "…" when the bar is narrow (drop 7, shows mark + word on Mac and iPad, mark only on iPhone). Right-click on the Mac and press and hold on iPhone and iPad: the same line "Copy link to this" before "Remove" (one thing only; not for several chosen). Mark used: the existing Copy mark (no new mark drawn).
- Opening such a link: opens the board, chooses the thing and the view glides and zooms (60 % to 120 %, readable) so it is in the middle. If the board is already open it just glides. On timelines and Who-does-what boards the row is chosen and brought into sight (no zoom).
- A link whose thing is gone: the board opens and the line "That thing is no longer on the board." (problem colour, 5 s) shows.
- Identifiers: `sel.copyLink` (bar), `menu.copyLink` (menu).
- Does NOT: no link from timeline bars or Who-does-what things (those boards have their own bars; `placesItself`); no link for several things; does not unfold a folded branch the thing is hidden in.

## 2. No work while boards are still arriving, and never many removals
`CalendarFollow.pass` returns wait while iCloud has not finished its first look at the folder or a board file is not on this device yet (`BoardStore.stillArriving`); the calendar then waits and looks again after 20 s (up to 15 times). `CalendarFollow.limited`: at most 5 days are taken out per pass (`mostRemovals`); the rest follow in the next pass (retry after 30 s). Added, changed and twin copies are not limited.

## 3. Only when the wanted days changed
A fingerprint of the wanted days is kept after each complete pass (`calendar.wantedSignature`); an unchanged one skips the pass without touching the calendar. A real look is forced when the switch is turned on, after a failure, while removals wait, and when the app comes to the front after more than an hour.

## 4. A refused change is said
On failure nothing is saved, the old "updated" time and signature stay, and the line under the switch reads "Could not update the calendar — will try again" (identifier `settings.calendarFailed`, problem colour); a new try follows after 60 s.

## 5. Two "Seedboard" calendars
If none is found, the calendar waits 8 s, refreshes the sources and looks again before making one. If two or more of that name exist, the remembered one (else the first) is kept; our days in the others move into it, and an other one is removed only when nothing else is left in it.

## 6. Switching off
Switching off removes our events (looking as far as our days were ever put: the first and last day are remembered, `calendar.firstDay/lastDay`), then removes the calendar only if no other event is found from 5 years back to 10 ahead (or as far as our days reach). Otherwise the calendar stays and a line says "Seedboard's days are out of the calendar. The calendar itself stays: other days are in it."

## Not seen
Nothing run (no simulator, no real calendar, no iCloud). The glide target and the arrival test on a real iCloud folder are unseen. Launch words: none.

## Tests
`Core/Tests/SeedboardCoreTests/Calendar14Tests.swift` (3 tests: link parts, removal cap + change check, join + off rules). No screen test (no new screen).
