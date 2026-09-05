import Foundation
import SpriteKit
import Testing
@testable import Humline

@MainActor
@Suite(.serialized)
struct FlightControllerTests {
    @Test func startsIdleOnTheOpeningPitch() {
        let controller = FlightController(
            melody: TestFixtures.drone,
            calibration: .fallbackHum,
            inputMode: .hum
        )
        #expect(controller.flightState == .idle)
        #expect(controller.progress == 0)
        #expect(abs(controller.sungNormalized - 0.5) < 0.001)
        #expect(controller.envelope.points.isEmpty)
        #expect(controller.melody.id == "test-drone")
    }

    @Test func armAndCalibrationChangeState() {
        let controller = makeController()
        controller.beginCalibration()
        #expect(controller.flightState == .calibrating)
        #expect(controller.statusMessage.contains("comfortable low"))

        controller.arm()
        #expect(controller.flightState == .armed)
        #expect(controller.statusMessage.contains("gold ribbon"))
    }

    @Test func tickWhileIdleDoesNothing() {
        let controller = makeController()
        controller.tick(dt: 0.05)
        #expect(controller.flightState == .idle)
        #expect(controller.songTime == 0)
    }

    @Test func ignoresOutOfRangeDelta() {
        let controller = makeController()
        controller.arm()
        controller.setManualPitch(0.5)
        controller.tick(dt: 0)
        controller.tick(dt: 0.4)
        #expect(controller.flightState == .armed)
        #expect(controller.songTime == 0)
    }

    @Test func manualPitchStartsAFlight() {
        let controller = makeController()
        controller.arm()
        controller.setManualPitch(0.5)
        controller.tick(dt: 0.05)
        #expect(controller.flightState == .flying)
        #expect(controller.songTime > 0)
        #expect(!controller.envelope.points.isEmpty)
    }

    @Test func silenceAfterGraceStalls() {
        let controller = makeController()
        controller.arm()
        fly(controller, pitch: 0.5, seconds: 0.05)
        controller.setManualPitch(nil)
        controller.ingest(.silent)
        fly(controller, pitch: nil, seconds: 0.8)
        #expect(controller.flightState == .stalled)
        #expect(controller.statusMessage.contains("silent"))
        #expect(controller.flightState.isTerminal)
    }

    @Test func energyWithoutPitchLockDoesNotStall() {
        let controller = makeController()
        controller.arm()
        fly(controller, pitch: 0.5, seconds: 0.05)
        controller.setManualPitch(nil)
        let tone = PitchReading(
            hz: nil,
            midi: nil,
            rms: 0.02,
            confidence: 0,
            voiced: false,
            timestamp: 1
        )
        var elapsed: TimeInterval = 0
        while elapsed < 0.8, !controller.flightState.isTerminal {
            controller.ingest(tone)
            controller.tick(dt: 0.05)
            elapsed += 0.05
        }
        #expect(controller.flightState == .flying)
        #expect(!controller.statusMessage.contains("silent"))
    }

    @Test func leavingTheRibbonCrashes() {
        let controller = makeController()
        controller.arm()
        fly(controller, pitch: 0.5, seconds: 0.05)
        fly(controller, pitch: 1.0, seconds: 0.5)
        #expect(controller.flightState == .crashed)
        #expect(controller.statusMessage.contains("left the gold ribbon"))
    }

    @Test func stayingInsideClearsAndRecordsAGhost() {
        let controller = makeController()
        controller.arm()
        fly(controller, pitch: 0.5, seconds: controller.terrain.duration + 0.1)
        #expect(controller.flightState == .cleared)
        #expect(controller.ghost != nil)
        #expect(controller.ghost?.melodyId == TestFixtures.drone.id)
        #expect(controller.progress == 1)
    }

    @Test func resetClearsEnvelopeAndOptionallyGhost() {
        let controller = makeController()
        controller.arm()
        fly(controller, pitch: 0.5, seconds: controller.terrain.duration + 0.1)
        #expect(controller.ghost != nil)

        controller.resetRun(keepGhost: true)
        #expect(controller.flightState == .idle)
        #expect(controller.envelope.points.isEmpty)
        #expect(controller.ghost != nil)

        controller.resetRun(keepGhost: false)
        #expect(controller.ghost == nil)
    }

    @Test func clampsManualPitch() {
        let controller = makeController()
        controller.arm()
        controller.setManualPitch(1.8)
        controller.tick(dt: 0.05)
        #expect(controller.flightState == .flying)
        controller.setManualPitch(-0.4)
        fly(controller, pitch: -0.4, seconds: 0.2)
        #expect(controller.sungNormalized >= 0)
        #expect(controller.sungNormalized <= 1)
    }

    @Test func makeSceneAttaches() {
        let controller = makeController()
        let scene = controller.makeScene(size: CGSize(width: 800, height: 360))
        #expect(controller.scene === scene)
        #expect(scene.size.width == 800)
        #expect(scene.scaleMode == .resizeFill)
    }

    @Test func liveVoicedPitchDrivesAltitude() {
        let controller = makeController()
        controller.calibration = VoiceCalibration(lowHz: 110, highHz: 330)
        controller.arm()
        controller.ingest(PitchReading(
            hz: 330,
            midi: YinDetector.midi(fromHz: 330),
            rms: 0.2,
            confidence: 0.9,
            voiced: true,
            timestamp: 1
        ))
        controller.tick(dt: 0.05)
        #expect(controller.flightState == .flying)
        #expect(controller.sungNormalized > 0.5)
    }

    private func makeController() -> FlightController {
        FlightController(
            melody: TestFixtures.drone,
            calibration: .fallbackHum,
            inputMode: .hum
        )
    }

    private func fly(_ controller: FlightController, pitch: Double?, seconds: TimeInterval, step: TimeInterval = 0.05) {
        if let pitch {
            controller.setManualPitch(pitch)
        } else {
            controller.setManualPitch(nil)
        }
        var elapsed: TimeInterval = 0
        while elapsed < seconds, !controller.flightState.isTerminal {
            controller.tick(dt: step)
            elapsed += step
        }
    }
}

struct FlightStateCoverageTests {
    @Test(arguments: [
        (FlightState.idle, false, false),
        (FlightState.calibrating, false, false),
        (FlightState.armed, false, false),
        (FlightState.flying, false, true),
        (FlightState.stalled, true, false),
        (FlightState.crashed, true, false),
        (FlightState.cleared, true, false),
    ])
    func flags(state: FlightState, isTerminal: Bool, allowsFlight: Bool) {
        #expect(state.isTerminal == isTerminal)
        #expect(state.allowsFlight == allowsFlight)
    }
}

struct PhysicsCategoryTests {
    @Test func bitsDoNotOverlap() {
        #expect(PhysicsCategory.none == 0)
        #expect(PhysicsCategory.craft & PhysicsCategory.wall == 0)
        #expect(PhysicsCategory.craft != PhysicsCategory.wall)
    }
}

struct FlightRulesEdgeTests {
    @Test func easeDoesNotOvershootOnSmallSteps() {
        var value = 0.0
        for _ in 0..<40 {
            value = FlightRules.ease(current: value, target: 1, dt: 0.016)
        }
        #expect(value > 0.9)
        #expect(value <= 1)
    }

    @Test func crashRequiresBeingOutside() {
        #expect(!FlightRules.shouldCrash(sung: 0.55, center: 0.5, halfWidth: 0.1, outsideDuration: 1))
        #expect(FlightRules.shouldCrash(sung: 0.0, center: 0.5, halfWidth: 0.1, outsideDuration: FlightRules.crashGrace))
    }
}
