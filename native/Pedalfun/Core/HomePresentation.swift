import Foundation

/// What the home screen shows for a week of rides: the headline, the seven
/// bars, and the picked day's numbers. Decided here, laid out by `HomeView`.
struct HomePresentation: Equatable {
    struct Bar: Equatable, Identifiable {
        var id: Int
        var weekday: String
        var dayNumber: Int
        /// distance inside the bar; nil on a day without a ride
        var text: String?
        var unit: String
        /// share of the tallest day, 0 when there was no ride
        var ratio: Double
        var isToday: Bool
        var isPicked: Bool
        /// later this week: dimmed, cannot be picked
        var isFuture: Bool
        var accessibilityLabel: String
    }

    /// Where the label inside a bar goes.
    struct LabelPlace: Equatable {
        /// centre of the label, measured up from the bottom of the bar
        var centre: Double
        /// the label lies on the coloured fill rather than on the empty track
        var onFill: Bool
    }

    static let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    /// a day with any ride at all still gets a visible stub of a bar
    static let minRatio = 0.06

    var weekDist: String
    var distUnit: String
    var weekSummary: String

    var bars: [Bar]
    /// index of the day shown under the bars
    var picked: Int

    var dayTitle: String
    /// distance, average speed, time, energy: always these four, in this order
    var dayCells: [StatCell]
    /// no weight on file, so energy cannot be shown; offer the way to settings
    var showsWeightHint: Bool

    /// `picked`: the day the user tapped, nil for today. Days still to come cannot be picked.
    init(_ week: WeekStats, picked: Int?, hasWeight: Bool, _ f: Fmt) {
        let sel = min(max(picked ?? week.todayIndex, 0), week.todayIndex)
        self.picked = sel

        weekDist = f.dist(week.dist, digits: 1)
        distUnit = f.distUnit
        weekSummary = week.count == 0
            ? "这周还没骑。"
            : "\(week.count) 次骑行，\(Fmt.dur(week.moving))，爬升 \(f.alt(week.climb)) \(f.altUnit)"

        let peak = max(week.perDay.max() ?? 0, 1)
        bars = (0..<7).map { i in
            let day = week.days[i]
            let dist = f.dist(day.dist, digits: 1)
            return Bar(
                id: i,
                weekday: Self.weekdays[i],
                dayNumber: week.dayNumbers[i],
                text: day.dist > 0 ? dist : nil,
                unit: f.distUnit,
                ratio: day.dist > 0 ? max(Self.minRatio, day.dist / peak) : 0,
                isToday: i == week.todayIndex,
                isPicked: i == sel,
                isFuture: i > week.todayIndex,
                accessibilityLabel: "周\(Self.weekdays[i])，\(dist) \(f.distUnit)"
            )
        }

        let day = week.days[sel]
        let has = day.count > 0
        let name = sel == week.todayIndex ? "今天" : "周\(Self.weekdays[sel])"
        dayTitle = has ? "\(name)，\(day.count) 次骑行" : "\(name)，没有骑行"
        dayCells = [
            StatCell("里程", f.distUnit, has ? f.dist(day.dist, digits: 1) : StatCell.none),
            StatCell("均速", nil, has ? f.speed(day.avg) : StatCell.none),
            StatCell("时间", nil, has ? Fmt.dur(day.moving) : StatCell.none),
            StatCell("消耗", "kcal", has ? day.kcal.map(Fmt.kcal) ?? StatCell.none : StatCell.none),
        ]
        showsWeightHint = !hasWeight
    }

    /// The label sits mid-bar when the fill reaches past it, otherwise in the
    /// empty track above the fill. It never straddles the edge of the fill.
    ///
    /// - Parameters:
    ///   - height: the whole bar
    ///   - fill: the coloured part, from the bottom
    ///   - half: half the height the label needs
    static func labelPlace(height: Double, fill: Double, half: Double) -> LabelPlace {
        let mid = height / 2
        if fill >= mid + half { return LabelPlace(centre: mid, onFill: true) }
        // Just above the fill, but no higher than the bar's rounded top allows.
        let above = min(max(mid, fill + half + 2), height - half - 4)
        return LabelPlace(centre: above, onFill: false)
    }
}
