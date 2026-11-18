# Notes for 0.2 — builder "bringback" (picks 4 and 5)

## 1. What's new

**Bring back removed boards (pick 4)**
- Before: a removed board went into a hidden Removed folder for 30 days, but the app had no way to look into it or get a board back. The only trace was one line, "It is kept for 30 days in the Removed folder."
- Now: Settings › Your boards has a new page, **Removed and earlier versions**. Its first part, **Removed**, lists every board removed in the last 30 days — one row per board, the newest of the device's and iCloud's copies — with a small drawing of the board, its name, what is on it ("12 ideas · 5 shapes") and "removed 12 Nov · 18 days left". The last 3 days are written in the page's colour.
- **Bring back** returns the board as the same board (links from PARAGON notes open it again), stamped as changed now, on every device. A line at the bottom confirms — "“Old garden plan” is back." — with an **Open** button.
- **Remove for good** asks first, with the board's name, and says it cannot be undone. It deletes only that board's removed copies, on the device and in iCloud.
- With nothing removed the part says "Nothing was removed in the last 30 days."

**Earlier versions (pick 4)**
- Before: the app kept a copy of all boards once a day (14 days) and set a version aside when two devices disagreed, but nothing of that could be seen or opened in the app.
- Now: the second part of the page, **Earlier versions**, lists every board that has any. Press a board to see its versions, newest first, each with where it came from and its date — "from another device, 18 Nov 10:00", "this device's version, 18 Nov 09:40", "daily copy, 17 Nov 17:40", "set aside, 16 Nov 08:12" — and what was on it.
- **Open as a copy** makes a NEW board named "Summer cabin (version from 18 Nov 10:00)" and opens it. The board itself is never replaced.
- Only copies that can really be read are listed. The same version kept twice is one row. A copy that is the board exactly as it stands now is not listed.
- Of this device's own set-aside versions only the newest 10 per board are listed (a line says how many more are kept); daily copies and other devices' versions are all listed.

**A clash is no longer silent (pick 4)**
- Before: when two devices changed the same board, the newer change won and the other went into the safety copies without a word (or with one short line that only showed inside an open board).
- Now: a line across the top of the window says "Another device changed “Summer cabin”. The other version is kept under Earlier versions." with **Show**, which opens the page at that board, and a cross to close the line.

**A link to a removed board (pick 4)**
- Before: a link from a PARAGON note to a removed board showed "This board was removed on 12 Nov 2026." for 4 seconds, and only when a board was open.
- Now: the same sentence stays as a line across the top with a **Bring back** button; the board comes back and opens. When its 30 days are over, the line says so and has no button.

**Tidy (pick 4)**
- Before: set-aside versions were never cleared away.
- Now: set-aside versions older than 30 days are deleted. Daily copies keep their own rule (the newest 14 days), removed boards theirs (30 days), both unchanged.

