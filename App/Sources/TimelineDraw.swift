import SwiftUI
import SeedboardCore

// How a timeline board is drawn. One painter draws the live board and the picture that goes to
// PARAGON, so the two can never differ. Every place comes from `TimelineGeometry` (days ↔ x, rows ↔ y).

struct TimelinePainter {
    let board: Board
    let paint: Paint
    var geometry: TimelineGeometry
    /// The room it is drawn in: the whole view, or the whole picture.
    var size: CGSize
    var today: Day = .today()
    var selection: Set<UUID> = []
    var selectedLink: UUID?
    /// The row whose name is being typed: the text field shows its words.
    var editing: UUID?
    /// The grips and the "comes after" dot of the one chosen bar.
    var handles = true
    /// The bar the "comes after" tool starts from.
    var linkFrom: UUID?
    /// The bar a pulled "comes after" line would land on.
    var dropTarget: UUID?
    /// The line being pulled from a bar's dot.
    var rubber: (from: CGPoint, to: CGPoint)?
    /// The chosen bar's dates, shown over it while it is dragged.
    var showDates = false
    /// What lies behind (white for a picture).
    var ground: Color?
    var nameSize: CGFloat = TimelineLook.nameSize
    /// How each to-do stands (the board's own knowledge with what was read back from PARAGON laid over it):
    /// a bar ticked off in PARAGON is drawn done (TimelineProgress.swift).
    var todoStates: [UUID: TodoState] = [:]
    /// 0.11: "Differentiate Without Colour" is on: what is late also wears a hatch / dashes, not only red.
    var patterns = false

    static let gripRadius: CGFloat = 6
    static let dotRadius: CGFloat = 5
    static let dotGap: CGFloat = 20
    /// 0.9: the room a phase's chevron (fold / unfold) takes before its name, and the width of the press on it.
    static let chevronRoom: CGFloat = 14

    // MARK: Places (shared with the view's press handling)

    /// The round grip at each end of a bar.
    static func grips(of bar: CGRect) -> (start: CGPoint, end: CGPoint) {
        (CGPoint(x: bar.minX, y: bar.midY), CGPoint(x: bar.maxX, y: bar.midY))
    }

    /// The small dot after a bar's end: pull it onto another bar for "comes after".
    static func dot(of bar: CGRect) -> CGPoint { CGPoint(x: bar.maxX + dotGap, y: bar.midY) }

    /// Where a row's name begins: rows under a phase stand a little in; a milestone has its small diamond first.
    static func nameLeft(_ item: Item, grouped: Bool) -> CGFloat {
        (grouped ? 20 : 10) + (item.kind == .milestone ? 14 : 0) + (item.kind == .phase ? chevronRoom : 0)
    }

    /// Where an item is drawn: a bar, a milestone's diamond; nil for a phase or an item without days.
    func rect(of item: Item, row: Int) -> CGRect? {
        guard let span = item.span else { return nil }
        return item.kind == .milestone ? geometry.diamond(on: span.start, row: row) : geometry.bar(from: span.start, to: span.end, row: row)
    }

    private func colour(of item: Item) -> Color {
        switch item.kind {
        case .milestone: return paint.line(item.colour.isEmpty ? TimelineColours.milestone : item.colour)
        case .phase: return paint.line(item.colour.isEmpty ? "teal" : item.colour)
        default: return paint.line(item.colour.isEmpty ? "blue" : item.colour)
        }
    }

    // MARK: Drawing

    func draw(_ ctx: inout GraphicsContext) {
        let g = geometry
        // 0.9: a folded phase hides its rows; the rows below move up (Core: shownTimelineRows).
        let rows = board.shownTimelineRows
        let names = CGFloat(g.namesWidth), header = CGFloat(g.headerHeight)
        let back = ground ?? paint.canvas
        let chart = CGRect(x: names, y: header, width: max(size.width - names, 0), height: max(size.height - header, 0))
        let first = g.day(atX: Double(names)) - 1
        let last = DayRange.drawEnd(from: first, to: g.day(atX: Double(size.width)) + 1)
        let groups = board.shownPhaseGroups
        let byID = rows.enumerated().reduce(into: [UUID: (item: Item, row: Int)]()) { $0[$1.element.id] = ($1.element, $1.offset) }

        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(back))

