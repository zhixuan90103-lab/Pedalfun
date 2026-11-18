import XCTest

/// Drives the real touch path of the buttons that cannot be checked from screenshots.
final class PedalfunUITests: XCTestCase {
    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    /// The hold must react at touch-down. The app reports how long the touch
    /// took to reach the hold logic; a recognition delay would show up here.
    func testHoldStartsOnTouchDown() {
        let app = launch(["-mock", "1", "-demo", "paused"])
        let hold = app.buttons["holdButton"]
        XCTAssertTrue(hold.waitForExistence(timeout: 5))
        sleep(1)

        var samples: [Int] = []
        for _ in 0..<5 {
            hold.press(forDuration: 0.3)
            samples.append(Int(hold.value as? String ?? "") ?? -1)
            sleep(1)
        }
        print("HOLD_LATENCY_MS \(samples)")
        XCTAssertFalse(samples.contains(-1), "touch-down was not reported")
        XCTAssertLessThan(samples.max() ?? 999, 50, "touch-down reached the hold logic late: \(samples) ms")

        // 0.3 s is shorter than the hold: it must not end the ride, and must hint.
        // Checked straight after a press: the hint only stays up for about two seconds.
        hold.press(forDuration: 0.3)
        XCTAssertTrue(app.staticTexts["长按结束骑行"].waitForExistence(timeout: 2))
        XCTAssertTrue(hold.exists)
    }

    func testFullHoldEndsRide() {
        let app = launch(["-mock", "1", "-demo", "paused"])
        let hold = app.buttons["holdButton"]
        XCTAssertTrue(hold.waitForExistence(timeout: 5))
        sleep(1)
        hold.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 3), "summary did not appear after a full hold")
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["开始骑行"].waitForExistence(timeout: 3))
    }

    func testPauseAndResume() {
        let app = launch(["-mock", "1", "-demo", "cruise"])
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 5))
        sleep(1)
        app.buttons["暂停"].tap()
        XCTAssertTrue(app.buttons["继续"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["holdButton"].exists)
        app.buttons["继续"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 2))
    }

    func testSwipeToDelete() {
        let app = launch(["-mock", "1", "-demo", "history"])
        let cells = app.cells
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 5))
        let before = cells.count
        cells.element(boundBy: 1).swipeLeft()
        let delete = app.buttons["trash"].firstMatch.exists ? app.buttons["trash"].firstMatch : app.buttons["删除"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 2), "delete action did not appear")
        delete.tap()
        sleep(1)
        XCTAssertEqual(cells.count, before - 1)
    }
}
