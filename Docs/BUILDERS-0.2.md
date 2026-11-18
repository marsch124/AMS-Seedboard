# Rules for every builder of 0.2

AMS Seedboard: SwiftUI, iPhone + iPad + Mac from one target (XcodeGen, `project.yml`). Rules live in the Swift package `Core/` (SeedboardCore, with its tests); the app is `App/Sources`. The board is ONE drawn Canvas (`CanvasView` input, `CanvasDraw` painter with day/night `Paint`, `BoardSession` state + undo, `BoardView` bars). Your pick numbers are explained in `Docs/PANEL-0.2.md`; today's behaviour in `Docs/SPEC.md`.

## Where you work
- ONLY in your own copy (the worktree folder and branch named in your brief). Never write to `~/Developer/AMS-Seedboard` itself, another builder's copy, `~/Developer/AMS-Icons`, PARAGON's code or notes, or any iCloud folder.
- Do NOT boot or use simulators, do NOT run screen (UI) tests, do NOT launch the app: other conversations use the Mac's screen and simulators. Screen tests and pictures are run once at the end by the lead.
- Other builders work at the same time in the same files (`CanvasView`, `CanvasDraw`, `BoardSession`, `BoardView`, `Board.swift`). Keep changes to shared files in small, tight hunks and put new code in NEW files (extensions, new views, new Core files). Do not reformat, reorder or rename existing code. Do not fix things outside your brief — note them instead.
- Two builders are fixing the list "Fixed in any case" in `Docs/PANEL-0.2.md` (B1–B8, S1–S7) right now. Do not fix those.

## Code rules
- Every new rule is a pure function in SeedboardCore with ONE small data test. Run `cd Core && swift test` (seconds). No screen-test runs.
- Stored data: add new stored fields as optionals with tolerant decoding (old files must still load; fields this version does not know are carried through). Put new coding keys on their OWN new `case` line under the existing one (fewer clashes between builders). The stored format becomes 2 in this release — the lead sets the number; do not change it yourself unless your brief says so.
- Undo: every change the owner makes is one whole undo step (`BoardSession`).
- New screen or sheet → one screen test in a NEW file `UITests/<Feature>UITests.swift` that finds things by accessibility identifier (see `UITests/SeedboardUITests.swift` for the launch pattern and `-sampleData`). Write it, do not run it. Give every new button an accessibility identifier. Trap: `.accessibilityIdentifier` on a container replaces its buttons' identifiers — put `.accessibilityElement(children: .contain)` before it. Keep every existing identifier.
- For pictures the lead needs launch options: if your feature has a screen or state worth a picture, add a launch argument for it next to the existing ones in `AppModel.load()` / `LaunchOptions` (e.g. `-board <word>`, `-pick <word>`) and add made-up content to `Sample.swift` if needed. Name them in your notes.

## Look (the owner's house style)
- Compact: minimal padding, Apple's standard text sizes, rows as tall as their words.
- Colourful: each part of the app has its own colour (`Theme`) for its headings, buttons and marks; pleasing by day AND by night — check both `Paint` sets.
- The main button is always full colour, never grey. Every page where something is changed has Cancel and Save (or Done); on the Mac Escape is Cancel.
- Icons: hand-drawn marks only, never SF Symbols, never emoji. Existing marks: `Glyph.app(AppMark)` / `.control(ControlMark)`. For a NEW mark use `Glyph.new(NewMark)` from `App/Sources/NewMarks.swift` — it shows a stand-in until the lead has the real drawings added to the icon library. If the mark you need is not in `NewMark`, use the nearest one and write a line `ICON-WANTED: <what it should show>` in your notes. Do not edit `NewMarks.swift`.
- Words in the app: plain, non-technical, sentence case ("Bring back", "Line up").

## Texts — do NOT edit `Docs/SPEC.md` or `App/Sources/Guide.swift`
Write ONE new file `Docs/notes-0.2/<your-name>.md` instead, with these parts (a writer joins them at the end):
1. **What's new** — per pick: what was there before, what is there now, with numbers, in plain words.
2. **How it works** — the guide text for what you built (how the owner uses it: which button, which key, which drag).
3. **Spec** — every detail (sizes, colours, rules, stored fields, keys, identifiers).
4. **For the lead** — launch arguments for pictures, screen-test file, `ICON-WANTED` lines, anything left open, and what only a real device can prove.

## Finish
- Both apps must compile: `xcodegen generate` in your worktree root, then
  `xcodebuild -scheme AMSSeedboard -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build-ios build 2>&1 | grep -E "error:|BUILD"` and
  `xcodebuild -scheme AMSSeedboard -configuration Debug -destination 'platform=macOS' -derivedDataPath build-mac CODE_SIGN_IDENTITY="-" CODE_SIGN_ENTITLEMENTS="" build 2>&1 | grep -E "error:|BUILD"`.
- Commit on your branch (message ends with the line `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`). Do NOT push, do NOT merge.
- Report once, at most 15 lines: what was built per pick, tests added + test count, both builds' result, stored fields added, what is left open or only a real device can prove, the commit hash.
