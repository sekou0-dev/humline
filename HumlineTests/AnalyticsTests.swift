import Foundation
import Testing
@testable import Humline

@MainActor
@Suite(.serialized)
struct AnalyticsTests {
    @Test func testHostDoesNotInitializeTheSDK() {
        #expect(HumlineAnalytics.isTestEnvironment)
        #expect(HumlineAnalytics.appID == "A25F65A7-B2EF-47C0-9508-E2622E465030")
        HumlineAnalytics.start()
    }

    @Test func recorderCapturesSignalsWithoutSending() {
        TestSupport.withAnalyticsLog { log in
            HumlineAnalytics.signal("Menu.howToPlay", parameters: ["source": "test"])
            #expect(log.names() == ["Menu.howToPlay"])
            #expect(log.events.first?.parameters["source"] == "test")
        }
    }

    @Test func armAndFlightEmitPhraseAndOutcomeSignals() {
        TestSupport.withAnalyticsLog { log in
            let controller = FlightController(
                melody: TestFixtures.drone,
                calibration: .fallbackHum,
                inputMode: .hum
            )
            controller.arm()
            #expect(log.names() == ["Phrase.started"])
            #expect(log.events[0].parameters["melodyId"] == "test-drone")
            #expect(log.events[0].parameters["inputMode"] == "hum")
            #expect(log.events[0].parameters["shared"] == "false")

            controller.setManualPitch(0.5)
            var elapsed: TimeInterval = 0
            while elapsed < controller.terrain.duration + 0.1, !controller.flightState.isTerminal {
                controller.tick(dt: 0.05)
                elapsed += 0.05
            }

            #expect(controller.flightState == .cleared)
            #expect(log.names() == ["Phrase.started", "Flight.started", "Flight.cleared"])
            #expect(log.events.last?.parameters["progress"] == "1.00")
        }
    }

    @Test func stallAndCrashEmitMatchingSignals() {
        TestSupport.withAnalyticsLog { log in
            let controller = FlightController(
                melody: TestFixtures.drone,
                calibration: .fallbackHum,
                inputMode: .hum
            )
            controller.arm()
            controller.setManualPitch(0.5)
            controller.tick(dt: 0.05)
            controller.setManualPitch(nil)
            var elapsed: TimeInterval = 0
            while elapsed < 0.6, !controller.flightState.isTerminal {
                controller.tick(dt: 0.05)
                elapsed += 0.05
            }
            #expect(controller.flightState == .stalled)
            #expect(log.names().contains("Flight.stalled"))
        }

        TestSupport.withAnalyticsLog { log in
            let controller = FlightController(
                melody: TestFixtures.drone,
                calibration: .fallbackHum,
                inputMode: .hum
            )
            controller.arm()
            controller.setManualPitch(0.5)
            controller.tick(dt: 0.05)
            controller.setManualPitch(1.0)
            var elapsed: TimeInterval = 0
            while elapsed < 0.5, !controller.flightState.isTerminal {
                controller.tick(dt: 0.05)
                elapsed += 0.05
            }
            #expect(controller.flightState == .crashed)
            #expect(log.names().contains("Flight.crashed"))
        }
    }

    @Test func inputModeChangeEmitsASignal() {
        TestSupport.withAnalyticsLog { log in
            let previousMode = AppSettings.inputMode
            defer { AppSettings.inputMode = previousMode }
            let controller = FlightController(
                melody: TestFixtures.drone,
                calibration: .fallbackHum,
                inputMode: .hum
            )
            controller.inputMode = .whistle
            #expect(log.names() == ["Input.modeChanged"])
            #expect(log.events[0].parameters["inputMode"] == "whistle")
            #expect(log.events[0].parameters["previous"] == "hum")
        }
    }
}
