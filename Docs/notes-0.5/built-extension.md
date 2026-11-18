# Built: extension — pick 24, Share › Seedboard (18 Nov 2026)

Lane `extension`, branch `wt-extension`. Finding 1 of `panel-apple-platform.md`.

## What it is, in plain words
Seedboard now shows up in the Share button of every app on iPhone, iPad and Mac (Safari, Photos, Mail, Notes, Finder …) under the name **Seedboard**. Words, one link and up to 10 pictures can be sent to a board. The share page never touches a board itself: it leaves what came in a waiting place, and Seedboard lays it on the board the next time it is in front.

## The share page (exactly as on screen)
- Heading: the sprout mark and **Send to Seedboard** (green, large, bold).
- A grey plate "what came": one bold line — "A link", "Words", "1 picture", "Words and 2 pictures", "A link, words and 1 picture" (nothing usable: "Nothing to send"); under it the first two lines of the words or the link's title (joined with " · "), the link's address small, and the pictures as small squares 44 × 44. While reading: a spinner and "Getting what you shared…".
- **New board** — first row, full green with white words, a ring and a "+"; picked when the page opens.
- **Pinned**, then **Recent** (green small headings): his boards, each with a ring (ticked when picked), its colour dot and its name. Pinned first, then the rest, each newest first, 30 at most. A timeline, a "Who does what" board and a board a newer Seedboard made are NOT offered (nothing from outside can be laid on them).
- Lines in brick red when something could not be taken:
  - "Pictures cannot be shared to Seedboard yet. Words and links can." (only when the shared folder cannot be reached — keychain fallback)
  - "Seedboard cannot take things from other apps on this device yet. Open Seedboard once, then share again." (no waiting place at all)
  - "1 thing could not be read as a picture. Seedboard takes words, links and pictures." / "3 things could not be read as pictures. …"
  - "Seedboard takes 10 pictures at a time. 2 more were left out."
  - "That could not be kept for Seedboard. Press Send again." (writing the waiting line failed)
- Small grey line: "It is on the board the next time you open Seedboard."
- **Cancel** (Escape) and **Send** (full green, Return; paler green — never grey — until something can be sent). On the Mac the page is 420 × 480.
- Cancel takes away the pictures it had kept for this share. Send writes each thing once (a second press writes nothing more).

