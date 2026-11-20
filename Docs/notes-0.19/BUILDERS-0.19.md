# Seedboard 0.19 — brief for every lane helper

You build a few of Martin's picks for AMS Seedboard 0.19 (iPhone, iPad, Mac; SwiftUI; shared logic in the Swift
package `Core/`). The idea list with the exact wording is `Docs/IDEAS-0.18.md` in your copy. The full written
spec of the app as it stands is `Docs/SPEC.md` (1850 lines — grep it for your area before you change anything; a
pick may already be half there).

## Your copy
- You work ONLY in your own git worktree: `/Users/martinschabbauer/Developer/AMS-Seedboard-wt-<lane>` on branch
  `wt19-<lane>`. Never touch `/Users/martinschabbauer/Developer/AMS-Seedboard` itself, other worktrees, his real
  boards, his running apps, or any simulator (no simulator runs at all — other helpers share the Mac).
- Groundwork is already on your branch (commit 87766b8): board format 9 with these new stored fields, ready to
  use — do NOT add other stored fields (a new stored field breaks `StoredFieldsTests`; if you truly need one, say so
  in your report and use a per-device `UserDefaults` key or an existing field instead):
  - Item: `note: String?` (a short note on a milestone, or the grey note box beside a message), `initials: String?`
    (bar), `cropShape: String?` ("circle"), `printFrame: Bool?`, `widths: [Double]?` (table column widths),
    `tickColumn: Int?` (table; cells in it are "x" ticked / "" not).
  - Link: `bend: [Double]?` ([dx, dy] of the middle knob from the plain line's middle).
  - Board: `paper: String?` ("paper", "warmGrey", "nightBlue"; nil = plain as now), `numberBranches: Bool?`,
    `mapLook: String?` ("lines", "curves", "boxes"; nil = as before).
  - Existing and useful: `Item.textSize` ("small" may now also mean a small sticky note), `Link.dashed`,
    `Board.colour` (the board's dot in the list), `Item.doneDay`, `Item.todo`, `Board.due`.
- Version is already 0.19 (19) in `project.yml`. Do not change it.

## Do NOT touch
`App/Sources/Guide.swift` (What's new / How it works / Signs), `Docs/SPEC.md`, `README.md`, `project.yml`
(unless you must add a usage line — say so), entitlements, the release tools, AMS-Icons. Texts are written later
from your report.

## Look (his rules)
- Apple-like. NEW marks are SF Symbols (Apple's own) — never draw new marks, never emoji. Put every SF Symbol name
  you add in ONE small enum in your own new file (e.g. `enum Marks19Timeline { static let repeatBar = "repeat" }`)
  so the lead can swap a name after Martin looks at them. Reuse the app's existing marks where one already fits.
- A button that is only a symbol gets a word, unless everyone knows it (+, gear). Main button full colour.
- Every page where something is changed has Cancel and Save/Done; on the Mac Escape = Cancel.
- One mark / one colour = one meaning in the whole app. Red = late or a warning only. Purple = PARAGON only.
  Green ring/tick = done. Never reuse a mark for a different meaning.
- Compact, Apple standard text sizes, works by day and by night (use the app's `Paint`/`Theme` colours).
- Every new control gets an accessibility identifier (`<area>.<thing>`, like the existing ones) so a screen test can
  find it.
- Everything that changes a board must be undoable through the board's existing one undo path (see how
  neighbouring commands do it: `session.change { … }` or the like) and refused on read-only boards
  (`canBeChanged`).

## Build and test in your copy (all must pass before you finish)
```
cd /Users/martinschabbauer/Developer/AMS-Seedboard-wt-<lane>
xcodegen generate
swift test --package-path Core            # all Core tests green (554 + yours)
xcodebuild build -project AMSSeedboard.xcodeproj -scheme AMSSeedboard -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet
xcodebuild build -project AMSSeedboard.xcodeproj -scheme AMSSeedboard -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet
```
(First build fetches the AMS-Icons package — that is fine.) Fix every error and new warning you caused.

Tests, lean (his rule): put the rules in `Core` where you can, and add ONE small data test file
`Core/Tests/SeedboardCoreTests/<Lane>19Tests.swift` — one short test per new rule. If you add a new page or card,
add ONE screen test `UITests/<Lane>19UITests.swift` that finds it by identifier (launch with `-sampleData` LAST in
the arguments; look at `UITests/List17UITests.swift` for the pattern) — write it, make it compile
(`xcodebuild build-for-testing` is enough), do NOT run it (no simulators).

## Finish
1. `git add -A && git commit -m "0.19 <lane>: <picks>"` on your branch (end the message with the line
   `Co-Authored-By: Claude Sonnet <noreply@anthropic.com>`). Do not merge, push or switch branches.
2. Write your report to `/Users/martinschabbauer/Library/Application Support/Claude/side-session-notes/local_4469037b-83de-4d59-b029-fe1ed0d861fc/built19-<lane>.md`:
   per pick — what it does now in plain words, the EXACT words on screen, keys, identifiers, SF Symbols used,
   numbers (sizes, limits), anything that already existed before (say "before: … now: …"), anything left out and why,
   and what you could not see. Plus a line "Signs:" listing any new mark or colour with its meaning.
3. Your final answer: at most 15 lines — picks done, build/test result, commit hash, anything the lead must decide.
