# Seedboard — 30 hardening and improvement ideas for 0.14 (19 Nov 2026)

Read from the code of 0.13 (nothing run, nothing changed). Each idea was looked up in `SPEC.md` first and none is already built. None repeats the ideas turned down on 18–19 Nov (0.11: 13, 25, 29, 32, 34, 35, 42, 44, 45, 46, 48, 49, 50; 0.9: 3, 4, 5, 6, 8, 9, 11, 13, 31, 32, 34, 43, 44, 45) or the items turned down after the 0.2 and 0.5 panels (mind map as a list, a PARAGON project as a board, widget, two windows, board as a real file, small pictures, tool pill words, find, note on an idea, big-board speed). Nothing needs a change in PARAGON, and no new marks are drawn. Already there and so NOT listed: small map, dependencies between bars ("It comes after …"), lock in place, votes, highlighter, lasso, balance, Show frames, share per frame. ⭐ = my 8 strongest.

## Hardening (1–12)

**1. ⭐ A calendar day opens the wrong place** — Every day in the Seedboard calendar carries a link to its bar, but when you press it Seedboard reads the last part of the link (the bar) as if it were the board, so the board does not open.
*S · `Safety.swift:189–192` (`BoardLink.id` takes `lastPathComponent`), `Switches13.swift:176` (the link `…/board/<id>/item/<row>`), `AppModel.swift:481` · read the board from the first part; a test with such a link.*

**2. ⭐ The calendar can empty itself on a new device** — On a device whose boards have not all arrived from iCloud yet, the calendar is matched against the few boards it has, so the days of the missing boards are taken out and put back later.
*M · `Switches13.swift:183–185` (`match` uses `model.boards`), Core `Switches13.swift:82` (`plan.remove` = everything not wanted) · do nothing while boards are still arriving, and never take out more than a few days in one go.*

**3. Every edit anywhere runs the calendar** — Typing in any mind map starts a look through six years of calendar a few seconds later, even when no timeline changed.
*M · `Switches13.swift:55–58` (every change of the board list, 3 s), `143–158` (`ourEvents`, reads 2 years back to 4 ahead) · compare the wanted days with the last ones and only touch the calendar when they differ.*

**4. The calendar fails without a word** — If the calendar refuses a change (full, offline account, read-only), the work is dropped, and the line under the switch still says "updated" just now.
*S · `Switches13.swift:210–212` (`store.reset()` and nothing said), `218–220` (the time is written anyway) · keep the old time and say "Could not update the calendar — will try again".*

**5. Two devices can make two calendars** — If the switch is on in two devices before the first calendar has travelled, each makes its own "Seedboard" calendar and the days are doubled.
*M · `Switches13.swift:113–128` (looks by name on this device only, then makes one) · wait a little and look again before making; join two calendars of that name into the first.*

**6. Switching off can take away a calendar with your own days** — After the events are removed, only one year ahead is checked before the whole calendar is deleted, so a day you put there by hand in 2028 would go with it.
*S · `Switches13.swift:231–235` (`removeCalendar` after a look of −2 to +1 years) · look as far as the days were put, or keep the calendar and say so.*

**7. ⭐ A picture of a huge board has no size limit** — "Share as picture" of a board that stretches 20,000 points makes one enormous picture, which can stop the app.
*S · `BoardPicture.swift:37–39` (scale 1 above 3,000 points, no ceiling), `Safe11.swift` allows positions to 100,000 · cut the picture to about 100 million points and say "Shown smaller".*

**8. A very big PDF page is drawn in one piece** — One page of a large board is made in one go, so memory is used all at once, the one limit left after 0.11.
*M · `BoardPaper.swift:104` (`ImageRenderer(content: page)`), `SPEC.md` 17.5 "Limits" · draw a very large page in strips, one after the other.*

**9. ⭐ Undo of "Move to a new board" leaves a double** — The things come back, the door goes, but the new board stays in the list with copies of everything.
*M · `Doors.swift:300–306` (`model.write(moved.board)` before `change`), `SPEC.md` 9.7 · let Undo also put the new board away (never delete), and say so.*

**10. A copy of a put-away board stays put away** — "Make a copy" of a board under Put away makes a board you cannot see in the list, and then opens it.
*S · `AppModel.swift:431–437` (resets pinned, sent, dates; not `putAway`), `HomeView.swift:156` (Make a copy is offered there too) · clear `putAway` on the copy.*

**11. Long shared words are cut without a word** — Share a very long text to Seedboard and only the first 20,000 letters arrive; the page says nothing (it does say it for pictures).
*S · `Arrivals.swift:151` (`prefix(Arrival.longest)`), `ShareViewController.swift:148` (only pictures get a problem line) · add "Only the first 20,000 letters were taken."*

**12. A tick PARAGON was not told about is lost quietly** — If the line "this bar is done" cannot be written, the tick stands on the board but PARAGON never hears of it, and nothing says so.
*M · `ParagonGate.swift:250–258` (`appendDone`, every `try?` silent) · remember the tick and try again at the next start; say "Not told to PARAGON yet" on the bar.*

## Improvements (13–30)

**13. ⭐ A link to one single thing** — Press and hold an idea, bar or note and "Copy link to this" gives a link that opens the board and zooms right onto it, also from the calendar.
*M · `Safety.swift:189` (the link has only a board), `Switches13.swift:176` (already writes `/item/<row>`), `AppModel.swift:481`, `BarActions.swift` · fixes 1 and gives every calendar day a direct way back.*

