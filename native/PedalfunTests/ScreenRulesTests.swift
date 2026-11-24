import XCTest
@testable import Pedalfun

/// What the home and summary screens show, and the speed checks on their own.
final class ScreenRulesTests: XCTestCase {
    private let km = Fmt(units: .km)
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    /// Wednesday 18 Nov 2026, with rides on Monday (20 km) and Wednesday (5 km + 3 km).
    private func week(profile: Profile = Profile(weight: 70)) -> WeekStats {
        let wed = cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 14))!
        func ride(_ day: Int, _ hour: Int, _ km: Double) -> Ride {
            let d = cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
            return Ride(id: "t\(day)-\(hour)", date: d, name: "晨间骑行", dist: km * 1000, moving: 600, total: 700,
                        max: 30, climb: 10, altMax: 50, samples: [], hasTrack: false)
        }
        return WeekStats(rides: [ride(18, 9, 5), ride(18, 12, 3), ride(16, 9, 20)], profile: profile, now: wed)
    }

    // MARK: home

    func testHomeDefaultsToToday() {
        let p = HomePresentation(week(), picked: nil, hasWeight: true, km)
        XCTAssertEqual(p.picked, 2)
        XCTAssertEqual(p.weekDist, "28.0")
        XCTAssertEqual(p.weekSummary, "3 次骑行，0:30:00，爬升 30 m")
        XCTAssertEqual(p.dayTitle, "今天，2 次骑行")
        XCTAssertEqual(p.dayCells.map(\.label), ["里程", "均速", "时间", "消耗"])
        XCTAssertEqual(p.dayCells[0], StatCell("里程", "km", "8.0"))
        XCTAssertEqual(p.dayCells[1].value, "24.0") // 8 km in 20 min
        XCTAssertEqual(p.dayCells[2].value, "0:20:00")
        XCTAssertNotEqual(p.dayCells[3].value, StatCell.none)
        XCTAssertFalse(p.showsWeightHint)
    }

    func testHomeBars() {
        let p = HomePresentation(week(), picked: nil, hasWeight: true, km)
        XCTAssertEqual(p.bars.count, 7)
        XCTAssertEqual(p.bars.map(\.text), ["20.0", nil, "8.0", nil, nil, nil, nil])
        XCTAssertEqual(p.bars[0].ratio, 1)
        XCTAssertEqual(p.bars[2].ratio, 0.4, accuracy: 0.001)
        XCTAssertEqual(p.bars[1].ratio, 0)
        XCTAssertEqual(p.bars.map(\.isToday), [false, false, true, false, false, false, false])
        XCTAssertEqual(p.bars.map(\.isPicked), [false, false, true, false, false, false, false])
        XCTAssertEqual(p.bars.map(\.isFuture), [false, false, false, true, true, true, true])
        XCTAssertEqual(p.bars[0].accessibilityLabel, "周一，20.0 km")
    }

    func testHomePickedDayAndEmptyDay() {
        let mon = HomePresentation(week(), picked: 0, hasWeight: true, km)
        XCTAssertEqual(mon.dayTitle, "周一，1 次骑行")
        XCTAssertTrue(mon.bars[0].isPicked)
        XCTAssertTrue(mon.bars[2].isToday, "today keeps its mark when another day is picked")

        let tue = HomePresentation(week(), picked: 1, hasWeight: true, km)
        XCTAssertEqual(tue.dayTitle, "周二，没有骑行")
        XCTAssertEqual(tue.dayCells.map(\.value), ["--", "--", "--", "--"])
        XCTAssertEqual(tue.dayCells.map(\.label), ["里程", "均速", "时间", "消耗"], "cells stay put")

        // A day still to come cannot be picked: falls back to today.
        XCTAssertEqual(HomePresentation(week(), picked: 5, hasWeight: true, km).picked, 2)
    }

    func testHomeWithoutWeight() {
        let p = HomePresentation(week(profile: Profile()), picked: nil, hasWeight: false, km)
        XCTAssertEqual(p.dayCells[3].value, "--")
        XCTAssertEqual(p.dayCells[0].value, "8.0")
        XCTAssertTrue(p.showsWeightHint)
    }

    /// The label is mid-bar on a tall fill, above a short one, and never across the edge.
    func testBarLabelNeverStraddlesTheFill() {
        let tall = HomePresentation.labelPlace(height: 100, fill: 90, half: 15)
        XCTAssertEqual(tall, .init(centre: 50, onFill: true))
        let short = HomePresentation.labelPlace(height: 100, fill: 20, half: 15)
        XCTAssertEqual(short, .init(centre: 50, onFill: false))
        for fill in stride(from: 0.0, through: 100, by: 1) {
            let p = HomePresentation.labelPlace(height: 100, fill: fill, half: 15)
            let bottom = p.centre - 15, top = p.centre + 15
            XCTAssertTrue(p.onFill ? top <= fill : bottom >= fill || fill > 100 - 15 * 2 - 4,
                          "label across the edge at fill \(fill)")
            XCTAssertLessThanOrEqual(top, 100)
        }
    }

    // MARK: summary

    func testSummaryGroups() {
        let d = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 15, minute: 1))!
        let ride = Ride(id: "r", date: d, name: "午后骑行", dist: 62_300, moving: 11_108, total: 11_972,
                        max: 62.9, climb: 653, altMax: 830, samples: [], hasTrack: false)
        let p = SummaryPresentation(ride, live: true, profile: Profile(), km)
        XCTAssertEqual(p.topTitle, "11月14日 周六 15:01")
        XCTAssertEqual(p.name, "午后骑行，已保存")
        XCTAssertEqual(p.distText, "62.30")
        XCTAssertEqual(p.endLabel, "62.3 km")
        XCTAssertEqual(p.groups.map(\.title), ["时间", "速度", "海拔", "消耗"])
        XCTAssertEqual(p.groups[0].cells, [StatCell("移动时间", nil, "3:05:08"), StatCell("总耗时", nil, "3:19:32")])
        XCTAssertEqual(p.groups[1].cells, [StatCell("均速", "km/h", "20.2"), StatCell("最高", "km/h", "62.9")])
        XCTAssertEqual(p.groups[2].cells, [StatCell("爬升", "m", "653"), StatCell("最高", "m", "830")])
        XCTAssertEqual(p.groups[3].cells, [StatCell("估算", "kcal", "--")])

        let detail = SummaryPresentation(ride, live: false, profile: Profile(weight: 70), Fmt(units: .mi))
        XCTAssertEqual(detail.name, "午后骑行")
        XCTAssertEqual(detail.groups[1].cells[0].unit, "mph")
        XCTAssertEqual(detail.groups[2].cells[0].unit, "ft")
        XCTAssertNotEqual(detail.groups[3].cells[0].value, "--")
    }

    // MARK: speed checks

    private func fix(_ t: Double, metres: Double, speed: Double?, acc: Double? = 0.3, hAcc: Double = 5) -> Fix {
        Fix(t: t, lat: 31.2 + metres / 111_194.9, lon: 121.4, speed: speed, speedAcc: acc, hAcc: hAcc,
            alt: nil, baro: nil, motion: nil)
    }

    func testSpeedEstimatorTrustsAConsistentReceiver() {
        var est = SpeedEstimator()
        est.begin(fix(0, metres: 0, speed: 6))
        var v = 0.0
        for i in 1...5 { v = est.update(fix(Double(i), metres: Double(i) * 6, speed: 6), dd: 6, dt: 1) }
        XCTAssertEqual(v, 6)
    }

    func testSpeedEstimatorFallsBackToDisplacement() {
        var est = SpeedEstimator()
        est.begin(fix(0, metres: 0, speed: 2))
        var lagging = 0.0, invalid = 0.0, vague = 0.0
        for i in 1...5 {
            let t = Double(i)
            lagging = est.update(fix(t, metres: t * 2, speed: 2), dd: 2, dt: 1)
        }
        XCTAssertEqual(lagging, 2)
        // The receiver jumps to 9 m/s while the positions keep moving at 2.
        for i in 6...9 { lagging = est.update(fix(Double(i), metres: Double(i) * 2, speed: 9), dd: 2, dt: 1) }
        XCTAssertEqual(lagging, 2, accuracy: 0.01)
        invalid = est.update(fix(10, metres: 20, speed: -1, acc: -1), dd: 2, dt: 1)
        XCTAssertEqual(invalid, 2, accuracy: 0.01)
        vague = est.update(fix(11, metres: 22, speed: 3, acc: 6), dd: 2, dt: 1)
        XCTAssertEqual(vague, 2, accuracy: 0.01)
    }

    func testSpeedEstimatorLimitsRisesNotFalls() {
        var est = SpeedEstimator()
        est.begin(fix(0, metres: 0, speed: 0))
        // No position history yet, so only the acceleration limit applies.
        XCTAssertEqual(est.update(fix(1, metres: 10, speed: 10), dd: 10, dt: 1), RideTracker.Tune.maxAccel)
        XCTAssertEqual(est.update(fix(1.5, metres: 15, speed: 10), dd: 5, dt: 0.5), RideTracker.Tune.maxAccel * 1.5)
        XCTAssertEqual(est.update(fix(2.5, metres: 15, speed: 0), dd: 0, dt: 1), 0)
    }
}
