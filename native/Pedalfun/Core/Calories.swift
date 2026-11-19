import Foundation

enum Sex: String, CaseIterable {
    case male, female
}

/// What the rider has told us about themselves. Everything is optional.
struct Profile: Equatable {
    var sex: Sex?
    /// centimetres
    var height: Double?
    /// kilograms
    var weight: Double?
}

/// Rough energy estimate from average speed, moving time and the rider's
/// profile. There is no heart rate or power behind it, and it ignores climb
/// and wind.
enum Calories {
    /// Mifflin-St Jeor needs an age; none is collected.
    static let assumedAge = 30.0

    /// Bicycling entries of the Compendium of Physical Activities, by speed in km/h.
    private static let table: [(kmh: Double, met: Double)] = [
        (8.9, 3.5), (15.1, 5.8), (17.6, 6.8), (20.8, 8.0), (24.1, 10.0), (28.2, 12.0), (33.0, 15.8),
    ]

    /// Metabolic equivalent for an average speed, interpolated between table entries.
    static func met(kmh: Double) -> Double {
        guard let first = table.first, let last = table.last else { return 0 }
        if kmh <= first.kmh { return first.met }
        if kmh >= last.kmh { return last.met }
        for i in 1..<table.count where kmh <= table[i].kmh {
            let a = table[i - 1], b = table[i]
            return a.met + (b.met - a.met) * (kmh - a.kmh) / (b.kmh - a.kmh)
        }
        return last.met
    }

    /// kcal for `dist` metres ridden in `moving` seconds. Nil without a weight.
    static func kcal(dist: Double, moving: Double, profile: Profile) -> Double? {
        guard let w = profile.weight, w > 0 else { return nil }
        guard moving > 0 else { return 0 }
        var kcal = met(kmh: dist / moving * 3.6) * w * moving / 3600
        // One MET assumes a resting rate of 1 kcal/kg/h; scale by this rider's own.
        if let sex = profile.sex, let h = profile.height {
            let resting = 10 * w + 6.25 * h - 5 * assumedAge + (sex == .male ? 5 : -161)
            if resting > 0 { kcal *= 25.2 * w / resting }
        }
        return kcal
    }
}

extension Ride {
    func kcal(_ profile: Profile) -> Double? {
        Calories.kcal(dist: dist, moving: moving, profile: profile)
    }
}
