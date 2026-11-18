import SwiftUI
import SeedboardCore

// 0.5, pick 18: a timeline shows how far the plan is. A done bar is paler with a tick at its end and its
// name grey; a late bar (its last day is behind today, and it is not done) has a red end and a red name;
// a bar in work is darker up to the Today line; one line above the names says "3 of 8 done · 1 late ·
// ends 20 Feb"; the Weeks scale carries the week's number. The rules are in SeedboardCore (TimelinePlan.swift).

extension TimelinePainter {
    /// Where a Monday's date stands on the Weeks scale (a little lower than on the other scales: the week's
    /// number stands over it), and where the number stands.
    static let weekDateY: CGFloat = 35
    static let weekNumberY: CGFloat = 23.5

    /// Done on the board, or ticked off in PARAGON (read back on this device).
    func isDone(_ item: Item) -> Bool { item.span != nil && (item.isDone || todoStates[item.id] == .done) }

    /// Its last day is behind today and it is not done.
    func isLate(_ item: Item) -> Bool {
        guard let span = item.span else { return false }
        return span.end < today && !isDone(item)
    }

    /// The things PARAGON has ticked off.
    var doneInParagon: Set<UUID> { Set(todoStates.filter { $0.value == .done }.keys) }

    /// A row's name in the names column: grey when it is done, red when it is late; nil = as always.
    func nameShade(_ item: Item) -> Color? {
        if isDone(item) { return paint.faint }
        return isLate(item) ? paint.line("red") : nil
    }

    /// How strongly a bar is filled: a done bar is paler.
    func barStrength(_ item: Item) -> Double { isDone(item) ? (paint.night ? 0.42 : 0.36) : 1 }