        // The days: weekend shade, phase bands, date lines, arrows, bars, today.
        var days = ctx
        days.clip(to: Path(chart))
        // 0.9: weekends and Swedish public holidays, shaded softly on the Days and Weeks scales (holidays a little
        // stronger); the Months scale carries none.
        if g.scale != .months {
            let holidays = SwedishHolidays.names(from: first, to: last)
            let weekend = g.scale == .days ? (paint.night ? 0.22 : 0.20) : (paint.night ? 0.18 : 0.15)
            let holiday = paint.night ? 0.42 : 0.38
            var day = first
            while day <= last {
                let isHoliday = holidays[day] != nil
                if day.isWeekend || isHoliday {
                    let column = CGRect(x: g.x(of: day), y: Double(header), width: g.scale.pointsPerDay, height: Double(chart.height))
                    days.fill(Path(column), with: .color(paint.edge.opacity(isHoliday ? holiday : weekend)))
                }
                day = day + 1
            }
        }
        for group in groups {
            guard let phase = byID[group.id]?.item else { continue }
            let band = CGRect(x: Double(names), y: g.y(ofRow: group.firstRow), width: Double(chart.width),
                              height: Double(group.lastRow - group.firstRow + 1) * g.rowHeight)
            days.fill(Path(band), with: .color(paint.soft(phase.colour.isEmpty ? "teal" : phase.colour).opacity(paint.night ? 0.40 : 0.55)))
        }
        for tick in TimelineGeometry.ticks(from: first, to: last, scale: g.scale) {
            var line = Path()
            let x = g.x(of: tick.day).rounded() + 0.5
            line.move(to: CGPoint(x: x, y: Double(header)))
            line.addLine(to: CGPoint(x: x, y: Double(size.height)))
            days.stroke(line, with: .color(paint.edge.opacity(tick.strong ? 0.95 : (g.scale == .days ? 0.40 : 0.65))), lineWidth: 1)
        }
        for row in 1...max(rows.count, 1) {
            var line = Path()
            let y = g.y(ofRow: row).rounded() + 0.5
            line.move(to: CGPoint(x: Double(names), y: y))
            line.addLine(to: CGPoint(x: Double(size.width), y: y))
            days.stroke(line, with: .color(paint.edge.opacity(0.30)), lineWidth: 1)
        }

        // An arrow to a bar a folded phase hides ends at that phase's band; one between two bars hidden in the
        // same phase is not drawn.
        let places = TimelinePainter.linkPlaces(board, geometry: g)
        for link in board.links {
            guard let from = places[link.from], let to = places[link.to], from != to else { continue }
            drawArrow(g.arrow(from: from, to: to), chosen: selectedLink == link.id, &days)
        }

        for group in groups {
            guard let phase = byID[group.id]?.item, let start = group.start, let end = group.end else { continue }
            // The phase's own thin bar: from its first bar's first day to its last bar's last day.
            let whole = g.bar(from: start, to: end, row: group.firstRow)
            if group.folded {
                // 0.9: a folded phase: one soft band from its first to its last day, with how many bars are in it.
                let band = TimelinePainter.foldBand(of: group, geometry: g)!
                days.fill(Path(roundedRect: band, cornerRadius: 7), with: .color(colour(of: phase).opacity(paint.night ? 0.55 : 0.50)))
                days.stroke(Path(roundedRect: band, cornerRadius: 7), with: .color(colour(of: phase).opacity(0.85)), lineWidth: 1)
                if let words = group.foldWords {
                    let text = days.resolve(Text(words).font(.system(size: 10.5, weight: .medium)).foregroundColor(paint.ink))
                    let wide = text.measure(in: CGSize(width: 300, height: 30)).width
                    if wide + 12 <= band.width {
                        days.draw(text, at: CGPoint(x: band.minX + 7, y: band.midY), anchor: .leading)
                    } else {
                        days.draw(text, at: CGPoint(x: band.maxX + 6, y: band.midY), anchor: .leading)
                    }
                }
                continue
            }
            let thin = CGRect(x: whole.minX, y: whole.midY - 3, width: whole.width, height: 6)
            days.fill(Path(roundedRect: thin, cornerRadius: 3), with: .color(colour(of: phase).opacity(0.80)))
        }