## What becomes of each thing (in the app)
- Words → a sticky note; a list → a mind map (the same rule as paste, `Board.addWords`). Longer than 20,000 letters: cut.
- A link → a sticky note: the page's title, the address on the next line (no title: the address alone).
- A picture → shrunk in the share page to 2048 at the long side (never opened at full size; see-through parts laid on white, JPEG), then kept with the board's pictures (`PictureStore.adopt`) and laid as a picture thing.
- Each thing lies at `board.arrivalSpot` — a free column to the right of everything, one under the other: nothing is covered or moved.
- "New board" (or a board that was removed meanwhile, or became a timeline): ONE new board per Send, named after the first line of the words, else the link's title, else the site's name ("example.com"), else "Shared pictures" (40 letters at most), the next board colour, a name no other board has ("… 2").
- On the board that is open: one step that can be undone, and the things that came are chosen. While he types or drags, the lines wait and are tried again 3 seconds later.
- The line at the bottom: "4 things came in from Share." (one: "1 thing came in from Share."), 6 s with a pill **Show** (open board: brings them into sight) or **Open** (another board) when everything went to one board; otherwise 4 s without a pill. Pictures that could not be read: "1 picture from Share could not be read." in brick red (the problem tone).
- When: at the end of loading the boards, and every time Seedboard comes to the front (iPhone/iPad `didBecomeActive`; the Mac `NSApplication.didBecomeActiveNotification`, because the Mac's scene does not notice a switch between apps).
- Safety: a line is taken off the waiting list only AFTER its board was written on the device (`saveNow` + `flush`, and the store's "last write failed" list is checked). A line read twice lays nothing twice: the thing made carries the line's own identity. Unreadable lines are left in the list, never lost. Kept pictures no line names are swept after one day.
- The app tells the share page its boards in a small list (`boards.json`), 2 seconds after the boards change.

## Where the waiting list lives (`App/Sources/ArrivalBox.swift`)
1. PARAGON's shared folder (app group `group.com.schabbauer.amspara`, Mac `D24ENP83QQ.group.com.schabbauer.amspara`), its own corner `Seedboard/arrivals/` (`arrivals.jsonl`, `boards.json`, `pictures/`). Words, links AND pictures. On the Mac only for the sandboxed real app (a builder's unsigned trial build never gets PARAGON's real folder).
2. Fallback: the keychain group `D24ENP83QQ.com.schabbauer.AMSSeedboard` (after first unlock). Words and links only; the page then says pictures cannot be shared yet.
The share page writes into the first home it reaches; the app empties every home it reaches.
Entitlements: `App/Config/Share/AMSSeedboardShare.entitlements` (iPhone/iPad) and `…-macOS.entitlements` (sandbox, read a shared picture file, keychain group, app group). The app group sits in ONE block marked "APP GROUP BLOCK, begin/end" — the lead said the group IS attached to the Share bundle id, so it stays.

## Target and release
- `project.yml`: target `AMSSeedboardShare` (app-extension, iOS + macOS, bundle id `com.schabbauer.AMSSeedboard.Share`, `SKIP_INSTALL`, version/build from the project's `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`), a dependency of the app → embedded. Activation: text, 1 web link, 1 web page, up to 10 pictures.
- Checked in both unsigned builds: the app's `PlugIns` folder holds `AMSSeedboardShare.appex`; app and extension both 0.5 (5).
- `Tools/release.sh`: the archive signs both bundles (automatic signing with the key covers every target; `CURRENT_PROJECT_VERSION=<build>` on the command line reaches the extension too). New check after each archive, before the upload: stops the release if the share page is missing or its version/build differs from the app's, and prints "share page: 0.5 (N), keychain group yes, shared folder yes".

## Launch words (debug builds)
- `-sharePage` — the share page itself in a window, with made-up content (a link "Timber prices this spring" and 2 pictures) and the sample boards. `-sharePageNoPictures` — the same when pictures cannot be taken. `-night` for night.
- `-arrivalsFolder <folder>` — use that folder as the waiting place (also with `-sampleData`); `-arrivalsShow` presses the Show/Open pill at once.

## Identifiers
`shareIn.what`, `shareIn.picture`, `shareIn.boards`, `shareIn.newBoard`, `shareIn.board.<name>`, `shareIn.problem`, `shareIn.later`, `shareIn.cancel`, `shareIn.send`.

## Tests
- Rule tests: `Core/Tests/SeedboardCoreTests/Extension05Tests.swift`, 8 tests (the waiting line, what a share becomes, a link's note, the "what came" words, a new board's name, which board, landing beside everything and only once, the boards offered). All 302 rule tests pass.
- Screen test: `UITests/ShareInUITests.swift` (the page via `-sharePage`): compiles (build-for-testing, Mac), NOT run (the lead runs screen tests after the join).

## Seen and not seen
- Seen: both platforms build unsigned with the extension embedded; the app half on the Mac debug build with a scratch waiting list (words list + link + picture → a new board, "4 things came in from Share.", the list and its picture emptied afterwards); the page by day, by night and without pictures (`-sharePage`).
- NOT seen: the real share page inside another app's Share button (cannot run a share extension here), the keychain fallback on a device, a signed archive (builders may not build signed copies; `release.sh` was not run).

## Stored fields, marks
- No stored field added; board format unchanged. Marks: none wanted (sprout from the icon library, ring/tick/plus from the control marks).

## Join clashes to expect
`project.yml` (app dependencies + new target), `Tools/release.sh`, `App/Sources/AppModel.swift` (one line at the end of `load`), `App/Sources/BoardStore.swift` (one small function `notOnDevice`).

## Drive-by
None seen.
