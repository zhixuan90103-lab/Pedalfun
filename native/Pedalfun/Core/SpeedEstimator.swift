import Foundation

/// Turns the receiver's speed into one that can be shown and acted on.
///
/// The receiver's speed is filtered by the system and, with poor signal,
/// keeps reporting riding speed for seconds after the bike has stopped. So
/// each reading is checked three ways:
///
/// 1. Marked invalid, or with a large reported error: not used. Displacement
///    over the last couple of seconds stands in.
/// 2. Well above that displacement speed: it is lagging, and the displacement
///    speed is used. Position noise only ever inflates displacement, so this
///    pulls a too-high reading down and never pushes one up.
/// 3. Rising faster than a bicycle can accelerate: limited. Falls are not.
///
/// Thresholds live in `RideTracker.Tune` with all the others.
struct SpeedEstimator {
    private typealias Tune = RideTracker.Tune

    /// recent usable positions, for displacement speed
    private var recent: [(t: TimeInterval, lat: Double, lon: Double)] = []
    /// previous estimate, m/s
    private var last = 0.0

    /// The first fix of a ride: nothing to compare it with yet.
    mutating func begin(_ fix: Fix) {
        remember(fix)
        last = Self.doppler(fix) ?? 0
    }

    /// Speed in m/s for `fix`, which lies `dd` metres and `dt` seconds after the previous one.
    mutating func update(_ fix: Fix, dd: Double, dt: Double) -> Double {
        remember(fix)
        let displaced = displacementSpeed(at: fix)

        var v: Double
        if let d = Self.doppler(fix) {
            v = d
            if let p = displaced, d > p * Tune.lagRatio + Tune.lagMargin { v = p }
        } else {
            v = displaced ?? dd / dt
        }
        v = min(v, last + Tune.maxAccel * dt)
        last = v
        return v
    }

    /// The receiver's Doppler speed, when it is usable.
    static func doppler(_ fix: Fix) -> Double? {
        guard let s = fix.speed, s >= 0 else { return nil }
        if let acc = fix.speedAcc, !(acc >= 0 && acc <= Tune.speedAccLimit) { return nil }
        return s
    }

    private mutating func remember(_ fix: Fix) {
        if fix.isUsable { recent.append((fix.t, fix.lat, fix.lon)) }
        recent.removeAll { $0.t < fix.t - Tune.posWindow * 3 }
    }

    /// Straight-line speed from the newest position at least `posWindow` old to `fix`.
    private func displacementSpeed(at fix: Fix) -> Double? {
        guard let old = recent.last(where: { $0.t <= fix.t - Tune.posWindow }) else { return nil }
        return RideTracker.haversine(old.lat, old.lon, fix.lat, fix.lon) / (fix.t - old.t)
    }
}