        for (row, item) in rows.enumerated() {
            guard let box = rect(of: item, row: row), box.maxX > names - 40, box.minX < size.width + 40 else { continue }
            drawPlanGhost(item, row: row, &days)
            drawBar(item, box, &days)
            drawState(item, box, &days)
        }

        // Today: a red line down the middle of the day.
        let todayX = CGFloat(g.todayX(today))
        let red = paint.line("red")
        if todayX > names - 2, todayX < size.width + 2 {
            var line = Path()
            line.move(to: CGPoint(x: todayX, y: header))
            line.addLine(to: CGPoint(x: todayX, y: size.height))
            days.stroke(line, with: .color(red), lineWidth: 1.6)
        }
        // 0.9: the done-day words go over the Today line, on a soft plate, so the line never runs through them.
        for (row, item) in rows.enumerated() {
            guard let box = rect(of: item, row: row), box.maxX > names - 40, box.minX < size.width + 40 else { continue }
            drawDoneLabel(item, box, &days)
        }

        drawChosen(byID, &days)

        // The pinned column of names.
        let todoMarks = TodoMark.marks(for: board)
        var column = ctx
        column.clip(to: Path(CGRect(x: 0, y: header, width: names, height: max(size.height - header, 0))))
        column.fill(Path(CGRect(x: 0, y: header, width: names, height: size.height)), with: .color(ground ?? paint.plate))
        for group in groups {
            guard let phase = byID[group.id]?.item else { continue }
            let band = CGRect(x: 0, y: g.y(ofRow: group.firstRow), width: Double(names),
                              height: Double(group.lastRow - group.firstRow + 1) * g.rowHeight)
            column.fill(Path(band), with: .color(paint.soft(phase.colour.isEmpty ? "teal" : phase.colour).opacity(paint.night ? 0.40 : 0.55)))
        }
        let grouped = Set(groups.flatMap { group in rows[group.firstRow...group.lastRow].dropFirst().map(\.id) })
        for (row, item) in rows.enumerated() {
            let top = CGFloat(g.y(ofRow: row)), height = CGFloat(g.rowHeight)
            guard top + height > header, top < size.height else { continue }
            if selection.contains(item.id) {
                let plate = CGRect(x: 4, y: top + 3, width: names - 8, height: height - 6)
                column.fill(Path(roundedRect: plate, cornerRadius: 7), with: .color(paint.chosen.opacity(paint.night ? 0.26 : 0.16)))
            }
            let indent: CGFloat = grouped.contains(item.id) ? 20 : 10
            var right = names - 8
            // 0.14: "2 days late" / "3 days early" against the plan, small and grey, at the right of the name.
            if let slip = item.slipWords {
                let words = column.resolve(Text(slip).font(.system(size: 10)).foregroundColor(paint.faint))
                let wide = words.measure(in: CGSize(width: 200, height: 30)).width
                column.draw(words, at: CGPoint(x: right, y: top + height / 2), anchor: .trailing)
                right -= wide + 6
            }
            // 0.5: the to-do mark by how it stands (TodoMark.swift).
            let todo = item.kind == .phase ? nil : TodoMark.state(of: item, in: todoMarks)
            if let todo {
                tick(todo, at: CGPoint(x: names - 15, y: top + height / 2), &column)
                right = names - 26
            }
            if item.kind == .milestone {
                // A small diamond before the name says: this row is one day.
                let c = CGPoint(x: indent + 5, y: top + height / 2)
                var mark = Path()
                mark.move(to: CGPoint(x: c.x, y: c.y - 5)); mark.addLine(to: CGPoint(x: c.x + 5, y: c.y))
                mark.addLine(to: CGPoint(x: c.x, y: c.y + 5)); mark.addLine(to: CGPoint(x: c.x - 5, y: c.y)); mark.closeSubpath()
                column.fill(mark, with: .color(colour(of: item)))
            }
            if item.kind == .phase, let group = groups.first(where: { $0.id == item.id }), group.folded || group.bars + group.milestones > 0 {
                drawChevron(open: !group.folded, at: CGPoint(x: indent + 5, y: top + height / 2), colour: colour(of: item), &column)
            }
            guard editing != item.id else { continue }
            let left = TimelinePainter.nameLeft(item, grouped: grouped.contains(item.id))
            let empty = item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let words = empty ? item.kind.word : item.nameLine
            let shade = empty || TodoMark.greysWords(todo) ? paint.faint : (item.kind == .phase ? colour(of: item) : (nameShade(item) ?? paint.ink))
            let text = column.resolve(Text(words).font(.system(size: nameSize, weight: item.kind == .phase ? .semibold : .regular)).foregroundColor(shade))
            let line = text.measure(in: CGSize(width: 2000, height: 100)).height
            var clipped = column
            clipped.clip(to: Path(CGRect(x: left, y: top, width: max(right - left, 10), height: height)))
            clipped.draw(text, in: CGRect(x: left, y: top + (height - line) / 2, width: 2000, height: line + 1))
        }
        for row in 1...max(rows.count, 1) {
            var line = Path()
            let y = g.y(ofRow: row).rounded() + 0.5
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: Double(names), y: y))
            column.stroke(line, with: .color(paint.edge.opacity(0.30)), lineWidth: 1)
        }

        // The pinned band of dates.
        var band = ctx
        band.clip(to: Path(CGRect(x: names, y: 0, width: max(size.width - names, 0), height: header)))
        band.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: header)), with: .color(ground ?? paint.plate))
        let todayTag = band.resolve(Text("Today").font(.system(size: 10.5, weight: .bold)).foregroundColor(.white))
        let tagSize = todayTag.measure(in: CGSize(width: 200, height: 40))
        let tagBox = CGRect(x: todayX - tagSize.width / 2 - 6, y: 4, width: tagSize.width + 12, height: 15)
        // The small words above the dates stay in sight: the first one sticks to the left edge.
        let heads = TimelineGeometry.heads(from: max(first, g.day(atX: Double(names))), to: last, scale: g.scale)
        for (n, head) in heads.enumerated() {
            let text = band.resolve(Text(head.label).font(.system(size: 10.5, weight: .semibold)).foregroundColor(paint.faint))
            let wide = text.measure(in: CGSize(width: 400, height: 40)).width
            var x = n == 0 ? names + 6 : CGFloat(g.x(of: head.day)) + 5
            if n == 0, heads.count > 1 { x = min(x, CGFloat(g.x(of: heads[1].day)) - wide - 8) }
            let box = CGRect(x: x, y: 4, width: wide, height: 15)
            if box.intersects(tagBox.insetBy(dx: -4, dy: 0)), todayX > names - 20 { continue }
            // Never half a word at the right edge.
            if n > 0, box.maxX > size.width - 2 { continue }
            band.draw(text, at: CGPoint(x: x, y: 11.5), anchor: .leading)
        }
        for tick in TimelineGeometry.ticks(from: first, to: last, scale: g.scale) {
            let x = CGFloat(g.x(of: tick.day))
            let isToday = g.scale == .days && tick.day == today
            let shade = isToday ? red : (g.scale == .days && tick.day.isWeekend ? paint.faint : paint.ink)
            let text = band.resolve(Text(tick.label).font(.system(size: 12, weight: tick.strong || isToday ? .semibold : .regular)).foregroundColor(shade))
            if g.scale == .days {
                band.draw(text, at: CGPoint(x: x + CGFloat(g.scale.pointsPerDay) / 2, y: 31), anchor: .center)
            } else {
                // On the Weeks scale the week's number stands over its Monday's date (TimelineProgress.swift).
                band.draw(text, at: CGPoint(x: x + 5, y: g.scale == .weeks ? TimelinePainter.weekDateY : 31), anchor: .leading)
                if g.scale == .weeks { drawWeek(tick.day, x: x, &band) }
                var line = Path()
                line.move(to: CGPoint(x: x.rounded() + 0.5, y: 22))
                line.addLine(to: CGPoint(x: x.rounded() + 0.5, y: header))
                band.stroke(line, with: .color(paint.edge.opacity(0.65)), lineWidth: 1)
            }
        }
        if todayX > names - 20, todayX < size.width + 20 {
            band.fill(Path(roundedRect: tagBox, cornerRadius: 7.5), with: .color(red))
            band.draw(todayTag, at: CGPoint(x: tagBox.midX, y: tagBox.midY), anchor: .center)
        }

        // The corner, and the two edges that pin names and dates.
        ctx.fill(Path(CGRect(x: 0, y: 0, width: names, height: header)), with: .color(ground ?? paint.plate))
        drawProgress(&ctx)
        var edges = Path()
        edges.move(to: CGPoint(x: 0, y: header + 0.5)); edges.addLine(to: CGPoint(x: size.width, y: header + 0.5))
        edges.move(to: CGPoint(x: names + 0.5, y: 0)); edges.addLine(to: CGPoint(x: names + 0.5, y: size.height))
        ctx.stroke(edges, with: .color(paint.edge), lineWidth: 1)
    }

    /// 0.14: where a bar was planned ("Set the plan"), when it now stands elsewhere: a faint dashed outline in
    /// the bar's own colour.
    private func drawPlanGhost(_ item: Item, row: Int, _ ctx: inout GraphicsContext) {
        guard item.movedFromPlan, let plan = item.planSpan else { return }
        let box = item.kind == .milestone ? geometry.diamond(on: plan.start, row: row) : geometry.bar(from: plan.start, to: plan.end, row: row)
        let line = colour(of: item).opacity(paint.night ? 0.50 : 0.45)
        let style = StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round, dash: [3, 3])
        if item.kind == .milestone {
            var d = Path()
            d.move(to: CGPoint(x: box.midX, y: box.minY)); d.addLine(to: CGPoint(x: box.maxX, y: box.midY))
            d.addLine(to: CGPoint(x: box.midX, y: box.maxY)); d.addLine(to: CGPoint(x: box.minX, y: box.midY)); d.closeSubpath()
            ctx.stroke(d, with: .color(line), style: style)
        } else {
            ctx.stroke(Path(roundedRect: box, cornerRadius: min(7, box.width / 2)), with: .color(line), style: style)
        }
    }

    /// The small chevron before a phase's name: pointing down while it is open, right while it is folded.
    private func drawChevron(open: Bool, at c: CGPoint, colour: Color, _ ctx: inout GraphicsContext) {
        var path = Path()
        if open {
            path.move(to: CGPoint(x: c.x - 4, y: c.y - 2)); path.addLine(to: CGPoint(x: c.x, y: c.y + 2)); path.addLine(to: CGPoint(x: c.x + 4, y: c.y - 2))
        } else {
            path.move(to: CGPoint(x: c.x - 2, y: c.y - 4)); path.addLine(to: CGPoint(x: c.x + 2, y: c.y)); path.addLine(to: CGPoint(x: c.x - 2, y: c.y + 4))
        }
        ctx.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
    }

    /// The band of a folded phase: from its first to its last day (a little over a day when it is empty of days).
    static func foldBand(of group: PhaseGroup, geometry g: TimelineGeometry) -> CGRect? {
        guard let start = group.start, let end = group.end else { return nil }
        let whole = g.bar(from: start, to: end, row: group.firstRow)
        return CGRect(x: whole.minX, y: whole.midY - 9, width: max(whole.width, 8), height: 18)
    }

    /// Where every row that has a place is, for the "comes after" arrows: a bar or a diamond where it is; a bar
    /// that a folded phase hides is at that phase's band (nil for a phase's own row).
    static func linkPlaces(_ board: Board, geometry g: TimelineGeometry) -> [UUID: CGRect] {
        let rows = board.timelineRows
        let hidden = board.hiddenTimelineIDs
        let doneAway = board.hiddenDoneIDs
        let shownIndex = board.shownTimelineRows.enumerated().reduce(into: [UUID: Int]()) { $0[$1.element.id] = $1.offset }
        let groups = board.shownPhaseGroups
        var places: [UUID: CGRect] = [:]
        var current: PhaseGroup?
        for item in rows {
            if item.kind == .phase { current = groups.first { $0.id == item.id }; continue }
            guard let span = item.span, !doneAway.contains(item.id) else { continue }
            if hidden.contains(item.id) {
                if let group = current, let band = foldBand(of: group, geometry: g) { places[item.id] = band }
            } else if let row = shownIndex[item.id] {
                places[item.id] = item.kind == .milestone ? g.diamond(on: span.start, row: row) : g.bar(from: span.start, to: span.end, row: row)
            }
        }
        return places
    }

    private func drawBar(_ item: Item, _ box: CGRect, _ ctx: inout GraphicsContext) {
        // A done bar is paler (laid on the ground first, so no line shows through it).
        let pale = barStrength(item) < 1
        let fill = colour(of: item).opacity(barStrength(item))
        if item.kind == .milestone {
            var diamond = Path()
            diamond.move(to: CGPoint(x: box.midX, y: box.minY)); diamond.addLine(to: CGPoint(x: box.maxX, y: box.midY))
            diamond.addLine(to: CGPoint(x: box.midX, y: box.maxY)); diamond.addLine(to: CGPoint(x: box.minX, y: box.midY))
            diamond.closeSubpath()
            if pale { ctx.fill(diamond, with: .color(ground ?? paint.canvas)) }
            ctx.fill(diamond, with: .color(fill))
            ctx.stroke(diamond, with: .color(ground ?? paint.canvas), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
        } else {
            if pale { ctx.fill(Path(roundedRect: box, cornerRadius: min(7, box.width / 2)), with: .color(ground ?? paint.canvas)) }
            ctx.fill(Path(roundedRect: box, cornerRadius: min(7, box.width / 2)), with: .color(fill))
        }
    }

    /// The small to-do mark: this goes to PARAGON as a task, and how it stands there.
    private func tick(_ state: TodoState, at c: CGPoint, _ ctx: inout GraphicsContext) {
        let r: CGFloat = 7
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r - 1, y: c.y - r - 1, width: r * 2 + 2, height: r * 2 + 2)), with: .color(ground ?? paint.plate))
        TodoMark.draw(state, at: c, radius: r, paint: paint, ground: ground ?? paint.plate, &ctx)
    }

    /// A thin line with softly rounded corners and a small head where it arrives.
    private func drawArrow(_ points: [CGPoint], chosen: Bool, _ ctx: inout GraphicsContext) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for n in 1..<points.count {
            if n + 1 < points.count {
                path.addArc(tangent1End: points[n], tangent2End: points[n + 1], radius: 4)
            } else {
                path.addLine(to: points[n])
            }
        }
        if chosen {
            ctx.stroke(path, with: .color(paint.chosen.opacity(0.35)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        }
        ctx.stroke(path, with: .color(paint.arrow), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        let tip = points[points.count - 1], before = points[points.count - 2]
        let length = max(hypot(tip.x - before.x, tip.y - before.y), 0.001)
        let v = CGPoint(x: (tip.x - before.x) / length, y: (tip.y - before.y) / length)
        let back = CGPoint(x: tip.x - v.x * 6, y: tip.y - v.y * 6)
        let n = CGPoint(x: -v.y, y: v.x)
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: back.x + n.x * 3.6, y: back.y + n.y * 3.6))
        head.addLine(to: CGPoint(x: back.x - n.x * 3.6, y: back.y - n.y * 3.6))
        head.closeSubpath()
        ctx.fill(head, with: .color(paint.arrow))
    }

    /// The ring round what is chosen, the grips and the dot of the one chosen bar, and what is being pulled.
    private func drawChosen(_ byID: [UUID: (item: Item, row: Int)], _ ctx: inout GraphicsContext) {
        func ring(_ box: CGRect, dashed: Bool = false) {
            let shape = Path(roundedRect: box.insetBy(dx: -3.5, dy: -3.5), cornerRadius: 10)
            ctx.stroke(shape, with: .color(paint.chosen), style: StrokeStyle(lineWidth: dashed ? 2.4 : 2, dash: dashed ? [6, 4] : []))
        }
        for id in selection {
            guard let found = byID[id], let box = rect(of: found.item, row: found.row) else { continue }
            ring(box)
        }
        if let linkFrom, let found = byID[linkFrom], let box = rect(of: found.item, row: found.row) { ring(box, dashed: true) }
        if let dropTarget, let found = byID[dropTarget], let box = rect(of: found.item, row: found.row) { ring(box, dashed: true) }

        if selection.count == 1, let id = selection.first, let found = byID[id], let box = rect(of: found.item, row: found.row) {
            if handles, editing == nil {
                if found.item.kind == .bar {
                    let ends = TimelinePainter.grips(of: box)
                    for c in [ends.start, ends.end] {
                        let r = TimelinePainter.gripRadius
                        let grip = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                        ctx.fill(grip, with: .color(paint.plate))
                        ctx.stroke(grip, with: .color(paint.chosen), lineWidth: 2)
                    }
                }
                let c = TimelinePainter.dot(of: box)
                let r = TimelinePainter.dotRadius
                var stem = Path()
                stem.move(to: CGPoint(x: box.maxX + (found.item.kind == .bar ? TimelinePainter.gripRadius + 1 : 3), y: c.y))
                stem.addLine(to: CGPoint(x: c.x - r, y: c.y))
                ctx.stroke(stem, with: .color(paint.chosen.opacity(0.7)), style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(paint.chosen))
            }
            if showDates {
                let text = ctx.resolve(Text(found.item.spanWords).font(.system(size: 11, weight: .medium)).foregroundColor(paint.ink))
                let wide = text.measure(in: CGSize(width: 400, height: 40))
                let names = CGFloat(geometry.namesWidth)
                let midX = min(max(box.midX, names + wide.width / 2 + 10), max(size.width - wide.width / 2 - 10, names + wide.width / 2 + 10))
                // Above the bar; under it when the bar is in the top row.
                let above = box.minY - 15 > CGFloat(geometry.headerHeight) + 10
                let plate = CGRect(x: midX - wide.width / 2 - 7, y: above ? box.minY - 26 : box.maxY + 7, width: wide.width + 14, height: 19)
                var shade = ctx
                shade.addFilter(.shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1))
                shade.fill(Path(roundedRect: plate, cornerRadius: 9.5), with: .color(paint.plate))
                ctx.draw(text, at: CGPoint(x: plate.midX, y: plate.midY), anchor: .center)
            }
        }

        if let rubber {
            var line = Path()
            line.move(to: rubber.from)
            line.addLine(to: rubber.to)
            ctx.stroke(line, with: .color(paint.chosen), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))
        }
    }
}

extension TimelinePainter {
    /// A timeline drawn whole, for its picture: the board's own box (see `Board.timelinePicture`) starts at (0, 0).
    static func whole(_ board: Board, paint: Paint, ground: Color?) -> TimelinePainter {
        // 0.9: the picture shows every row, folded or not.
        var board = board
        for i in board.items.indices where board.items[i].kind == .phase { board.items[i].folded = false }
        let picture = board.timelinePicture()
        var painter = TimelinePainter(board: board, paint: paint, geometry: picture.geometry, size: picture.box.size)
        painter.handles = false
        painter.ground = ground
        painter.nameSize = 13
        return painter
    }
}