    /// Laid over a bar that is drawn: the tick of a done one; for one that is not done, the days behind it
    /// darker (up to the Today line) and, when it is late, a red end.
    func drawState(_ item: Item, _ box: CGRect, _ ctx: inout GraphicsContext) {
        let own = paint.line(item.colour.isEmpty ? (item.kind == .milestone ? "purple" : "blue") : item.colour)
        let red = paint.line("red")
        if isDone(item) {
            // Inside the bar's end when there is room, otherwise right behind it.
            let inside = item.kind == .bar && box.width >= 22
            let c = CGPoint(x: inside ? box.maxX - 10 : box.maxX + 9, y: box.midY)
            var mark = Path()
            mark.move(to: CGPoint(x: c.x - 3.6, y: c.y + 0.3))
            mark.addLine(to: CGPoint(x: c.x - 1.0, y: c.y + 3.0))
            mark.addLine(to: CGPoint(x: c.x + 3.8, y: c.y - 2.8))
            ctx.stroke(mark, with: .color(own), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            // 0.8: the day it was done, small and grey, right after the bar (nothing for one ticked only in PARAGON).
            if let words = item.doneLabel(today: today) {
                // Always the same place, past the bar's end: clear of a "comes after" arrow leaving the end, and of
                // the grip and the dot a chosen bar wears there, so the label never jumps when the bar is chosen.
                let x = max(box.maxX + Self.dotGap + Self.dotRadius + 6, inside ? 0 : c.x + 9)
                ctx.draw(Text(words).font(.system(size: 10, weight: .medium)).foregroundColor(paint.faint),
                         at: CGPoint(x: x, y: box.midY), anchor: .leading)
            }
            return
        }
        if item.kind == .milestone {
            guard isLate(item) else { return }
            var diamond = Path()
            diamond.move(to: CGPoint(x: box.midX, y: box.minY)); diamond.addLine(to: CGPoint(x: box.maxX, y: box.midY))
            diamond.addLine(to: CGPoint(x: box.midX, y: box.maxY)); diamond.addLine(to: CGPoint(x: box.minX, y: box.midY))
            diamond.closeSubpath()
            ctx.stroke(diamond, with: .color(red), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            return
        }
        var inner = ctx
        inner.clip(to: Path(roundedRect: box, cornerRadius: min(7, box.width / 2)))
        let todayX = CGFloat(geometry.todayX(today))
        if todayX > box.minX {
            let behind = CGRect(x: box.minX, y: box.minY, width: min(todayX, box.maxX) - box.minX, height: box.height)
            inner.fill(Path(behind), with: .color(.black.opacity(paint.night ? 0.30 : 0.20)))
        }
        if isLate(item) {
            let wide = min(6, box.width / 2)
            inner.fill(Path(CGRect(x: box.maxX - wide, y: box.minY, width: wide, height: box.height)), with: .color(red))
        }
    }

    /// The one line in the corner above the names: "3 of 8 done · 1 late · ends 20 Feb", on as many short
    /// lines as the corner needs (at most three). "1 late" is red.
    func drawProgress(_ ctx: inout GraphicsContext) {
        let parts = board.timelineProgress(today: today, also: doneInParagon).parts(today: today)
        guard !parts.isEmpty else { return }
        let names = CGFloat(geometry.namesWidth), header = CGFloat(geometry.headerHeight)
        let size: CGFloat = names < 140 ? 10 : 11
        let room = names - 14
        /// The pieces of one line as they are drawn, with the small dot between them, and how wide they are.
        func pieces(_ words: [String]) -> (texts: [GraphicsContext.ResolvedText], widths: [CGFloat]) {
            var texts: [GraphicsContext.ResolvedText] = []
            var widths: [CGFloat] = []
            func add(_ words: String, _ shade: Color, air: CGFloat) {
                let text = ctx.resolve(Text(words).font(.system(size: size, weight: .medium)).foregroundColor(shade))
                texts.append(text)
                widths.append(text.measure(in: CGSize(width: 2000, height: 100)).width + air)
            }
            for (n, word) in words.enumerated() {
                // The dot has 4 points of air on each side (it is drawn 4 in from where its room begins).
                if n > 0 { add("·", paint.faint, air: 8) }
                add(word, word.hasSuffix(" late") ? paint.line("red") : (word.hasSuffix(" done") ? paint.ink : paint.faint), air: 0)
            }
            return (texts, widths)
        }
        // As many pieces on a line as fit.
        var lines: [[String]] = []
        for part in parts {
            if var last = lines.last {
                last.append(part)
                if pieces(last).widths.reduce(0, +) <= room {
                    lines[lines.count - 1] = last
                    continue
                }
            }
            lines.append([part])
        }
        let shown = Array(lines.prefix(3))
        let step = size + 2.5
        var y = (header - CGFloat(shown.count) * step) / 2 + step / 2
        var corner = ctx
        corner.clip(to: Path(CGRect(x: 0, y: 0, width: names, height: header)))
        for line in shown {
            let made = pieces(line)
            var x: CGFloat = 8
            for (n, (text, wide)) in zip(made.texts, made.widths).enumerated() {
                corner.draw(text, at: CGPoint(x: x + (n % 2 == 1 ? 4 : 0), y: y), anchor: .leading)
                x += wide
            }
            y += step
        }
    }

    /// "w 49" over a Monday's date on the Weeks scale.
    func drawWeek(_ monday: Day, x: CGFloat, _ ctx: inout GraphicsContext) {
        let text = ctx.resolve(Text(monday.weekWord).font(.system(size: 9.5, weight: .semibold)).foregroundColor(paint.faint))
        ctx.draw(text, at: CGPoint(x: x + 5, y: TimelinePainter.weekNumberY), anchor: .leading)
    }
}

extension BoardSession {
    /// The bars PARAGON has ticked off (read back on this device; never kept in the board).
    var timelineDoneInParagon: Set<UUID> {
        Set(ParagonEcho.shared.marks(for: board).filter { $0.value == .done }.keys)
    }

    /// How many bars are late today: "Catch up" shows only when this is not 0.
    var timelineLateCount: Int {
        board.isTimeline ? board.lateBars(today: .today(), also: timelineDoneInParagon).count : 0
    }

    /// "3 of 8 done · 1 late · ends 20 Feb" (empty for a timeline without bars).
    var timelineProgressLine: String {
        let today = Day.today()
        return board.timelineProgress(today: today, also: timelineDoneInParagon).line(today: today)
    }

    /// True when every chosen bar or milestone is done (on the board or in PARAGON).
    var timelineChosenDone: Bool {
        let ids = selection.filter { board.item($0)?.span != nil }
        let inParagon = timelineDoneInParagon
        return !ids.isEmpty && ids.allSatisfy { board.item($0)?.isDone == true || inParagon.contains($0) }
    }

    /// The Done button: marks the chosen bars and milestones done today, or takes the mark off when all of
    /// them are done. One Undo step. Returns words to say, if any.
    @discardableResult
    func timelineToggleDone() -> String? {
        let ids = selection.filter { board.item($0)?.span != nil }
        guard !readOnly, !ids.isEmpty else { return nil }
        if editing != nil { commitEdit() }
        let inParagon = timelineDoneInParagon
        let allMarked = ids.allSatisfy { board.item($0)?.isDone == true }
        change { $0.toggleDone(ids, on: .today()) }
        // The mark came off, but PARAGON has the task ticked off: say why the bar still looks done.
        if allMarked, ids.contains(where: inParagon.contains) { return "It is ticked off in PARAGON, so it stays done." }
        return nil
    }

    /// Catch up: every late bar is brought to today and what comes after is pushed along. One Undo step.
    /// Returns the line to say ("4 bars moved. The plan now ends 27 Feb (was 20 Feb)."), nil when nothing was late.
    @discardableResult
    func timelineCatchUp() -> String? {
        guard !readOnly, board.isTimeline else { return nil }
        if editing != nil { commitEdit() }
        let today = Day.today()
        let inParagon = timelineDoneInParagon
        var done: CatchUp?
        change { done = $0.catchUp(today: today, also: inParagon) }
        return done?.line(today: today)
    }
}
