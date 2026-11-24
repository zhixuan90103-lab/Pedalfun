import Foundation

/// One location sample.
struct Fix {
    /// seconds since 1970
    var t: TimeInterval
    var lat: Double
    var lon: Double
    /// m/s from the receiver (Doppler); nil or negative = unavailable
    var speed: Double?
    /// 1-sigma error of `speed` in m/s; negative = speed invalid, nil = unknown
    var speedAcc: Double? = nil
    /// horizontal accuracy in metres; negative = invalid
    var hAcc: Double
    /// GPS altitude in metres
    var alt: Double?
    /// barometric altitude relative to recording start, metres
    var baro: Double?
    /// recent accelerometer vibration level in g; ~0 when the phone is still
    var motion: Double?
}

/// How a fix reads against the thresholds in `RideTracker.Tune`.
extension Fix {
    /// Too inaccurate to trust the speed shown from it.
    var isWeak: Bool { !(hAcc >= 0 && hAcc <= RideTracker.Tune.weakAcc) }
    /// Accurate enough to add distance and to measure displacement from.
    var isUsable: Bool { hAcc >= 0 && hAcc <= RideTracker.Tune.rejectAcc }
    /// The accelerometer says the phone is at rest. False when there is no accelerometer.
    var isStill: Bool { motion.map { $0 < RideTracker.Tune.stillMotion } ?? false }
    /// The accelerometer says the phone is clearly being moved.
    var isShaking: Bool { motion.map { $0 >= RideTracker.Tune.stillMotion * 2 } ?? false }
}

struct TrackPoint: Codable {
    var t: TimeInterval
    var lat: Double
    var lon: Double
    var ele: Double
}

struct Sample: Codable, Equatable {
    /// distance, metres
    var d: Double
    /// altitude, metres
    var a: Double
}

enum RideStatus: Equatable {
    case moving, autoPaused, paused
}

struct RideState {
    var status: RideStatus = .moving
    var gpsWeak = true
    var startedAt = Date()
    /// seconds
    var moving: Double = 0
    var total: Double = 0
    /// metres
    var dist: Double = 0
    /// km/h
    var speed: Double = 0
    var max: Double = 0
    /// metres
    var alt: Double = 0
    var altMax: Double = 0
    var climb: Double = 0
    /// percent
    var grade: Double = 0
    var samples: [Sample] = []
    /// recorded path, one array per continuous segment (split at pauses)
    var track: [[TrackPoint]] = [[]]

    var avg: Double { moving > 0 ? dist / moving * 3.6 : 0 }
}

/// Turns a stream of location fixes into ride numbers. Pure: driven only by
/// fix timestamps.
///
/// Auto-pause is back-dated: a stop is confirmed a couple of seconds after it
/// began, then time and distance are rolled back to the moment it began; a
/// start is confirmed after about a second and the buffered fixes are
/// replayed. So the confirmation delay never leaks into the recorded numbers.
///
/// The receiver's speed is not used raw; it goes through `SpeedEstimator` first.
///
/// The thresholds are starting points and need tuning on real rides.
final class RideTracker {
    enum Tune {
        /// fixes worse than this are shown as "GPS weak"
        static let weakAcc = 35.0
        /// fixes worse than this add no distance
        static let rejectAcc = 65.0
        /// faster than this between two fixes is a position glitch (m/s)
        static let maxSpeed = 35.0
        /// below this the bike is stopped (m/s)
        static let stopSpeed = 0.6
        /// with a still accelerometer, anything below this is GPS drift (m/s)
        static let driftSpeed = 1.4
        /// above this the bike is moving again (m/s)
        static let goSpeed = 1.2
        /// accelerometer level under which the phone counts as still (g)
        static let stillMotion = 0.012
        /// how long a stop must last before it is confirmed (s)
        static let stopConfirm = 2.5
        /// same, when the accelerometer agrees that the phone is still (s).
        /// At one fix per second this means the first still fix confirms.
        static let stillConfirm = 1.0
        /// how long movement must last before it is confirmed (s)
        static let goConfirm = 1.0
        /// with a shaking accelerometer, above this the restart needs no confirmation (m/s)
        static let fastGoSpeed = 2.0
        /// receiver speed with a larger reported error than this is not used (m/s)
        static let speedAccLimit = 2.5
        /// span over which displacement speed is measured (s)
        static let posWindow = 2.0
        /// receiver speed above `displacement speed * lagRatio + lagMargin` is lagging
        static let lagRatio = 1.5
        static let lagMargin = 1.0
        /// no bicycle gains speed faster than this (m/s²)
        static let maxAccel = 3.0
        /// longest gap between fixes still credited as riding time (s)
        static let maxGap = 15.0
        /// barometer: climb hysteresis and grade window (m)
        static let baroClimb = 1.5
        static let baroWindow = 40.0
        /// GPS altitude is much noisier
        static let gpsClimb = 4.0
        static let gpsWindow = 100.0
        /// spacing of elevation-profile samples (m)
        static let sampleEvery = 20.0
    }

