import Foundation

struct Fmt {
    var units: Units

    private let kmPerMi = 1.609344
    private let ftPerM = 3.28084

    var speedUnit: String { units == .km ? "km/h" : "mph" }
    var distUnit: String { units == .km ? "km" : "mi" }
    var altUnit: String { units == .km ? "m" : "ft" }

    func speed(_ kmh: Double) -> String {
        String(format: "%.1f", units == .km ? kmh : kmh / kmPerMi)
    }

    func dist(_ metres: Double, digits: Int = 2) -> String {
        let v = metres / 1000 / (units == .km ? 1 : kmPerMi)
        return String(format: "%.\(v >= 100 ? min(digits, 1) : digits)f", v)
    }

    func alt(_ metres: Double) -> String {
        String(Int((units == .km ? metres : metres * ftPerM).rounded()))
    }

    static func dur(_ sec: Double) -> String {
        let s = max(0, Int(sec.rounded()))
        return String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
    }

    static func kcal(_ v: Double) -> String {
        String(Int(v.rounded()))
    }

    static func grade(_ pct: Double) -> String {
        let r = (pct * 10).rounded() / 10
        if r == 0 { return "0.0" }
        return (r > 0 ? "+" : "−") + String(format: "%.1f", abs(r))
    }

    private static let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    static func date(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day, .weekday], from: d)
        return "\(c.month ?? 0)月\(c.day ?? 0)日 \(weekdays[(c.weekday ?? 1) - 1])"
    }

    static func clock(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

/// One labelled number as a screen shows it: "均速 km/h" over "23.2".
struct StatCell: Equatable {
    var label: String
    var unit: String?
    var value: String

    /// Shown in place of a number that does not exist.
    static let none = "--"

    init(_ label: String, _ unit: String? = nil, _ value: String) {
        self.label = label
        self.unit = unit
        self.value = value
    }
}

enum GradeBand {
    case down, flat, up

    init(_ pct: Double) {
        if pct <= -3 { self = .down } else if pct < 3 { self = .flat } else { self = .up }
    }
}
