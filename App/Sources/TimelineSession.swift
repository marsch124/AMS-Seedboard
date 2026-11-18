import SwiftUI
import SeedboardCore

/// What an open timeline board remembers about its view (none of it is kept in the file).
struct TimelineLook: Equatable {
    /// How wide a day is drawn. Zooming steps through days, weeks and months.
    var scale: TimeScale = .weeks
    /// A pinch or ⌘-scroll adds up here until it is worth one step of the scale.
    var pinch: CGFloat = 1
    /// The iPhone: a narrower column of names.
    var narrow = false

    #if os(macOS)
    static let rowHeight: Double = 34
    static let barHeight: Double = 22
    static let nameSize: CGFloat = 13
    #else
    static let rowHeight: Double = 40
    static let barHeight: Double = 24
    static let nameSize: CGFloat = 15
    #endif
    static let headerHeight: Double = 44
    static let wideNames: Double = 170
    static let narrowNames: Double = 104
    /// One pinch step: the scale changes when the fingers have moved this much apart or together.
    static let pinchStep: CGFloat = 1.2

    /// The room at the bottom that the tools, the zoom buttons and the chosen bar's buttons take
    /// (on the iPhone they stand in rows above each other).
    var bottomRoom: Double { narrow ? 215 : 150 }
}

/// The timeline board's side of the open board. The view's place is the session's own `offset`
/// (sideways: the days; up and down: the rows), so the top bar, Undo and the Board menu work as on any board.
extension BoardSession {
    var timelineGeometry: TimelineGeometry {
        TimelineGeometry(scale: timeline.scale,
                         namesWidth: timeline.narrow ? TimelineLook.narrowNames : TimelineLook.wideNames,
                         headerHeight: TimelineLook.headerHeight, rowHeight: TimelineLook.rowHeight,
                         barHeight: TimelineLook.barHeight, slide: offset)
    }

    /// The width left for the days, beside the names.
    private var chartWidth: CGFloat { max(viewSize.width - CGFloat(timelineGeometry.namesWidth), 60) }

    /// Where a bar, a milestone or a phase heading is on screen. A phase has no bar of its own: its row's band.
    func timelineRect(of id: UUID) -> CGRect? {
        guard let item = board.item(id), let row = board.timelineRow(of: id) else { return nil }
        let g = timelineGeometry
        guard let span = item.span else {
            return CGRect(x: g.namesWidth, y: g.y(ofRow: row), width: Double(chartWidth), height: g.rowHeight)
        }
        return item.kind == .milestone ? g.diamond(on: span.start, row: row) : g.bar(from: span.start, to: span.end, row: row)
    }

    // MARK: The view

    /// Shows the whole timeline: the closest scale at which everything (with today) fits, from its first day.
    func timelineFit() {
        guard viewSize.width > 10 else { return }
        let today = Day.today()
        let bare = board.timelineRange(today: today, air: 0)
        let scale = TimeScale.fitting(days: (bare.last - bare.first + 1) + 2 * TimeScale.weeks.air, width: Double(chartWidth))
        timeline.scale = scale
        timeline.pinch = 1
        let range = board.timelineRange(today: today, air: scale.air)
        let wide = Double(range.last - range.first + 1) * scale.pointsPerDay
        // Narrower than the screen: in the middle. Wider (a very long plan): from its first day.
        let lead = max((Double(chartWidth) - wide) / 2, 0)
        offset = CGSize(width: timelineGeometry.slide(showing: range.first, after: lead), height: 0)
    }

    /// Brings today into view, a third of the way in from the names.
    func timelineShowToday() {
        guard viewSize.width > 10 else { return }
        let g = timelineGeometry
        let lead = Double(chartWidth) / 3 - g.scale.pointsPerDay / 2
        offset = CGSize(width: g.slide(showing: .today(), after: lead), height: offset.height)
        // A step of zero: the board counts as moved by its owner, so it is not shown whole again by itself.
        pan(by: .zero)
    }

    /// Days → weeks → months (further away) or back (closer). The day under the point stays where it is.
    func stepTimeScale(closer: Bool, around x: CGFloat? = nil) {
        guard let next = closer ? timeline.scale.closer : timeline.scale.further else { return }
        setTimeScale(next, around: x)
    }

    func setTimeScale(_ scale: TimeScale, around x: CGFloat? = nil) {
        let g = timelineGeometry
        let anchor = Double(x ?? (CGFloat(g.namesWidth) + chartWidth / 2))
        let dayUnder = (anchor - g.namesWidth - Double(offset.width)) / g.scale.pointsPerDay
        timeline.scale = scale
        timeline.pinch = 1
        offset = CGSize(width: anchor - g.namesWidth - dayUnder * scale.pointsPerDay, height: offset.height)
        pan(by: .zero)
    }

    /// A pinch, ⌘-scroll or ⌘+ / ⌘−: adds up, and steps the scale each time it passes one step.
    func timelineZoom(by ratio: CGFloat, around point: CGPoint) {
        guard ratio.isFinite, ratio > 0 else { return }
        timeline.pinch *= ratio
        if timeline.pinch >= TimelineLook.pinchStep {
            timeline.pinch = 1
            stepTimeScale(closer: true, around: point.x)
        } else if timeline.pinch <= 1 / TimelineLook.pinchStep {
            timeline.pinch = 1
            stepTimeScale(closer: false, around: point.x)
        }
    }