    private struct Snapshot {
        var since: TimeInterval
        var moving, dist, climb, altMax, max: Double
        var samples, trackPts: Int
        var climbRef: Double?
    }

    private struct Step {
        var fix: Fix
        var dd, dt, v: Double
        var weak: Bool
    }

    private(set) var state: RideState
    private let autoPause: () -> Bool

    private var last: Fix?
    private var altBase: Double?
    private var altSmooth: Double?
    private var climbRef: Double?
    private var window: [Sample] = []
    private var lastSampleD = 0.0
    private var stopCand: Snapshot?
    private var goBuf: [Step] = []
    private var speed = SpeedEstimator()

    init(autoPause: @escaping () -> Bool, startedAt: Date = Date()) {
        self.autoPause = autoPause
        state = RideState()
        state.startedAt = startedAt
    }

    func setTotal(_ seconds: Double) {
        state.total = seconds
    }

    func pause() {
        // A stop that was still being confirmed is real: roll back to its start.
        if let cand = stopCand { rollback(cand) }
        stopCand = nil
        goBuf = []
        state.status = .paused
        state.speed = 0
        state.grade = 0
    }

    func resume() {
        state.status = .moving
        stopCand = nil
        goBuf = []
        window = []
        newSegment()
    }

    func push(_ fix: Fix) {
        let prev = last
        last = fix

        let weak = fix.isWeak
        state.gpsWeak = weak

        let alt = altitude(fix)
        guard let prev else {
            state.alt = alt
            state.altMax = alt
            climbRef = alt
            state.samples.append(Sample(d: 0, a: alt))
            speed.begin(fix)
            return
        }
        state.alt = alt

        let dt = fix.t - prev.t
        if dt <= 0 { return }
        let dd = Self.haversine(prev.lat, prev.lon, fix.lat, fix.lon)
        if dd / dt > Tune.maxSpeed { return }
        // Estimated on every fix, paused or not, so it is current on resume.
        let v = speed.update(fix, dd: dd, dt: dt)
        if state.status == .paused { return }
        let step = Step(fix: fix, dd: dd, dt: dt, v: v, weak: weak)

        if !autoPause() {
            if state.status == .autoPaused { state.status = .moving }
            stopCand = nil
            goBuf = []
            accumulate(step)
            return
        }

        let still = fix.isStill

        if state.status == .moving {
            let stillStop = still && v < Tune.driftSpeed
            let stopped = v < Tune.stopSpeed || stillStop
            if !stopped {
                stopCand = nil
                accumulate(step)
                return
            }
            if stopCand == nil { stopCand = snapshot(since: prev.t) }
            let need = stillStop ? Tune.stillConfirm : Tune.stopConfirm
            if let cand = stopCand, fix.t - cand.since >= need {
                rollback(cand)
                stopCand = nil
                state.status = .autoPaused
                state.speed = 0
                state.grade = 0
                return
            }
            // Still unconfirmed: keep counting, rollback undoes it if it was a stop.
            accumulate(step)
            // GPS and accelerometer agree: what is left of the speed is drift.
            if stillStop { state.speed = 0 }
            return
        }

        // autoPaused
        let going = v > Tune.goSpeed && !(still && v < Tune.driftSpeed * 1.5)
        if !going {
            goBuf = []
            state.speed = 0
            return
        }
        goBuf.append(step)
        if (fix.isShaking && v > Tune.fastGoSpeed) || fix.t - goBuf[0].fix.t >= Tune.goConfirm {
            state.status = .moving
            window = []
            newSegment()
            for st in goBuf { accumulate(st) }
            goBuf = []
        }
    }

