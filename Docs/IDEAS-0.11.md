# Seedboard — 50 hardening and improvement ideas for 0.11 (19 Nov 2026)

Read from the code of 0.10 (nothing run, nothing changed). None repeats the 14 ideas turned down on 18 Nov (3, 4, 5, 6, 8, 9, 11, 13, 31, 32, 34, 43, 44, 45) or the items turned down after the 0.2 and 0.5 panels (mind map as a list, a PARAGON project as a board, widget, two windows, board as a real file, small pictures, tool pill words, find, note on an idea, big-board speed). ⭐ = my 10 strongest. Already fine in 0.10 and so NOT listed: the Send page's "PARAGON 340 or newer" sentence (`SendSheet.swift:88`), the starter's working copy on the device (`StarterModel.swift:210–230`, saved on leaving at `AppModel.swift:283`).

## Hardening (1–25)

**1. ⭐ A damaged thing is dropped for good** — If one thing or one arrow in a board file cannot be read, it is left out, and the next save writes the board without it, with no word to you.
*M · `Board.swift:541–542` (items and arrows read with `Lenient`), `Board.swift:370–371` (an arrow with no start or end is lost) · the board stays editable, so the loss is silent; it should be set aside first and the board shown read-only with a line.*

**2. A damaged date makes a board look ancient** — If a board's "changed" and "created" times cannot be read, the board counts as from 1970 and any other device's copy would win over it.
*S · `Board.swift:535–536`, `BoardStore.swift:505–509` · the "newer wins" rule trusts this date; use the file's own date when the text is unreadable.*

**3. ⭐ A wrong year can freeze the timeline** — A bar dated year 0001 or 9999 makes the timeline draw a date mark for every single day in between.
*S · `Timeline.swift:32–37` (any year is accepted), `Timeline.swift:267–272` (one mark per day), `TimelineDraw.swift:111`, `258` · a typo on the Dates page or a pasted date could make the app hang.*

**4. Huge numbers can crash the view** — A board file with a thing placed absurdly far away makes the dot grid and the timeline turn a giant number into a whole number, which stops the app.
*S · `DotGrid.swift:36–37`, `Timeline.swift:230`, `234`, `240` · only 9 files in Core check numbers for sense (`isFinite`); clean positions and sizes when a board is read.*

**5. ⭐ Every Send problem says "no Inbox"** — A full disk, a locked file or a closed iCloud all end in the same line, so you cannot tell what to do.
*S · `ParagonGate.swift:239` (any write error becomes `noInbox`) · an error message that says nothing; name the real cause in plain words.*

**6. ⭐ PDF keeps every photo open at once** — While the PDF is made, each photo stays unpacked at full size until the last page is done, so twenty phone photos can use up the memory.
*M · `BoardPaper.swift:21`, `49–50` (the `found` list is only emptied at the end), `77` (drawn at 4 times) · the comment above it promises "without running out of memory"; keep only the pictures of the page being drawn.*

**7. Print and PDF freeze the screen** — Making the pages happens in the main thread, so a big board holds everything still, and iOS may stop the app for being slow.
*M · `BoardPaper.swift:158–166` (`BoardPrint.ask`, main thread), `BoardPaper.swift:57–88` · the known open point, confirmed; show a "Making the pages…" line and read the photo files in the background first.*

**8. Export all holds everything three times** — The packed file, the pictures and the final copy are all in memory together, which is heavy with many boards and photos.
*M · `BringBack.swift:140–156` (pictures read into `files`, then zipped, then read back whole) · a full month of work could end in a crash at the moment you want a safety copy.*

**9. ⭐ Undo keeps 120 whole boards** — Every step stores a full copy of the board, pencil lines included, so a long evening on a drawing board grows without a limit in size.
*M · `BoardSession.swift:61`, `102–106` · limit by size (for example about 40 MB), not only by count; say so in the Undo list.*

