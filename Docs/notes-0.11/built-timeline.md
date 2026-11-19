# 0.11 lane timeline: items 3, 20, 47

## What's new
- 3: A bar date in year 1 or 9999 could make the timeline draw a mark for every day in between. Now the Dates page refuses a year outside 1900 to 2200 with the line "Pick a date between the years 1900 and 2200.", and the timeline never draws more than 1500 date marks at once (before: no limit).
- 20: The small picture of an own timeline starter showed its saved dates. Now it shows them moved to "from today", as a new board from it would get.
- 47: A board can have its own due day. "Due day…" in the board's More menu (iPhone/iPad) and in the Mac's File menu opens a small page with a date picker, Cancel, Save and "No due day". The card and the row show "Due 12 Jan" small, red when past. Send as a project gives PARAGON that day as the project's due day. The list order is not changed.

## How it works
- Due day: open More, Due day…, pick a day, Save. "No due day" takes it away. It shows small under the board's name in the list; red once the day has passed. When you send the board as a project, PARAGON gets it as the project's due day (on a timeline this replaces the last bar's day).
- Dates page: a year before 1900 or after 2200 is not accepted; a red line says so.

## Spec
- Core: `Timeline11.swift`: `DayRange` (firstYear 1900, lastYear 2200, mostMarks 1500, `refusal`, `drawEnd`), `StarterShelf.shownBoard`, `Board.dueDay`, `Board.dueWords(today:)` ("Due 12 Jan", with year when not this year, e.g. "Due 12 Jan 2027"; past = before today), `Board.setDue(_:)`, `ParagonExport.withBoardDue` (replaces or adds `due:` in the project's front matter; used in `projectHandover`). `TimelineGeometry.ticks` stops at 1500 marks; `Board.setDates` returns 0 for an insane day.
- App: `DueDay.swift` (`DueDesk`, `DueWords` id `home.due.<title>`, `DueHost`, `DueSheet` ids due.picker, due.none, due.cancel, due.save, due.problem). Dates page: id `dates.problem`. More menu id `more.dueDay`. Mac File menu: "Due Day…".
- Shared files edited (small): BoardView.swift (menu line + sheet modifier), Menus.swift (one line), HomeView.swift, RootView.swift (one DueWords line each), BoardThumb.swift, TimelineBars.swift, TimelineDraw.swift (one line), SendTasks.swift (one line), Timeline.swift (tick loops, setDates guard).
- A due day is stored in `Board.due` "yyyy-MM-dd" (format 7); a stored day outside 1900-2200 is ignored.

## Pictures
- Dates page: any timeline board, double-tap a bar, Dates. Due page: More, Due day… (use `-sampleData`; set a past day for the red words).

## Not done / doubts
- The Dates page picker itself is not limited; the refusal shows on Save.
- Not a stored field of the board for sort order: none, per brief.
- Mac File menu "Due Day…" is not in a Board menu (there is none; it sits in File beside Rename).
- Setting a due day touches the board (its "changed" time moves it in the list, as any edit does).