    /// The rows never slide further than their last one; the days slide freely.
    func clampTimeline() {
        let g = timelineGeometry
        let rows = Double(board.timelineRows.count)
        // Room under the last row for the tools at the bottom.
        let lowest = min(0, Double(viewSize.height) - g.headerHeight - rows * g.rowHeight - timeline.bottomRoom)
        let y = min(0, max(Double(offset.height), lowest))
        if y != Double(offset.height) { offset = CGSize(width: offset.width, height: y) }
    }

    /// Slides just enough to bring a row (and the start of its bar) into sight.
    func timelineReveal(_ id: UUID) {
        guard viewSize.width > 10, let row = board.timelineRow(of: id) else { return }
        let g = timelineGeometry
        var dx = 0.0, dy = 0.0
        let top = g.y(ofRow: row), bottom = top + g.rowHeight
        let lowest = Double(viewSize.height) - timeline.bottomRoom
        if top < g.headerHeight { dy = g.headerHeight - top } else if bottom > lowest { dy = lowest - bottom }
        if let rect = timelineRect(of: id), board.item(id)?.span != nil {
            let left = g.namesWidth + 12, right = Double(viewSize.width) - 40
            if rect.minX < left { dx = left - rect.minX } else if rect.minX > right - 30 { dx = (right - 60) - rect.minX }
        }
        if dx != 0 || dy != 0 {
            pan(by: CGSize(width: dx, height: dy))
        }
    }

    // MARK: Adding

    /// A tool was pressed: a new row under the chosen one (or at the bottom), on today when today is in
    /// sight, otherwise a little in from the left edge. Its name is typed at once.
    func addTimeline(_ kind: ItemKind) {
        guard !readOnly else { return }
        if editing != nil { commitEdit() }
        linking = false
        linkFrom = nil
        let g = timelineGeometry
        let today = Day.today()
        let first = g.day(atX: g.namesWidth)
        let last = max(first, g.day(atX: Double(viewSize.width)) - 1)
        let day = (today >= first && today <= last) ? today : first + max(1, (last - first) / 6)
        let row = single.flatMap { board.timelineRow(of: $0.id) }.map { $0 + 1 }
        let days = timeline.scale.newBarDays
        var made: UUID?
        change { board in
            switch kind {
            case .milestone: made = board.addMilestone(on: day, atRow: row)
            case .phase: made = board.addPhase(atRow: row)
            default: made = board.addBar(start: day, days: days, atRow: row)
            }
        }
        if let made {
            beginEdit(made, isNew: true)
            timelineReveal(made)
        }
    }

    /// Return on a chosen bar or milestone: the next bar in the row below, the day after, already joined.
    /// On a phase: a first bar under it.
    func addBarAfterSelection() {
        guard !readOnly, let item = single else { return }
        if editing != nil { commitEdit() }
        if item.kind == .phase {
            addTimeline(.bar)
            return
        }
        var made: UUID?
        change { made = $0.addBarAfter(item.id) }
        if let made {
            beginEdit(made, isNew: true)
            timelineReveal(made)
        }
    }

    /// Joins two bars. Returns the words to say about it, if any.
    func timelineJoin(_ follower: UUID, after forerunner: UUID) -> String? {
        guard follower != forerunner else { return nil }
        if board.links.contains(where: { $0.from == forerunner && $0.to == follower }) { return "These two are joined already." }
        guard board.item(follower)?.span != nil, board.item(forerunner)?.span != nil else {
            return "A phase is a heading: join the bars under it."
        }
        if board.leads(from: follower, to: forerunner) { return "That would go round in a ring." }
        var pushed: Int?
        change { pushed = $0.comesAfter(follower, after: forerunner) }
        selectedLink = board.links.first { $0.from == forerunner && $0.to == follower }?.id
        if selectedLink != nil { selection = [] }
        return TimelineWords.pushed(pushed ?? 0, joined: true)
    }

    /// Copies the chosen rows into the rows right under them.
    func timelineDuplicate() {
        guard editing == nil, !selection.isEmpty else { return }
        let ids = selection
        var copies: Set<UUID> = []
        change { copies = $0.duplicateRows(ids) }
        if !copies.isEmpty { selection = copies }
    }

    /// Left and right arrow keys: the chosen bars move a day (a week with Shift). Returns how many were pushed.
    @discardableResult
    func timelineNudge(days: Int) -> Int {
        let ids = selection
        var pushed = 0
        change { pushed = $0.shift(ids, byDays: days) }
        if let id = ids.first, ids.count == 1 { timelineReveal(id) }
        return pushed
    }

    /// Up and down arrow keys: the row above or below is chosen.
    func timelineSelectRow(by step: Int) {
        let rows = board.timelineRows
        guard !rows.isEmpty else { return }
        let here = single.flatMap { board.timelineRow(of: $0.id) }
        let next = min(max((here ?? (step > 0 ? -1 : rows.count)) + step, 0), rows.count - 1)
        selection = [rows[next].id]
        selectedLink = nil
        timelineReveal(rows[next].id)
    }
}

/// The short lines a timeline says.
enum TimelineWords {
    /// "2 bars after it moved along."
    static func pushed(_ count: Int, joined: Bool = false) -> String? {
        guard count > 0 else { return nil }
        if joined { return count == 1 ? "Joined. 1 bar moved to come after." : "Joined. \(count) bars moved to come after." }
        return count == 1 ? "1 bar after it moved along." : "\(count) bars after it moved along."
    }

    static func linking(first: Bool) -> String {
        first ? "Press the bar that comes first, then the one after it." : "Now press the bar that comes after it."
    }
}