**14. ⭐ Tilt a note, picture or shape** — Turn a thing a little, like a note stuck on crooked, with a twist handle or two fingers; a drawn board feels alive.
*L · `Board.swift:157–160` (a thing has place and size only), `CanvasDraw.swift`, `Fingers.swift:39` (touch tests) · what Freeform and Miro do; arrows still end on the edge; off for lanes and timelines.*

**15. ⭐ Copy the look, paste it on others** — Take the colour and shape of one note or idea and paste that look on five others in one press.
*M · `BarActions.swift:326` (the bar's lines), `Board.swift:162` (colour) · today every colour or shape is set one group at a time; this is the "paint roller" of Whimsical and OmniGraffle.*

**16. Lift the subject out of a photo** — Press a picture and "Lift the person or thing out" removes the background, so a photo of a plant sits on the board without its square.
*M · `PictureStore.swift:125–140` (`take`), `PictureViews.swift` · the phone and Mac do this on the device; the new picture is kept next to the old one, which stays.*

**17. Big and small words on a text** — A free text can be a title, normal or small, so a board has a heading you can read from across the room.
*S · `CanvasDraw.swift:80` (text is always size 17), `109` (width 360) · three sizes, the same for everyone who opens the board; the Send text is unchanged.*

**18. Hide finished bars** — One press on a timeline hides the done bars and milestones, so you see only what is left; press again and they come back.
*S · `Timeline.swift:425` (`timelineRows`), `TimelineDraw.swift:312` · nothing is removed or changed; a small line says "3 finished bars hidden".*

**19. Zoom to the chosen things** — Choose a few ideas and press "Zoom to these": the board glides so just those fill the screen.
*S · `BoardSession.swift:840` (`fit()` knows only the whole board), `Glide.swift` · quick on an iPhone for a part of a big map.*

**20. Join two boards into one** — Drop one board card on another (or choose "Join with…") and the things of the first are laid beside the second; the first goes to Put away, not deleted.
*M · `Door.swift:206` (`moveToNewBoard` already moves things between boards), `AppModel.swift:415`, `ArrivalDesk.swift` (the "lay beside" rule) · for two small boards that turned out to be one thought.*

**21. ⭐ Lock a board with Face ID** — A board can ask for Face ID, Touch ID or the device code before it opens, and stays out of the device's search.
*M · `HomeView.swift:148` (card), `AppModel.swift:481` (open), `Spotlight.swift:73` (what is told to the search) · for a gift list, a health thought or a trip surprise; nothing is stored beyond a mark on the board.*

**22. A brainstorm timer** — A small button starts a quiet 5-minute timer on the board (a ring that fills); at the end one soft tap, then "Time!".
*S · `BoardView.swift` (top bar), `FeelMoments.swift` (taps and sound exist) · Miro's way to keep an idea round short; nothing is saved.*

**23. Loops and "if" boxes in Who does what** — A coloured frame round a few messages with a word ("repeat", "if", "else") like in real sequence diagrams.
*L · `Sequence.swift:87`, `SequenceDraw.swift` · what Whimsical's sequence boards have and Seedboard's lack; sent to PARAGON as indented steps.*

**24. Open an outline file as a mind map** — Choose a Markdown or OPML outline file (from Files, Dropbox or another outliner) and it becomes a mind map.
*S · `Outline.swift:20` (`parse` already reads a pasted list), `BringBack.swift` (Import reads only board files) · the same rule as Paste a list, from a file.*

**25. A table** — A small grid of cells on the board for comparing three options by four things.
*L · `Board.swift:148` (no cell kind), `Outline.swift` · Freeform and Miro have it; sent to PARAGON as a plain list of "row — column: words".*

**26. Put today's date into the words** — One press in the typing bar adds "19 Nov 2026" (or "Thu 19 Nov") where the cursor is.
*S · `Typing.swift`, `MapOrder.swift` (the keyboard bar) · meeting notes and "decided on" lines are everywhere on a board.*

**27. Saved pieces** — Save a branch or a few chosen things as a "piece" ("Packing, 5 ideas") and drop it into any board later.
*M · `StarterShelf.swift` (starters are whole boards only), `Clip.swift` (copy and paste between boards) · a bit between Starters and Copy; pieces are kept like starters.*

**28. Drop a PDF page as a picture** — Drag a PDF (or a page of it) from Files, Mail or the Finder onto a board; page 1 comes as a picture, the others on request.
*M · `ClipBoard.swift` (drops: pictures and words only), `PictureStore.swift:125` · plans, tickets and drawings are often PDFs.*

**29. Plan against now** — After a bar has been moved, a faint ghost shows where it first stood, so you see how far the plan slipped.
*M · `Timeline.swift:448` (`moveRow`), `TimelineDraw.swift` · kept only on this board (the day when you press "Set the plan"); Catch up exists, this is the picture of it.*

**30. A quick idea from any app on the Mac** — A key anywhere on the Mac opens a small line; typed words land on a board you choose, without opening Seedboard.
*M · `QuickActions.swift`, `IntentsAdd.swift` (add to a board exists in Shortcuts), `MacHabits.swift` (Core) · the Mac's own key, no new window of boards; Shortcuts and Raycast stay.*
