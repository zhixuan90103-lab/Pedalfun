import XCTest
@testable import Pedalfun

/// Display rules that came out of design decisions and past bugs.
final class PresentationTests: XCTestCase {
    private let km = Fmt(units: .km)

    private func state(_ edit: (inout RideState) -> Void) -> RideState {
        var s = RideState()
        s.gpsWeak = false
        s.speed = 26.8
        s.moving = 1744
        s.dist = 11_360
        edit(&s)
        return s
    }

    func testMoving() {
        let p = RidePresentation(state { $0.grade = 0.4 }, km)
        XCTAssertEqual(p.field, .moving)
        XCTAssertEqual(p.statusText, "记录中")
        XCTAssertEqual(p.speedText, "26.8")
        XCTAssertEqual(p.timeLabel, "时间")
        XCTAssertEqual(p.band, .flat)
        XCTAssertFalse(p.showsPausedActions)
    }

    func testUphillIsRedBandDownhillIsGreenBand() {
        XCTAssertEqual(RidePresentation(state { $0.grade = 6.2 }, km).band, .up)
        XCTAssertEqual(RidePresentation(state { $0.grade = 6.2 }, km).gradeLabel, "上坡 %")
        XCTAssertEqual(RidePresentation(state { $0.grade = -4.8 }, km).band, .down)
        XCTAssertEqual(RidePresentation(state { $0.grade = -4.8 }, km).gradeText, "−4.8")
        XCTAssertEqual(RidePresentation(state { $0.grade = 2.9 }, km).band, .flat)
    }

    /// A stopped clock shows no grade, whatever the last reading was.
    func testStoppedClockHasNoGrade() {
        for status in [RideStatus.paused, .autoPaused] {
            let p = RidePresentation(state { $0.status = status; $0.grade = 7; $0.speed = 0 }, km)
            XCTAssertEqual(p.band, .flat)
            XCTAssertEqual(p.gradeText, "0.0")
            XCTAssertEqual(p.timeLabel, "时间（已停表）")
        }
    }

    func testPausedShowsPlayAndStop() {
        let p = RidePresentation(state { $0.status = .paused }, km)
        XCTAssertEqual(p.field, .paused)
        XCTAssertEqual(p.statusText, "已暂停")
        XCTAssertTrue(p.showsPausedActions)
    }

    func testAutoPauseKeepsThePauseButton() {
        let p = RidePresentation(state { $0.status = .autoPaused }, km)
        XCTAssertEqual(p.field, .autoPaused)
        XCTAssertFalse(p.showsPausedActions)
    }

    /// Weak GPS hides the speed instead of showing a wrong one — but only while moving.
    func testWeakGpsHidesSpeedOnlyWhileMoving() {
        let moving = RidePresentation(state { $0.gpsWeak = true }, km)
        XCTAssertTrue(moving.weak)
        XCTAssertEqual(moving.speedText, "--")
        let paused = RidePresentation(state { $0.gpsWeak = true; $0.status = .paused; $0.speed = 0 }, km)
        XCTAssertFalse(paused.weak)
        XCTAssertEqual(paused.statusText, "已暂停")
    }

    func testUnits() {
        let mi = Fmt(units: .mi)
        XCTAssertEqual(km.dist(11_360), "11.36")
        XCTAssertEqual(mi.dist(1_609.344), "1.00")
        XCTAssertEqual(km.dist(102_600), "102.6") // three digits: one decimal, so the width holds
        XCTAssertEqual(mi.speedUnit, "mph")
        XCTAssertEqual(mi.alt(100), "328")
        XCTAssertEqual(Fmt.dur(3_725), "1:02:05")
        XCTAssertEqual(Fmt.grade(0.04), "0.0")
    }

    func testWeekStartsOnMondayAndCarriesDates() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let wed = cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 14))!
        func ride(_ day: Int, _ km: Double) -> Ride {
            let d = cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 9))!
            return Ride(id: "t\(day)", date: d, name: "", dist: km * 1000, moving: 600, total: 700, max: 30, climb: 10, altMax: 50, samples: [], hasTrack: false)
        }
        let w = WeekStats(rides: [ride(18, 5), ride(16, 20), ride(15, 99)], now: wed) // the 15th is last week's Sunday
        XCTAssertEqual(w.todayIndex, 2)
        XCTAssertEqual(w.dayNumbers, [16, 17, 18, 19, 20, 21, 22])
        XCTAssertEqual(w.count, 2)
        XCTAssertEqual(w.dist, 25_000)
        XCTAssertEqual(w.perDay[0], 20_000)
        XCTAssertEqual(w.perDay[2], 5_000)
    }
}