    private func altitude(_ fix: Fix) -> Double {
        if let baro = fix.baro {
            if altBase == nil { altBase = (fix.alt ?? 0) - baro }
            return (altBase ?? 0) + baro
        }
        if let alt = fix.alt {
            altSmooth = altSmooth.map { $0 + (alt - $0) * 0.15 } ?? alt
            return altSmooth ?? alt
        }
        return state.alt
    }

    private func accumulate(_ step: Step) {
        let fix = step.fix
        let usable = fix.isUsable
        let baro = fix.baro != nil
        let alt = state.alt

        if step.dt <= Tune.maxGap || step.dd / step.dt > Tune.goSpeed { state.moving += step.dt }
        if usable { state.dist += step.dd }
        state.speed = step.v * 3.6
        if !step.weak { state.max = Swift.max(state.max, state.speed) }
        state.altMax = Swift.max(state.altMax, alt)

        // Climb with hysteresis, so sensor noise on flat ground adds nothing.
        let hyst = baro ? Tune.baroClimb : Tune.gpsClimb
        let ref = climbRef ?? alt
        if alt - ref >= hyst {
            state.climb += alt - ref
            climbRef = alt
        } else if alt < ref - hyst {
            climbRef = alt
        } else {
            climbRef = ref
        }

        // Grade over a distance window, not between two fixes.
        let win = baro ? Tune.baroWindow : Tune.gpsWindow
        window.append(Sample(d: state.dist, a: alt))
        while window.count > 2 && window[1].d <= state.dist - win { window.removeFirst() }
        let run = state.dist - window[0].d
        if run >= win * 0.6 {
            let raw = Swift.max(-25, Swift.min(25, (alt - window[0].a) / run * 100))
            state.grade += (raw - state.grade) * 0.3
        } else {
            state.grade *= 0.8
        }

        if state.dist - lastSampleD >= Tune.sampleEvery {
            lastSampleD = state.dist
            state.samples.append(Sample(d: state.dist, a: alt))
        }
        if usable {
            state.track[state.track.count - 1].append(TrackPoint(t: fix.t, lat: fix.lat, lon: fix.lon, ele: alt))
        }
    }

    private func newSegment() {
        if !(state.track.last ?? []).isEmpty { state.track.append([]) }
    }

    private func snapshot(since: TimeInterval) -> Snapshot {
        Snapshot(
            since: since, moving: state.moving, dist: state.dist, climb: state.climb,
            altMax: state.altMax, max: state.max, samples: state.samples.count,
            trackPts: state.track.last?.count ?? 0, climbRef: climbRef
        )
    }

    private func rollback(_ snap: Snapshot) {
        state.moving = snap.moving
        state.dist = snap.dist
        state.climb = snap.climb
        state.altMax = snap.altMax
        state.max = snap.max
        let keep = Swift.max(1, snap.samples)
        if state.samples.count > keep { state.samples.removeLast(state.samples.count - keep) }
        let seg = state.track.count - 1
        if state.track[seg].count > snap.trackPts {
            state.track[seg].removeLast(state.track[seg].count - snap.trackPts)
        }
        climbRef = snap.climbRef
        lastSampleD = state.samples.last?.d ?? 0
        window = []
    }

    static func haversine(_ aLat: Double, _ aLon: Double, _ bLat: Double, _ bLon: Double) -> Double {
        let rad = Double.pi / 180
        let dLat = (bLat - aLat) * rad
        let dLon = (bLon - aLon) * rad
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(aLat * rad) * cos(bLat * rad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * 6_371_000 * asin(Swift.min(1, h.squareRoot()))
    }
}
