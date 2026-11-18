# Panel before 0.5 — from thought to action (18 Nov 2026)

Lens: the hand-over from a board to PARAGON and the way back; the Timeline as a planning tool; sharing outward.
Read: `Docs/SPEC.md` (0.4), `Docs/PANEL-0.2.md`, the Seedboard code named below, and PARAGON's code at build 340 (read only: `TaskParser.swift`, `Capture.swift`, `Note.swift`). Nothing was built or run; every claim marked "read, not run" comes from the code alone.

The safety rule stays as it is in every proposal: Seedboard only adds (a new note, a new picture, lines at the end of PARAGON's waiting list). Reading PARAGON's notes is used in findings 1 and 7; nothing here changes a PARAGON file. Finding 2 is the one that needs Martin's clear yes, and says why.

Not proposed again (turned down in 0.2): picks 9, 22, 23, 27.

Ranked by how much each would lift the app.

---

## 1. The board shows what is sent and done — IDEA

**Today:** After Send the board goes blind. A to-do carries one mark, a purple ring with a tick, whether it is waiting, already in PARAGON, or long finished there (`App/Sources/CanvasDraw.swift:387-396`, `App/Sources/TimelineDraw.swift:165-168`). The list of sent to-dos is only used to stop a second sending and is never drawn (`Core/Sources/SeedboardCore/Paragon.swift:145-152`). "Last sent …" stands only on the Send page (`App/Sources/SendSheet.swift:116-127`). A sent branch leaves no trace at all (`App/Sources/AppModel.swift:521-522`; SPEC 9.3). Nothing is ever read back from PARAGON. "Open in PARAGON" goes by the title (`AppModel.swift:545-552`), so after a rename in PARAGON it opens nothing.

**Better:**
- Three marks instead of one (one picture with the three first): hollow purple ring = to do, not sent yet; filled purple ring = in PARAGON; green ring with a tick and greyed words = done in PARAGON (a grey ring with a dash = cancelled there).
- Reading back, never writing: when a sent board opens, and when Seedboard comes to the front, it READS the note it made (its place is kept in `SentInfo.path`, `Core/Sources/SeedboardCore/Board.swift:375-382`). If the note is no longer there, it looks through PARAGON's folder for the note that holds this board's own link `seedboard://board/<id>`, so a project that was renamed or moved to Archive is still found. Done lines are read by PARAGON's own rule (`- [x]`, `- [-]`; PARAGON `TaskParser.swift:464`) and matched to the things on the board by the words Seedboard sent (kept at Send in one new stored list: thing → words sent). A task re-worded in PARAGON simply stays "in PARAGON".
- One small purple line under the board's top bar: "Project “Summer cabin” · 5 of 13 done · checked 14:02" with Open in PARAGON (which now opens the note that was found, also after a rename). The same "5 of 13 done" after "Changed …" on the board's card and row.
- A sent branch marks its own ideas "in PARAGON" too, so the branch is no longer traceless.
- What was read is kept on the device only, never in the board file: looking never changes a board and makes no iCloud traffic. A note iCloud has not brought to this device yet: "not checked on this device yet".
- Do NOT write own `^t…` task ids into the note to make matching easier: those ids belong to PARAGON's Reminders sync ("assigned on first sync", PARAGON `TaskParser.swift:45`); a foreign id there is a risk. Words are the safe key.

**PARAGON change:** none (reading only). **Size:** L (M without the search for a moved note).

---

## 2. Send again adds only what is new — IDEA, with one BUG

**Today:** A second Send always makes a second whole note, "Title (board 2)", with every task again (`App/Sources/ParagonGate.swift:151-155`, `Paragon.swift:38-55`; the page says so, `SendSheet.swift:129`). So a plan that grows after its first Send cannot follow into PARAGON: the new idea can only go to the Inbox, far from its project. BUG (read, not run): a to-do that already went to the Inbox is written AGAIN as a task when the board is later sent as a note or a project — neither text looks at the sent list (`Paragon.swift:103`, `Core/Sources/SeedboardCore/ProjectPlan.swift:36-73`).

**Better:**
- The board remembers every thing that became a task, not only the ticked boxes (one more stored list beside `sentTodos`, `Board.swift:413-415`; board format 5).
- When the board is already a project (or note) in PARAGON and holds new task things, the Send page opens with a new first row, already chosen: **Add what is new to “Summer cabin”** — "3 new tasks go into the project. Nothing that is there is touched." Send writes 3 lines to PARAGON's waiting list, aimed at that note. The waiting line already has this aim (`Paragon.swift:179`, `note(path:)`, unused so far), and PARAGON files such a line itself at the end of the note's Tasks (PARAGON `Capture.swift:214-246`, `Note.swift:270-274`). They appear when he switches to PARAGON (340 or newer).
- Seedboard looks first (reading): if the note is gone from its place, the row says "The project is not where it was: the 3 tasks go to the Inbox" — which is what PARAGON does by its own rule.
- New bars of a timeline go with their days (as in finding 6).
- What cannot follow is said, not hidden: "2 things were renamed and 1 bar moved since 18 Nov. PARAGON keeps the old ones." with the second choice **Send a fresh copy** (today's behaviour, a second note).
- The BUG: in a note or project, a box that is already in the Inbox is written as a plain line "- Permit (already in the Inbox)", and the count line on the page says so.

**The rule:** Seedboard still only adds lines to the waiting list, exactly as for Inbox to-dos, and never opens the note. But for the first time what it sends ends up inside a note that already exists — written there by PARAGON. That keeps the letter of the rule and needs Martin's clear yes. Safe variant without it: the new tasks go to the Inbox with the project in their words, "Order timber — [[Summer cabin]]", and he files them by hand.

**PARAGON change:** none. Limit: the new tasks land at the end of the Tasks part, not under their own branch or phase heading; placing them under a heading would need a PARAGON change. **Size:** M.

---

## 3. The timeline shows done, late and "catch up" — IDEA

**Today:** The Timeline has the Today line, "comes after" (which only ever pushes later, `Core/Sources/SeedboardCore/Timeline.swift:500-530`), milestones and phases. A plan needs four more things it does not have: no bar can be marked done; nothing shows that a bar is late; no line says how far the plan is; nothing helps when he is behind — every late bar must be dragged by hand. Smaller: the Weeks scale shows "1 Dec", no week number (`Timeline.swift:258-262`); a phase's rows do not move with it (SPEC 3.13, Note); scale and place are forgotten each time (SPEC 2.8).

**Better:**
- **Done** in the chosen bar's buttons (one new stored field on a bar, the day it was done). A done bar is paler with a tick at its end, its name grey. With finding 1, a task ticked in PARAGON sets it by itself.
- **Late:** a bar whose last day is before today and is not done gets a red end and a red name. A bar running now is darker up to the Today line.
- **One line** above the names column: "3 of 8 done · 1 late · ends 20 Feb".
- **Catch up** beside the Today button, shown only when something is late: every late bar is stretched to end today, bars not started that should have are moved to start today, and what comes after is pushed along by the rule that is there. One Undo step, and a line: "4 bars moved. The plan now ends 27 Feb (was 20 Feb)."
- Week numbers on the Weeks scale ("w 49" — the Swedish habit); a phase carries its rows when dragged; the timeline opens at the scale and place it was left.

**PARAGON change:** none. **Size:** M (L with phases and the remembered place).

---

## 4. A mind map becomes a timeline — IDEA

**Today:** A board is either a map / flow or a timeline, for good. The road "what → when → do" breaks in the middle: after thinking in a mind map, every bar must be typed again on a new Timeline board. A mind map sent as a project has no day on any task (`Paragon.swift:115-140`).

**Better:** More menu and File menu: **Make a timeline of it…** It is the mirror of the project rule (`ProjectPlan.swift:36-73`), so the two can never disagree:
- each main branch with ideas under it → a phase; each idea that would become a task (the ticks decide, exactly as for a project) → a bar under that phase, in the map's order; deeper ideas → bars right after their parent;
- flow shapes in arrow order (`Paragon.swift:323-340`) → bars joined with "comes after";
- bars start today, one week each, one after the other inside a phase; the phases start together.
A new board "Summer cabin timeline" opens at once; the mind map stays as it is. Line: "12 bars in 3 phases. Drag them to their days." Then Send as a project gives tasks with days. (The way back exists: Copy the board as text, then Paste a list as a mind map.)

**PARAGON change:** none. **Size:** M.

---

## 5. The Send page shows what PARAGON gets — IDEA, with four BUGS

**Today:** Three rows of words, and no look at the result (`SendSheet.swift:69-81`). He sends blind and checks in PARAGON. And four lines are wrong or missing:
- (a) BUG: after to-dos the line says "They show the next time PARAGON opens." (`ParagonGate.swift:148`; the guide too, `App/Sources/Guide.swift:415`). PARAGON is usually open already.
- (b) BUG: "No to-do boxes are waiting. Choose a box and press To do first." also shows when boxes ARE ticked and all were sent before (`SendSheet.swift:80`).
- (c) BUG (read, not run): on a timeline, "As a project" shows "The 2 to-do boxes become tasks in it." or no line at all, though every bar becomes a task — the project line knows no timeline (`SendSheet.swift:102-113`, `ProjectPlan.swift:123-142`).
- (d) After Send the page closes and a line shows for 4 seconds (`AppModel.swift:531`, `556-562`); there is no way to jump to the new note.

**Better:**
- Under the three rows a box **What PARAGON gets**, about 9 rows high, scrolling: a note = the small picture and the first outline lines; a project = headings bold, tasks with their box, the day at the right in purple ("12 Dec"), plain lines grey; to-dos = the tasks. It is drawn from the very text Send writes (`Paragon.swift:77`, `115`), so it cannot differ from what arrives. Under it one count line: "13 tasks · 3 headings · last day 20 Feb".
- (a) on the to-dos row, in the line after Send and in the guide: "The to-dos appear in PARAGON's Inbox when you switch to PARAGON (PARAGON 340 or newer)."
- (b) "All 4 to-do boxes are already in PARAGON."
- (c) on a timeline: "All 8 bars and 1 milestone become tasks with their days."
- (d) after a note or project the line stays 8 seconds and carries **Open in PARAGON**.

**PARAGON change:** none. **Size:** M (the four word fixes alone: S).

---

## 6. Inbox to-dos keep their day and origin — BUG and IDEA

**Today:** BUG: a ticked bar on a timeline goes to the Inbox as bare words, "Permit" — its days are dropped (`Paragon.swift:145-152`; the test expects exactly that, `Core/Tests/SeedboardCoreTests/TimelineTests.swift:352`), while the same bar in a project carries "(starts 1 Dec) >2026-12-05" (`Timeline.swift:671-676`). And every Inbox to-do arrives without a word about the board it came from (`Paragon.swift:196-200`): a next step cut off from its thought.

**Better:**
- A timeline to-do goes as "Permit (starts 1 Dec) >2026-12-05". PARAGON reads the day out of a waiting line with its own task reader (PARAGON `Capture.swift:244`, `TaskParser.swift:467`), so the task lands in the Inbox already dated.
- Every Inbox to-do ends with its way back: "Order timber [Summer cabin](seedboard://board/<id>)" (PARAGON 339 opens it). When the board is already a project in PARAGON: "Order timber — [[Summer cabin]]", which points at the project instead. A switch on the Send page, **Say where they come from**, on at first and remembered.
- This link is also what lets finding 1 find Inbox to-dos again after he has filed them elsewhere.
- One look on the example notes before shipping: how PARAGON shows a link inside a task row.

**PARAGON change:** none. **Size:** S.

---

## 7. A PARAGON project opens as a board — IDEA

**Today:** Nothing comes from PARAGON into a board except text copied by hand. "Paste a list as a mind map" reads headings, bullets and check boxes (`Core/Sources/SeedboardCore/Outline.swift:20-68`), but throws the ticks away (`Outline.swift:102-104`) and leaves PARAGON's marks in the words: ">2026-12-12", "@done(…)", "~45m".

**Better (reading only; says so on the page: "Seedboard reads the project. It does not change it."):**
- Step 1 (S): the list reader understands PARAGON's task lines. `- [ ]` → an idea with the To do mark, shown as "in PARAGON" so it is never sent a second time; `- [x]` → done; the day is lifted out of the words and kept; "@done(…)", "~45m", "!!" leave the words.
- Step 2 (M–L): in the Starters chooser a purple card **From PARAGON…**: the projects in PARAGON's Projects folder with a search field, each with "8 open · 5 done". Choose one, then **Mind map** (title = the middle, headings = branches, tasks = ideas, sub-tasks under them) or **Timeline** (a task with a day = a bar ending that day, starting at "(starts …)" when it says so, else one day; headings = phases; "4 tasks without a day were left out").
- The new board remembers the note as if it had been sent, so the status line and done marks (finding 1) and "Add what is new" (finding 2) work from the first minute: a project born in PARAGON gets its picture, and new thoughts go back as new tasks.
- Any other note the same way: its headings and bullets as a mind map.

**PARAGON change:** none. **Size:** L (step 1 alone: S).

---

## 8. Share: PDF, print, outline file — IDEA

**Today:** Outward there is "Share a picture…" (a PNG; `App/Sources/BoardView.swift:259-263`, `App/Sources/BoardPicture.swift:13-40`) and "Copy the board as text" to the clipboard only (`BoardView.swift:254-258`). No PDF, no printing, no ⌘P. A big board as a PNG is either huge or unreadable. The text leaves the lanes out (SPEC 9.3).

**Better:** One line **Share…** in More and in File, opening a small page with four tiles (hand-drawn marks), Cancel / Done:
- **Picture** — the PNG as now.
- **PDF** — the board as drawn shapes, sharp at any size; the name and the date small at the top; the paper upright or on its side by the board's shape; a switch "Outline on a second page".
- **Outline** — the board's words as a text file through the share page (Mail, Files, Messages), the same words the PARAGON note gets, lanes included.
- **Print** — ⌘P on the Mac, AirPrint on iPhone and iPad; it prints the PDF. A long timeline: "On one page" or "Readable: 3 pages side by side".

**PARAGON change:** none. **Size:** M.

---

## 9. A bar shows in PARAGON when it starts — IDEA

**Today:** A bar becomes one task due on its LAST day; its first day is only words, "(starts 8 Dec)" (`Timeline.swift:655-676`; guide `Guide.swift:267`). So PARAGON says nothing on the day a two-week job should begin, and the task first turns up when it is due. PARAGON has no start day, and a do-day with a deadline would turn the task red on its second day (PARAGON `TaskParser.swift:426-442`). The timeline's best information, when to start, is lost at the hand-over.

**Better, without touching PARAGON (S):** on a timeline's Send page a switch **Also remind me when a bar starts**, off at first. On: every bar longer than 3 days gets one more line under the same heading, "- [ ] Start: Foundation >2026-12-08". The preview of finding 5 shows them before he sends.

**Better, the real cure (a PARAGON change, not for 0.5):** a start day on a PARAGON task, so a task shows from its first day and is late only after its last; Seedboard would then write the bar as it is. Worth a line in PARAGON's own idea list once its quiet week is over.

**PARAGON change:** the safe variant none; the real cure yes. **Size:** S.

---

## Order of building, if several are picked

6 and the word fixes of 5 first (small, two are bugs). 1 and 2 share one new stored list (what was sent, with its words) — build them together. 3 uses 1 for "done". 7 leans on 1 and 2. 4, 8 and 9 stand alone.
