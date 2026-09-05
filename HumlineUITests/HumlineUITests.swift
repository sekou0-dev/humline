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
        XCTAssertTrue(phrase(app, title: "First Phrase", id: "first-phrase").waitForExistence(timeout: 3))
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
    func testHowToPlayCloseReturnsToMenu() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["How to play"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Humline"].waitForExistence(timeout: 5))
        XCTAssertTrue(phrase(app, title: "First Phrase", id: "first-phrase").waitForExistence(timeout: 3))
    }

    @MainActor
    func testPitchGymOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["Pitch gym"].tap()
        XCTAssertTrue(app.navigationBars["Pitch gym"].waitForExistence(timeout: 5)
            || app.staticTexts["Pitch gym"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Humline"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFirstPhraseShowsFlightHUD() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let firstPhrase = phrase(app, title: "First Phrase", id: "first-phrase")
        XCTAssertTrue(firstPhrase.waitForExistence(timeout: 5))
        firstPhrase.tap()

        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["First Phrase"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.segmentedControls.firstMatch.exists)

        app.buttons["Menu"].tap()
        XCTAssertTrue(app.staticTexts["Humline"].waitForExistence(timeout: 5))
        XCTAssertTrue(firstPhrase.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPaidPhrasesStayLockedWithoutThePack() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-keep-locked"]
        app.launch()

        let fifthCliff = phrase(app, title: "Fifth Cliff", id: "fifth-cliff")
        XCTAssertTrue(fifthCliff.waitForExistence(timeout: 5))
        XCTAssertFalse(fifthCliff.isEnabled)
        XCTAssertTrue(phrase(app, title: "First Phrase", id: "first-phrase").isEnabled)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Unlock'")).firstMatch.exists)
    }

    /// Phrase rows are buttons whose label is the title, or the title plus detail.
    private func phrase(_ app: XCUIApplication, title: String, id: String) -> XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR label == %@ OR label BEGINSWITH %@",
            id,
            title,
            title
        )
        return app.buttons.matching(predicate).firstMatch
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
