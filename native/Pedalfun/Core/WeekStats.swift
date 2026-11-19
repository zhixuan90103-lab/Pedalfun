import Foundation

/// This week's totals (Monday first).
struct WeekStats {
    struct Day: Equatable {
        /// metres
        var dist = 0.0
        /// seconds
        var moving = 0.0
        var count = 0
        /// nil when the profile has no weight
        var kcal: Double?

        /// km/h
        var avg: Double { moving > 0 ? dist / moving * 3.6 : 0 }
    }

    var days = [Day](repeating: Day(), count: 7)
    var dayNumbers = [Int](repeating: 0, count: 7)
    var dist = 0.0
    var climb = 0.0
    var moving = 0.0
    var count = 0
    var todayIndex = 0

    var perDay: [Double] { days.map(\.dist) }

    init(rides: [Ride], profile: Profile = Profile(), now: Date = Date()) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        todayIndex = (cal.component(.weekday, from: now) + 5) % 7
        let start = cal.date(byAdding: .day, value: -todayIndex, to: today) ?? today
        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: i, to: start) ?? start
            dayNumbers[i] = cal.component(.day, from: day)
        }
        for r in rides where r.date >= start {
            let i = (cal.component(.weekday, from: r.date) + 5) % 7
            days[i].dist += r.dist
            days[i].moving += r.moving
            days[i].count += 1
            // Per ride, since the estimate depends on each ride's own speed.
            if let k = r.kcal(profile) { days[i].kcal = (days[i].kcal ?? 0) + k }
            dist += r.dist
            climb += r.climb
            moving += r.moving
            count += 1
        }
    }
}