**10. A newer board is called "not a board"** — Importing a board from a newer Seedboard says "was not a board this Seedboard can read", although only an update is missing.
*S · `BringBack.swift:188–190`, `205` (`canBeChanged` failing counts as skipped) · name the real reason: "made by a newer Seedboard — update first".*

**11. A broken board link does nothing** — Opening a `seedboard://` link with a damaged name returns quietly with no sign.
*S · `AppModel.swift:475–478` (`BoardLink.id` nil, then `return`) · a link in PARAGON that fails should say "That board link is not complete".*

**12. ⭐ VoiceOver cannot reach anything on a board** — The whole board is one single element called "Board"; no idea, note, shape or arrow can be found or read out.
*L · `CanvasView.swift:123–126` (`accessibilityElement()` over the drawing); also `TimelineView.swift:82`, `SequenceView.swift:93` · build a list of things with their words, kind and place (outline order), with Choose, Move and Edit as actions.*

**13. VoiceOver cannot reach bars or messages** — Timeline bars, milestones and "Who does what" messages are painted, never described.
*M · `TimelineDraw.swift` and `SequenceDraw.swift` paint with no labels; only the whole view has one · "Permit, 1 Dec to 5 Dec, done" should be readable and movable.*

**14. Fixed letter sizes ignore your text size** — 29 places set a letter size in points, so the largest system text size does not reach them.
*M · `.font(.system(size:` in `App/Sources` (29 lines), against 96 Apple text styles; the spec 9.4 lists "the largest text sizes on the cards" as never seen · use `@ScaledMetric` for buttons and chips.*

**15. Colour alone says done, late and legend** — Someone who cannot tell red from green cannot tell a late bar or a colour's meaning; "Differentiate Without Colour" is never read.
*M · no `accessibilityDifferentiateWithoutColor` anywhere in `App/Sources`; bars in `TimelineDraw.swift`, legend card in `MarksViews.swift:42–77` · add a small mark or pattern beside each colour meaning.*

**16. ⭐ The file store has no test of its own** — Everything that saves, finds iCloud copies, sets aside versions and removes boards lives in the app, where there is no test target, only screen tests.
*L · `BoardStore.swift` (1,234 lines; atomic writes at `649`, `821`, `997`); `project.yml:153–172` has UI tests only · a small test target working on a temporary folder would test save, " 2" copies, removal marks and unreadable files with no iCloud.*

**17. Nobody tests damaged files** — No test feeds the reader a cut-off file, a wrong type, an enormous number or a file full of nulls.
*S · `Core/Tests/SeedboardCoreTests/BoardTests.swift`, `SafetyTests.swift` (none mention such files); `Board.swift:529–546` · one test of ten odd files that must not crash and must not lose items.*

**18. The picture tidy cannot be dry-run** — The weekly clean-up of unused photos goes by reading every board, safety copy and starter as plain bytes, but you cannot see what it would remove.
*M · `PictureStore.swift:547–609` (`tidy` reads all `blobs`, then deletes after two passes a week apart) · add a "Pictures nobody uses: 3 (12 MB) — Keep / Remove now" line in Settings; losing a photo is the worst thing the app can do.*

**19. Many photos read at once on a board** — Opening a board with 30 photos asks for every picture in view at the same moment, and the sharp copies are read "a few at a time" with no total.
*M · `PictureStore.swift:228–237` (`image`), `369–371` (`letSharpGo` only on a memory warning) · cap how many full-size copies are open; test with a made-up 40-photo board.*

**20. A starter's thumbnails show the saved days** — The small picture of a timeline starter you made shows its saved dates, not the "from today" dates a new board gets.
*S · `StarterShelf.swift` / `BoardThumb.swift` (the known open point, confirmed) · confusing next to "Plan starts today".*

**21. The caption's room is a guess** — The space kept under a picture for its caption counts 6.6 points per letter, so a wide font or another language can overlap the next thing.
*M · `Pictures.swift:153–171` (`captionLines`), `captionFrame` · measure with the same font the screen uses, in one shared function.*