**Export all boards (pick 5)**
- Before: boards could only leave the app one at a time (a picture, or Send to PARAGON).
- Now: Settings › Your boards › **Export all boards** makes ONE file, "Seedboard boards 2026-11-18.zip" (the day's date), and hands it to Files (iPhone, iPad) or a save panel (Mac). Inside, every board is there twice: as its `.seedboard` file and as a plain-text `.md` outline that reads without the app. Under the button: "Last export: 18 Nov" (kept per device), or "No export yet."
- **Import boards…** (small, so it is in): choose one or more `.seedboard` files (unpack the zip first, in Files or the Finder). Each comes in as a NEW board; none replaces a board. A name that is taken gets "(imported)". The zip itself cannot be chosen — see "left open".

## 2. How it works (guide text)

**Removed and earlier versions.** Settings › Your boards › Removed and earlier versions. Done closes the page (Escape on the Mac).

*Removed.* A board you remove is kept for 30 days. Each row shows the board's small picture, its name, what is on it, the day it was removed and how many days are left. Press **Bring back** and the board is in your list again, the same board as before — a link from a PARAGON note opens it again — on every device. A line at the bottom confirms it; **Open** takes you straight to the board. **Remove for good** deletes the board's kept copies now; Seedboard asks first, because this cannot be undone.

*Earlier versions.* Seedboard keeps a copy of every board once a day, 14 days back. It also keeps a version that lost when two devices changed the same board, for 30 days. Press a board's name to see its versions, newest first, each with where it came from and its date. **Open as a copy** makes a new board called, for example, "Summer cabin (version from 18 Nov 10:00)" and opens it. Your board stays exactly as it is, so you can look at both and take over what you need.

**When two devices changed the same board.** The newer change stays. A line at the top of the window tells you: "Another device changed “Summer cabin”. The other version is kept under Earlier versions." Press **Show** to see that version, or the cross to close the line.

**A link to a removed board.** When a link in a PARAGON note leads to a board you removed, a line at the top says when it was removed. Press **Bring back** and the board returns and opens. After 30 days it can no longer be brought back, and the line says so.

**Export all boards.** Settings › Your boards › Export all boards makes one zip file with all your boards and asks where to save it. Each board is in it as a Seedboard file and as a text outline you can read anywhere. The line below the button shows when you last exported. **Import boards…** reads Seedboard files from such an export (unpack the zip first) and adds each as a new board; it never replaces one.

## 3. Spec

**Colour.** New part `Part.kept` (Theme.swift): day `#B4492B`, night `#F0A183` (a warm brick red). Used for the page's headings, marks, Bring back, Done, the lines at the top, and the row in Settings.

**Marks.** `Glyph.new(.bringBack)` (heading "Removed", the row in Settings), `Glyph.new(.earlier)` (heading "Earlier versions"), `Glyph.new(.export)` (Export all boards). Disclosure: `ControlMark.chevron` (13 pt, turned 90° when open). Close: `ControlMark.close` (15 pt in a 26 pt press area).

**The page** (`KeptPage.swift`; title "Removed and earlier versions"; a List with two sections, row minimum height 10).
- Reached: pushed inside Settings (iPhone, iPad, and the Mac's Settings window); as a sheet over the main window (520 × 540 on the Mac, with the title as a heading because a Mac sheet has no title bar) from the clash line, from the launch argument `-removed`, and from `model.keptPage = KeptPageAsk(board:)`.
- Done: full colour in `Part.kept`, `.cancelAction` (Escape). Pushed, it goes back to Settings; as a sheet, it closes the sheet.
- Removed row: drawing 50 × 38 (the board's own painter, whole board fitted, day or night ground, corner 6), name (body medium), counts (caption, `Board.countLine`), "removed 12 Nov · 18 days left" (caption; `Part.kept` colour when 3 days or fewer are left), **Bring back** (FilledButton `.kept`), **Remove for good** (caption, borderless, secondary).
- Confirmation: "Remove “Title” for good?" — "This cannot be undone. Links to it from PARAGON's notes will no longer open it." — Remove for good (destructive) / Cancel.
- Footers: "A removed board is kept for 30 days. Bring back returns it as it was, on every device." and "A copy of every board is kept once a day, 14 days back; a version that lost against another device's is kept 30 days. Open as a copy makes a new board; the board itself stays as it is."
- Empty: "Nothing was removed in the last 30 days." / "No earlier versions are kept yet." Removed copies iCloud has not delivered yet are asked for and counted: "1 more removed board is on its way from iCloud."
- Board row of Earlier versions: chevron, name, "3 earlier versions" plus " · removed" (the board is among the removed) or " · not in your boards any more" (only the copies are left). Version rows are indented 21 pt: source line (subheadline), counts (caption), **Open as a copy** (soft button: `Part.kept` words on its soft tint, corner 8).
- A group opens by itself when it is the only one, or when the page was asked for at that board (then it is also scrolled to).
- Bottom line after Bring back: "“Title” is back." + **Open** (capsule in `Part.kept.fill`, like the board's notice). Problems use the same capsule: "“Title” could not be brought back: no copy of it can be read.", "That version could not be read any more.", "That version was made by a newer Seedboard. Update the app to open it."

**Rules (Core `Kept.swift`, tests in `KeptTests.swift`).**
- `KeptRules.keepDays` = 30. `daysLeft(since:now:)` = 30 − days gone, rounded up, never below 0 (30 on the day of removal; 12 days gone → 18). 0 is shown as "last day", 1 as "1 day left".
- `letGo(kind, kept:, now:)` — removed boards and set-aside versions: older than 30 days; daily copies: never by this rule.
- `newest(_:)` — one copy per board: the version changed last wins; of two copies of the same version (stamps within 1.5 ms) the one removed last. Order: most recently removed first.
- `removedRows(_:present:)` — the newest copy of every board that is NOT in the list now (a board that was brought back leaves its old copies in the Removed folders until their 30 days are over; they are not shown).
- `groups(versions:boards:removed:marked:)` — per board: versions with the same `changed` stamp are one row (kept: set-aside with a known origin, before set-aside without, before daily; then the most recent copy); a version with the stamp of the board as it stands (or of the removed copy) is left out; a board with a removal mark and no removed copy left (removed for good, or its 30 days are over) is not listed; of `.setAside(.here)` only the newest `mostOwn` = 10 are listed, the rest counted in `hidden`. Order: boards in the list by name, then removed, then lost.
- `copyTitle` — "Title (version from 18 Nov 10:00)" (the VERSION's own date, i.e. its `changed`; year added when not this year); a taken name gets " 2", " 3". `asCopy` — new identity, that title, created and changed now, not pinned, `sent` and `sentTodos` cleared.
- Words: `removedLine`, `sourceLine` ("daily copy" / "from another device" / "this device's version" / "set aside" + ", " + the version's date), `clashLine`. Dates are "d MMM" / "d MMM HH:mm" in English, with the year when it is not this year.
- `KeptFileName` reads a kept file's name: `Removed/<id>-<yyyyMMdd-HHmmss>.seedboard`; `SafetyCopies/<id>-<yyyyMMdd-HHmmss>-<6 letters>[-here|-away].seedboard` (or `.unreadable`); `.<name>.icloud` = not arrived.

**Files (Core `KeptFiles.swift`, tried against a throwaway folder in `KeptTests`).**
- `list` — reads both Removed folders (device, iCloud), SafetyCopies (day folders `yyyy-MM-dd/<id>.seedboard` and set-aside files) and the removal marks in both Boards folders. A copy is listed only when it decodes as the board its name says.
- `tidy(safety:now:)` — deletes set-aside files (`.seedboard` and `.unreadable`) older than 30 days; called at every look at the folders (`BoardDisk.loadAll`, after `purgeRemoved`).
- `removeForGood(id, in:)` — deletes every file of that board in the Removed folders, nothing else. The removal mark stays (so no device puts the board back); the board's safety copies stay until their own time is up but are no longer listed.
- `read(version, in:)` — reads one earlier version again (only ever a file inside SafetyCopies).
- The store's bridge: `BoardStore.kept { places in … }` runs such work on the store's iCloud line of work, off the main thread; nil with the example boards (nothing is read or written then). `BoardStore.bytes(of:)` / `board(from:)` give the board's file coding.

**Where a set-aside version came from.** New in the NAME of set-aside files (no change inside any file): `-here` = a version this device showed or saved, `-away` = a version another device wrote that was never shown here, nothing = not known (the board had not been shown in this run of the app yet; all files of 0.1 and of the S-fixes). Decided in `BoardDisk.setAside` from the lineage the store already keeps.

**The clash line** (`BringBackBars.swift`, `AppModel.clash: ClashNotice?`). Raised by the store (`onClash`) when: iCloud held a newer version than the one being saved (mine went to the copies); a version from another device was set aside (`-away`); iCloud had parked a version of its own (a conflict version or an "<id> 2.seedboard" copy) and the two differed; and by the app when another device's news lost against what was typed meanwhile. Text: `KeptRules.clashLine(title)`. Buttons: **Show** (opens the page at that board, closes the line), cross. One line at a time (the latest board). It takes its own room at the top of the window (`safeAreaInset`), over list and board, on all three devices.

**The removed-link line.** `AppModel.removedLink` (the hook) is shown as "This board was removed on 12 Nov 2026." + **Bring back** + cross. Bring back = `AppModel.bringBack(removed:)`, then the board opens and "“Title” is back." is said. 0 days left (by the mark's date): "… Its 30 days are over: it cannot be brought back.", no button. No readable copy: "No copy of this board is left to bring back."

**Bring back** (`AppModel.bringBack(removed:)`): `BoardStore.bringBack(id:)` (the S-fix hook: newest copy, stamped later than now and than its removal, marks cleared on the device and in iCloud), then the board joins the list and goes through the usual save once more so iCloud has it.

**Export** (Core `ExportAll.swift`, `AppModel.exportAllBoards`).
- Name: "Seedboard boards yyyy-MM-dd" + ".zip". Inside one folder of the same name: per board `<name>.seedboard` (the same bytes as the board's own file) and `<name>.md`.
- `<name>` = the title cleaned by PARAGON's file-name rule (`ParagonExport.noteTitle`); a second board with the same name (whatever the capitals) gets " (2)", " (3)".
- The `.md`: "# Title", a line "counts · last changed 17 Nov 10:00 · exported from Seedboard on 18 Nov", the board's outline (`Board.outlineText`: maps as nested bullets, "Flow:", "Notes:", "Shapes:") and "To do:" with `- [ ]` lines for everything marked to do.
- The zip is made by the system (`NSFileCoordinator`, reading the folder `.forUploading`) in the app's temporary folder, which is cleared again; nothing third-party, no Terminal. It is handed over with SwiftUI's `fileExporter` (Files' save sheet on iPhone and iPad, a save panel on the Mac).
- "Last export" is stored per device in the app's settings, key `lastExport` (seconds since 1970), only after the save place said yes.
- What is being typed is kept first, so it is in the export.

**Import** (`AppModel.importBoards`, `ExportRules.imported`, `looksLikeBoard`). Any files may be chosen (several at once); a file counts as a board when it is JSON with `id`, `title` and `items` and this version can change it. Each becomes a new board: new identity, changed now, not pinned, not sent; a taken name gets " (imported)", " (imported 2)". The line below says "2 boards came in as new boards." and/or "1 file was not a board this Seedboard can read."

**Stored fields.** None added to a board's file; the format number is not touched. New: the `-here` / `-away` ending in set-aside file names; the device setting `lastExport`.

**Identifiers.** Settings: `settings.kept`, `settings.export`, `settings.lastExport`, `settings.import`, `settings.importLine`. Page: `kept.page`, `kept.done`, `kept.removed.<title>`, `kept.removedLine.<title>`, `kept.bringBack.<title>`, `kept.forGood.<title>`, `kept.forGoodConfirm`, `kept.removedEmpty`, `kept.waiting`, `kept.board.<title>`, `kept.version.<title>`, `kept.openCopy.<title>.<daily|away|here|aside>`, `kept.earlierEmpty`, `kept.notice`, `kept.open`, `kept.problem`. Lines: `clash.notice`, `clash.words`, `clash.button`, `clash.close`, `removedLink.notice`, `removedLink.words`, `removedLink.button`, `removedLink.close`.

**Shared files touched (small hunks).** `BoardStore.swift` (onClash, the `kept` bridge, `bytes(of:)`/`board(from:)`, the clash event, the origin in set-aside names, one tidy line, `encode`/`decode` no longer private), `AppModel.swift` (`clash`, `keptPage`, `removedLink` can be set, `write` no longer private, one launch line, the held-news line now raises the clash line, the removed-link flash left out), `SeedboardApp.swift` (one line: `.modifier(BringBackHost())`), `SettingsView.swift` (one line: `KeptSettingsRows()`), `Theme.swift` (`Part.kept`). `RootView.swift` is NOT touched.

## 4. For the lead

**Launch arguments (with `-sampleData`).**
- `-removed` — opens the page over the main window. On the Mac it is a SHEET on the main window (not the Settings window). Made-up content: two removed boards ("Old garden plan", 18 days left; "Birthday party", 3 days left, written in the page's colour) and one board with three earlier versions ("Summer cabin": from another device 2 hours ago, two daily copies), opened by itself.
- `-removed cabin` — the same, opened and scrolled at the board whose name holds the word.
- `-clash` — shows the clash line for the first board ("Summer cabin") at the top of the window.
- `-settings` (existing) shows the new rows in Your boards: Removed and earlier versions, Export all boards, "No export yet.", Import boards….
- Sample content is in the new file `App/Sources/SampleKept.swift` (`Sample.removed`, `Sample.earlier(of:)`); `Sample.swift` itself is untouched.

**Screen test.** `UITests/BringBackUITests.swift`, one test (`testARemovedBoardIsListedAndComesBack`): the page lists both removed boards and the board with versions; Bring back shows the line with Open, the row leaves Removed, Done, and `boards.row.Old garden plan` is in the list. Written and compiled (`build-for-testing`), not run. It relies on `boards.row.<title>` still being there after the "look" builder's home page.

**Data tests.** `Core/Tests/SeedboardCoreTests/KeptTests.swift`, 10 tests (141 in all, green): days left, newest copy, copy title, tidy decision, kept file names, the version groups, the folders against a throwaway folder (list, tidy, remove for good, read), export names and outline, the zip, import.

**ICON-WANTED.** None — bringBack, earlier and export are in `NewMark`.

**Not built / left open.**
- "Bring back a removed board…" in a More menu of the boards list: the list has no More menu (only the press-and-hold menu of a row), so Settings is the one way in. One line to add when "look" gives the home page a More menu: `model.keptPage = KeptPageAsk(board: nil)`.
- Import straight from the `.zip`: the system offers a way to MAKE a zip but none to open one, and writing an unpacker is not small. Import takes the `.seedboard` files instead (the owner unpacks the zip with a tap in Files or a double-click in the Finder).
- The old hook `AppModel.bringBack(_:)` is no longer called (the line and the page use `bringBack(removed:)`, which also works with the example boards and can say when it fails). It is left in place; the lead may remove it.
- The flash line (`model.say`) only shows inside an open board; "Board removed. It is kept for 30 days…" is therefore not seen when a board is removed from the list. Not in my brief; noted. Its words could now end "… Bring it back in Settings."
- "Where it came from" is the device's best knowledge within one run of the app. A version set aside before the board was shown in that run says only "set aside". In a rare order of events (iCloud's copy not readable at the first look after a restart, and the device ahead of it) the device's own older version in iCloud can be taken for another device's and raise the clash line once without need.
- A clash where the device was restarted before it noticed (its unsent change loses against a newer one from iCloud at the next start) is kept under Earlier versions as before, but raises no line: after a restart the store cannot tell it from an ordinary newer version arriving.
- This device's version is set aside every time another device's change arrives (S-fix behaviour), so a board edited on two devices collects many "this device's version" rows; the page lists the newest 10 per board and counts the rest. All are deleted after 30 days.

**Only a real device can prove.**
- Bring back and Remove for good between two real devices through iCloud (marks cleared everywhere; the removed copies in iCloud's Removed folder really go; placeholders ".icloud" of removed copies arriving).
- The clash line after a real clash (two devices offline, both change a board, both come back).
- The save sheet for the zip on iPhone and iPad and the save panel in the Mac's Settings window; the zip opening in Files and the Finder; Import picking `.seedboard` files in Files.
- The look of the lines at the top on an iPhone (two or three lines of words) and that nothing is covered — a picture with `-clash` shows it.
