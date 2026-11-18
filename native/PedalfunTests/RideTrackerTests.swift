import XCTest
@testable import Pedalfun

/// The ride numbers, checked against synthetic rides with known answers.
final class RideTrackerTests: XCTestCase {
    private let metresPerDegree = 111_194.9

    /// 60 s at 8 m/s up a 5 % grade, 20 s stopped while GPS reports drift, 30 s at 7 m/s on the flat.
    private func ride(baro: Bool = true, motion: Bool = true, autoPause: Bool = true) -> (state: RideState, transitions: [Int: RideStatus]) {
        let t0 = 1_700_000_000.0
        var t = t0, lat = 31.2, alt = 0.0
        let tracker = RideTracker(autoPause: { autoPause }, startedAt: Date(timeIntervalSince1970: t0))
        var transitions: [Int: RideStatus] = [:]
        var last = RideStatus.moving
        func emit(_ v: Double, grade: Double, vibration: Double, reported: Double? = nil) {
            t += 1
            lat += v / metresPerDegree
            alt += v * grade / 100
            tracker.push(Fix(t: t, lat: lat, lon: 121.4, speed: reported ?? v, hAcc: 5, alt: 50 + alt,
                             baro: baro ? alt : nil, motion: motion ? vibration : nil))
            if tracker.state.status != last {
                last = tracker.state.status
                transitions[Int(t - t0)] = last
            }
        }
        emit(0, grade: 0, vibration: 0.002)
        for _ in 0..<60 { emit(8, grade: 5, vibration: 0.08) }
        for i in 0..<20 { emit(0, grade: 0, vibration: 0.003, reported: 0.3 + Double(i % 3) / 3) }
        for _ in 0..<30 { emit(7, grade: 0, vibration: 0.07) }
        return (tracker.state, transitions)
    }

    func testDistanceCountsOnlyRealMovement() {
        XCTAssertEqual(ride().state.dist, 690, accuracy: 10) // 480 + 210
    }

    /// The stop is confirmed a few seconds late, but those seconds must not be counted.
    func testAutoPauseIsBackDated() {
        let r = ride()
        XCTAssertEqual(r.state.moving, 90, accuracy: 2)
        let stop = r.transitions.first { $0.value == .autoPaused }?.key ?? 0
        let go = r.transitions.first { $0.value == .moving }?.key ?? 0
        XCTAssertLessThanOrEqual(stop - 61, 4, "stop confirmed too late")
        XCTAssertLessThanOrEqual(go - 81, 3, "restart confirmed too late")
    }

    func testClimbFromBarometer() {
        XCTAssertEqual(ride().state.climb, 24, accuracy: 1.5) // 480 m at 5 %
    }

    func testPauseSplitsTrackIntoSegments() {
        XCTAssertEqual(ride().state.track.filter { $0.count > 1 }.count, 2)
    }

    func testWithoutAutoPauseStopTimeCounts() {
        XCTAssertEqual(ride(autoPause: false).state.moving, 110, accuracy: 1)
    }

    func testManualPauseIgnoresFixes() {
        let tracker = RideTracker(autoPause: { true }, startedAt: Date(timeIntervalSince1970: 0))
        var t = 0.0, lat = 31.2
        func step() {
            t += 1
            lat += 8 / metresPerDegree
            tracker.push(Fix(t: t, lat: lat, lon: 121.4, speed: 8, hAcc: 5, alt: 50, baro: 0, motion: 0.08))
        }
        for _ in 0..<11 { step() }
        tracker.pause()
        for _ in 0..<30 { step() }
        tracker.resume()
        for _ in 0..<10 { step() }
        XCTAssertEqual(tracker.state.dist, 160, accuracy: 10)
        XCTAssertEqual(tracker.state.moving, 20, accuracy: 1)
    }

    func testGlitchesAndWeakFixesAddNoDistance() {
        let tracker = RideTracker(autoPause: { false }, startedAt: Date(timeIntervalSince1970: 0))
        func push(_ t: Double, _ metres: Double, acc: Double) {
            tracker.push(Fix(t: t, lat: 31.2 + metres / metresPerDegree, lon: 121.4, speed: nil, hAcc: acc, alt: 50, baro: nil, motion: nil))
        }
        push(1, 0, acc: 5)
        push(2, 8, acc: 5)
        push(3, 5_500, acc: 5) // teleport: rejected
        push(4, 24, acc: 5) // measured from the rejected point: also rejected
        push(5, 400, acc: 90) // too inaccurate to count
        XCTAssertEqual(tracker.state.dist, 8, accuracy: 1)
        XCTAssertTrue(tracker.state.gpsWeak)
    }
}
