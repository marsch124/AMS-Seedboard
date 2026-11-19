import Foundation

// 0.14, pick 29: plan against now. "Set the plan" keeps each bar's and milestone's days in
// `Item.planStart` / `planEnd`; a bar that stands elsewhere later shows a ghost where it was planned and
// how many days late or early it is. "Clear the plan" removes them. Nothing here moves a bar.

public extension Item {
    /// The days written down by "Set the plan"; nil when the item has none.
    var planSpan: (start: Day, end: Day)? {
        guard kind == .bar || kind == .milestone, let first = planStart.flatMap({ Day(iso: $0) }) else { return nil }
        if kind == .milestone { return (first, first) }
        let last = planEnd.flatMap { Day(iso: $0) } ?? first
        return (first, max(first, last))
    }

    /// How far the last day is from the planned last day: positive = late, negative = early; nil without a plan.
    var slipDays: Int? {
        guard let plan = planSpan, let now = span else { return nil }
        return now.end - plan.end
    }

    /// True when the bar stands somewhere else than planned (start or end differs).
    var movedFromPlan: Bool {
        guard let plan = planSpan, let now = span else { return false }
        return plan.start != now.start || plan.end != now.end
    }

    /// "2 days late", "1 day early"; nil when on time or without a plan. A bar that only changed length
    /// but ends on the planned day says nothing.
    var slipWords: String? {
        guard let d = slipDays, d != 0 else { return nil }
        let n = abs(d)
        return "\(n) \(n == 1 ? "day" : "days") \(d > 0 ? "late" : "early")"
    }
}

public extension Board {
    /// True when at least one bar or milestone carries a plan.
    var hasPlan: Bool { items.contains { $0.planSpan != nil } }

    /// Writes every bar's and milestone's days as the plan (a plan set before is replaced). Returns how many.
    @discardableResult
    mutating func setPlan() -> Int {
        var n = 0
        for i in items.indices where items[i].kind == .bar || items[i].kind == .milestone {
            if let s = items[i].span {
                items[i].planStart = s.start.iso
                items[i].planEnd = s.end.iso
                n += 1
            }
        }
        return n
    }

    /// Takes the plan away again. Returns how many items had one.
    @discardableResult
    mutating func clearPlan() -> Int {
        var n = 0
        for i in items.indices where items[i].planStart != nil || items[i].planEnd != nil {
            items[i].planStart = nil
            items[i].planEnd = nil
            n += 1
        }
        return n
    }
}