**22. Line up and Even gaps ignore captions** — These two use the picture's box only, so a captioned picture sits too close to the next one.
*S · `Tidy.swift:30` (`lineUp`), `45` (`evenGaps`); `Item.captionFrame` is not used there · the known open point, confirmed; use the picture plus its caption.*

**23. The Send mark of a picture reads "sketch"** — For a drawing PARAGON says "A sketch (on the board)", and for a picture the text is a second wording; both should say what it is the same way.
*S · `Paragon.swift:290–293` (`sketchLine`), `pictureLine(picture:)` · "A picture (on the board)" is still not the wording of the picture-without-image case; one test per wording.*

**24. The corner legend card has no mark** — Every other small tool has a mark; the card in the corner is plain.
*S · `MarksViews.swift:42–77` · the known open point; the same card mark as the menu line.*

**25. Nobody has seen the menu marks open** — The marks beside the menu lines are made once with `ImageRenderer` and kept; no one has seen them in a real open menu, day and night.
*S · `NewMarks.swift:113–141` (`MarkLabel`, `MarkPicture.image`, template image) · risk: invisible or black marks at night on the Mac; one picture round on a real device would settle it.*

## Improvements (26–50)

**26. ⭐ See what PARAGON did with it** — After Send, the board's to-do box says "in PARAGON" at once, but nothing says whether PARAGON has really taken it; a small "waiting" state would be honest.
*M · `ParagonGate.swift:235–256` (writes the waiting list and stops), `Echo.swift` reads back · "waiting" turns into "in PARAGON" when the line shows up, and into "not yet — open PARAGON" after a day.*

**27. ⭐ Send only the chosen things** — Choose three ideas, press Send, and only those three go; today the choice is a branch, a frame or the board.
*M · `SendFrames.swift`, `SendTasks.swift`, `SendSheet.swift` · the shortest way from a thought to a PARAGON task.*

**28. Take a board back out of PARAGON** — When a PARAGON task is done there, its box on the board ticks itself (already so); the other way, a box you tick on the board could tick the task in PARAGON.
*L · `Echo.swift`, `ParagonGate.swift` · would need PARAGON's yes first (it writes its own notes).*

**29. A board for today's meeting** — A starter that opens with the date as title, "Who", "Notes", "Decisions", "To do" ready, and Send puts the to-dos under that day.
*S · `Starters.swift` (10 built-in starters) · one more built-in starter, plus a data test.*

**30. Names for colours, yours** — Say once that yellow means "question" and green "decided", and the name shows under the colour in the bar and in PARAGON's note.
*M · `Board.swift` `legend` (already stored), `ChosenBar.swift:244` (`colour.word`) · reuses the legend; nothing new is saved.*

**31. Words of a drawing, on request** — Select pencil lines and say "Read this": the words come up as a note next to it, with the drawing kept.
*M · `Ink.swift`, `InkWords.swift` · handwriting already becomes words on tap (0.9); this keeps the drawing and puts the typed note beside it.*

**32. A board opens on its own "next"** — On opening, one small line says the next thing to do on this board ("Next: Call the electrician") from the first unticked to-do.
*S · `Home.swift`, `Views09.swift` · a thought board stops feeling like a pile.*

**33. ⭐ Fold a map to its main branches** — One press shows only the first level (or two) of a mind map; press again and everything opens.
*S · `MindMap.swift` (fold per idea exists since 0.9), `ChosenBar.swift` · a big map becomes readable on an iPhone at a glance. (Replaces "page through by frame": Show frames of 0.9 already does that.)*

**34. Link a board to a person in Contacts** — A "Who does what" lane name offers your contacts, so "Alex" is the same Alex everywhere.
*M · `SequenceSession.swift`, `Lanes.swift` · only the name is taken, nothing leaves the device.*

