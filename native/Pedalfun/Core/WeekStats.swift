import Foundation

/// This week's totals (Monday first).
struct WeekStats {
    var perDay = [Double](repeating: 0, count: 7)
    var dayNumbers = [Int](repeating: 0, count: 7)
    var dist = 0.0
    var climb = 0.0
    var moving = 0.0
    var count = 0
    var todayIndex = 0

    init(rides: [Ride], now: Date = Date()) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        todayIndex = (cal.component(.weekday, from: now) + 5) % 7
        let start = cal.date(byAdding: .day, value: -todayIndex, to: today) ?? today
        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: i, to: start) ?? start
            dayNumbers[i] = cal.component(.day, from: day)
        }
        for r in rides where r.date >= start {
            perDay[(cal.component(.weekday, from: r.date) + 5) % 7] += r.dist
            dist += r.dist
            climb += r.climb
            moving += r.moving
            count += 1
        }
    }
}
