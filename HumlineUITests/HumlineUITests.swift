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
    func testHowToPlayShowsFullInstructions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(app.buttons["How to play"].waitForExistence(timeout: 5))
        app.buttons["How to play"].tap()

        XCTAssertTrue(app.staticTexts["You are the instrument"].waitForExistence(timeout: 5))
        XCTAssertTrue(labelExists(in: app, containing: "the craft stalls"))

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["The land is the melody"].waitForExistence(timeout: 3))
        XCTAssertTrue(labelExists(in: app, containing: "Stay inside the gold ribbon"))

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Find your range"].waitForExistence(timeout: 3))
        XCTAssertTrue(labelExists(in: app, containing: "comfortable low note"))

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["The microphone stays here"].waitForExistence(timeout: 3))
        XCTAssertTrue(labelExists(in: app, containing: "never uploaded"))
    }

    private func labelExists(in app: XCUIApplication, containing fragment: String) -> Bool {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch.waitForExistence(timeout: 2)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