**35. Size words on arrows follow the zoom** — Words on an arrow stay a readable size when you zoom out a long way, instead of shrinking to nothing.
*S · `ArrowDraw.swift`, `Arrows.swift` · a real problem on a big mind map on an iPhone.*

**36. Pencil: an eraser that shows its size** — While the eraser is down, a ring on the board shows how much it will take away.
*S · `InkDesk.swift`, `InkDraw.swift` · you stop erasing a line too many.*

**37. Pencil: a ruler for a straight line** — Draw with the Pencil beside a straight edge you place with two fingers, and the line snaps to it.
*L · `InkShape.swift`, `InkPencil09.swift` · the rough-box idea of 0.5 already tidies shapes; this is for lines.*

**38. Ink drying: lines you can still fade** — A slider thins all pencil lines on a board to 30 % so notes on top can be read, then back.
*S · `InkDraw.swift` (one opacity) · useful on a photo with notes and drawing on it.*

**39. A picture's words you can copy** — The words found inside a picture (already searched) can be copied or turned into a note with one press on the picture.
*S · `Item.pictureWords` (stored in 0.9), `PictureViews.swift` · uses data already kept.*

**40. Copy a board's outline as an email** — "Copy as email" writes the outline with a short line on top and "Sent from Seedboard", for pasting into Mail.
*S · `Outline.swift`, `SharePages.swift` ("Copy as text" exists; this is the same text with a greeting and the board's link) · small and handy.*

**41. Soft sound when a to-do is ticked** — A quiet tick sound (off with silent mode), like the other Companion apps.
*S · `FeelMoments.swift` (haptics exist), `Feel.swift:35–40` (Reduce Motion check) · consistent with the family; setting "Sounds" off by default on the Mac.*

**42. Quick board from the lock screen** — A control on the lock screen and the Action button opens a new empty mind map, ready to type.
*M · `Intents.swift`, `QuickActions.swift` · adds a thought in two seconds on the street.*

**43. Recently opened strip on the Mac** — The Dock menu and the File menu list the last five boards opened.
*S · `MacHabits.swift`, `Remember.swift` · the "opens where you left" part exists; this adds the list.*

**44. Show the sent time on a board** — A small line "Sent to PARAGON 14 Nov 10:12 — 5 new since" at the foot of the Send page and the board.
*S · `Board.sent` (when, title, path are stored), `SendSheet.swift` · tells you whether to send again.*

**45. A calmer first minute** — The first launch shows one board "Try me" with three marks to touch, and the empty-board hints fade after you use them.
*M · `EmptyBoard.swift`, `Sample.swift` · an owner who has not used it on a real device yet will start here.*

**46. Plans that skip weekends** — A timeline bar can count working days, so a 5-day job that starts on Thursday ends on Wednesday, skipping weekends and Swedish holidays.
*M · `Timeline.swift`, `SwedishHolidays` (already used for shading) · plans match real work days. (Replaces the "read-only strip": that banner exists since 0.2.)*

**47. Boards with a due date** — A board can carry one date ("Trip: 12 Jan") that shows on the card and sorts the list, and goes to PARAGON as the project's due day.
*M · `Home.swift`, `Paragon.swift` (project `due:` exists for timelines) · uses an existing PARAGON field.*

**48. Print a board at actual size** — Choose "Fit to page" or "Several sheets" for a big board, instead of always one page.
*M · `BoardPaper.swift:113` (`fit`), `SPEC.md` 9.7 ("no printing across several sheets") · useful for a timeline on the wall.*

**49. Drag a photo out to another app** — Press and hold a picture on a board and drag it into Mail or Messages as a file.
*S · `PictureViews.swift`, `ClipBoard.swift` (drop in exists) · the board stops being a one-way box.*

**50. A weekly "still open" nudge, quiet** — Once a week, a gentle local notification: "3 boards have open to-dos not in PARAGON".
*M · `Home.swift` (line under each board), `Echo.swift` · off unless you switch it on; never sends anything by itself.*
