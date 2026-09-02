import XCTest

final class HumlineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMenuShowsPhrases() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Humline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["First Phrase"].exists)
        XCTAssertTrue(app.buttons["How to play"].exists)
        XCTAssertTrue(app.buttons["Pitch gym"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
