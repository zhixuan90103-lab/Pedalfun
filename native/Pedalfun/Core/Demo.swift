import Foundation

/// Canned data for screenshots and UI review. Never written to disk.
enum Demo {
    /// `-demo <name>`: cruise | climb | descent | autopause | paused | gpsweak
    static func state(_ name: String) -> RideState? {
        var s = RideState()
        s.gpsWeak = false
        s.startedAt = Date().addingTimeInterval(-1805)
        s.moving = 1744
        s.total = 1805
        s.dist = 11_360
        s.speed = 26.8
        s.max = 50.5
        s.alt = 182
        s.altMax = 196
        s.climb = 217
        s.samples = profile(seed: 7, km: 11.36, hilly: 1.1)
        switch name {
        case "cruise": s.grade = -0.2
        case "climb": s.speed = 12.5; s.grade = 6.2
        case "descent": s.speed = 45.1; s.grade = -4.8
        case "autopause": s.status = .autoPaused; s.speed = 0
        case "paused": s.status = .paused; s.speed = 0
        case "gpsweak": s.gpsWeak = true
        default: return nil
        }
        return s
    }

    static func rides() -> [Ride] {
        [
            ride(11, 1, 18, 31.6, 0.6), ride(12, 2, 7, 36.8, 1.1), ride(13, 5, 15, 62.3, 1.6),
            ride(14, 8, 7, 24.1, 0.4), ride(15, 11, 19, 18.7, 0.3), ride(16, 15, 9, 84.5, 2.0),
            ride(17, 22, 16, 40.2, 0.9), ride(18, 29, 7, 28.4, 0.7), ride(19, 36, 10, 102.6, 1.8),
        ]
    }

    private struct Rng {
        var s: UInt32
        mutating func next() -> Double {
            s = s &+ 0x6d2b_79f5
            var t = s
            t = (t ^ (t >> 15)) &* (t | 1)
            t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
            return Double(t ^ (t >> 14)) / 4_294_967_296
        }
    }

    private static func profile(seed: UInt32, km: Double, hilly: Double) -> [Sample] {
        var rng = Rng(s: seed)
        let base = 20 + rng.next() * 120
        let p1 = rng.next() * 6
        let p2 = rng.next() * 6
        return (0...90).map { i in
            let t = Double(i) / 90
            // Amplitude scales with length so slopes stay in a realistic 0–8% range.
            let a = base + hilly * km * (1.2 * sin(t * .pi) + 2.2 * sin(t * 9 + p1) + sin(t * 23 + p2) + 3.2)
            return Sample(d: t * km * 1000, a: a)
        }
    }

    private static func ride(_ seed: UInt32, _ daysAgo: Int, _ hour: Int, _ km: Double, _ hilly: Double) -> Ride {
        var rng = Rng(s: seed &+ 1000)
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let date = cal.date(bySettingHour: hour, minute: Int(rng.next() * 60), second: 0, of: day) ?? day
        let samples = profile(seed: seed, km: km, hilly: hilly)
        var climb = 0.0
        for i in 1..<samples.count where samples[i].a > samples[i - 1].a { climb += samples[i].a - samples[i - 1].a }
        let avg = 26 - hilly * 4 + rng.next() * 3
        let moving = (km / avg * 3600).rounded()
        return Ride(
            id: "mock-\(seed)", date: date, name: Ride.name(for: date), dist: km * 1000, moving: moving,
            total: moving + (240 + rng.next() * 900).rounded(), max: 44 + hilly * 9 + rng.next() * 6,
            climb: climb, altMax: samples.map(\.a).max() ?? 0, samples: samples, hasTrack: false
        )
    }
}
