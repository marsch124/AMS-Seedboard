# Lane "boards" — ideas 20, 21, 24 (all built)

Code: `Core/Sources/SeedboardCore/Boards14.swift` (BoardJoin, OpmlOutline), `App/Sources/Boards14.swift` (desk, lock, Join page, hosts). Tests: `Core/Tests/.../Boards14Tests.swift` (3), screen test `UITests/Boards14UITests.swift` (Join page; built only).

## 20 Join with…
- A board's menu (home-page card press-and-hold / right-click, iPhone list row press-and-hold, Mac right-click) has **Join with…** (id `card.join`), after "Make a copy". Not shown on timelines / Who does what, boards put away, or boards a newer Seedboard made.
- Page heading **Join with…**; hint "The things of “Garden” are laid to the right of the board you choose. “Garden” goes under Put away."; rows = the other ordinary, changeable, not-put-away boards (name + list line), the chosen row says **Chosen**; empty: "There is no other board to join with."; buttons **Cancel** (Escape) and **Join** (full colour, off until a board is chosen). Ids: `join.page`, `join.cancel`, `join.join`, `join.hint`, `join.empty`, `join.list`, `join.row.<title>`.
- Join: all things of THIS board are laid to the right of the chosen board's things (80 points gap, tops level), arrows kept, ids made new only where one clashes; the chosen board is saved and opened (name, colour, id stay the chosen board's); THIS board is put away (never deleted). Line: "“Garden” was joined in. It is under Put away." (6 s). The chosen board's undo list holds the join as one step when it was open.
- Not done: no drag-one-card-onto-another. Doors in other boards that pointed at the put-away board still open it (it is only put away). Not on boards that place things themselves.

## 21 Lock with Face ID
- Card menu (same places) and board **More** menu (`more.lock`): **Lock with Face ID** / **Unlock**; the word says Touch ID on a Mac with Touch ID, **Lock with device code** where there is no biometric. Ids `card.lock`, `more.lock`. Sets `Board.faceLock` (format 8).
- Uses `.deviceOwnerAuthentication`. Locking does not ask; Unlocking asks ("Unlock “Garden”."). Opening asks ("Open “Garden”.") for every way in — all go through `AppModel.open(_:)` (card, list, link, Handoff, Shortcuts, Spotlight); old body is now `openNow`. Failed: "The board stays closed." / "The board stays locked."; no code on device: "This device has no code set up, so the board cannot be opened." / "Set up a code or Face ID on this device first."
- Lines after locking/unlocking: "“Garden” is locked. It asks for Face ID to open." / "“Garden” is unlocked."
- Locked card (and iPhone row picture): title and colour dot, picture area empty with the word **Private** (`card.private`). Left out of Spotlight (and forgotten there when locked; also out of the Siri/Shortcuts name list) and out of "Still thinking about these?". Joining a locked board asks first.
- `NSFaceIDUsageDescription: To open boards you locked.` in project.yml.
- NOT done: the list's row text (e.g. "12 ideas") and the home-page search still find a locked board by the words inside it (BoardSearch); the lock is not re-asked when the app comes back from the background for an already open board; the lock change is in the board's undo list. Words "Private" and the guide should say a lock is only on this feature, not encryption — the file is not encrypted.

## 24 Open an outline file
- Mac **File ▸ Open Outline…** (after Starters…); iPhone/iPad: a small **More** menu in the list's bottom line (next to Settings) with **Open an outline file** (`boards.openOutline`, menu `boards.more`). Chooser takes .md, .txt, .opml (and xml).
- Result: a new mind-map board titled by the file's name (the first heading / OPML title only if the name were empty); one top entry becomes the centre, several hang under a centre called the file name. Markdown reads like "Paste a list" (`Outline.parse`: lists, headings, check boxes); OPML via `OpmlOutline` (nested `<outline text=…>`). It opens like any new board.
- Problems: "No outline was found in that file." Files over 5 MB are refused.
- NOT done: no drop of a file onto the window; no round-trip export to OPML.

## Shared files touched (small marked changes)
AppModel.swift (open → openGate + openNow; `edit` no longer private), HomeView.swift (card menu line, card/row picture), RootView.swift (row menu line, `.boards14Host()`, iPhone More), Menus.swift (Open Outline…), BoardView.swift (More: Lock), Spotlight.swift (filter), Switches13.swift (nudge filter), project.yml (one line). No new stored field.
Launch words: none. Could not see: any running screen, Face ID prompt (no simulator was used).
