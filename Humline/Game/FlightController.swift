import Combine
import Foundation
import SpriteKit

@MainActor
final class FlightController: ObservableObject, Identifiable {
    let id = UUID()
    let melody: Melody
    let terrain: TerrainGeometry

    @Published private(set) var flightState: FlightState = .idle
    @Published private(set) var livePitch: PitchReading = .silent
    @Published private(set) var sungNormalized: Double = 0.5
    @Published private(set) var targetNormalized: Double = 0.5
    @Published private(set) var songTime: TimeInterval = 0
    @Published private(set) var statusMessage = "Hum to stay inside the song."
    @Published var inputMode: InputMode {
        didSet {
            tracker.mode = inputMode
            AppSettings.inputMode = inputMode
        }
    }
    @Published var calibration: VoiceCalibration
    @Published var showDebugHUD = false

    let tracker = PitchTracker()
    private(set) var scene: FlightScene?
    private(set) var envelope: PerformanceEnvelope
    var ghost: PerformanceEnvelope?

    private var quietDuration: TimeInterval = 0
    private var outsideDuration: TimeInterval = 0
    private var craftPitch: Double = 0.5
    private var manualPitch: Double?
    private var awaitingVoice = true

    init(
        melody: Melody,
        calibration: VoiceCalibration? = nil,
        inputMode: InputMode = AppSettings.inputMode,
        ghost: PerformanceEnvelope? = nil
    ) {
        self.melody = melody
        self.terrain = TerrainBuilder.build(melody)
        self.calibration = calibration ?? VoiceCalibrationStore.load() ?? .fallbackHum
        self.inputMode = inputMode
        self.ghost = ghost
        self.envelope = .empty(melodyId: melody.id, inputMode: inputMode)
        tracker.mode = inputMode
        let opening = terrain.sample(at: 0)
        sungNormalized = opening.center
        targetNormalized = opening.center
        craftPitch = opening.center
    }

    var progress: Double {
        guard terrain.duration > 0 else { return 0 }
        return min(1, songTime / terrain.duration)
    }

    func attachScene(_ scene: FlightScene) {
        self.scene = scene
        scene.configure(controller: self)
        scene.rebuild(melody: melody, terrain: terrain)
    }

    func makeScene(size: CGSize) -> FlightScene {
        let scene = FlightScene(size: size)
        scene.scaleMode = .resizeFill
        attachScene(scene)
        return scene
    }

    func startMicrophone() {
        do {
            try tracker.start()
            tracker.onReading = { [weak self] reading in
                self?.livePitch = reading
            }
        } catch {
            statusMessage = "Microphone unavailable. On Simulator, drag vertically to fly."
        }
    }

    func stopMicrophone() {
        tracker.onReading = nil
        tracker.stop()
    }

    func beginCalibration() {
        flightState = .calibrating
        statusMessage = "Find a comfortable low, then a high."
    }

    func arm() {
        resetRun(keepGhost: true)
        flightState = .armed
        statusMessage = "Hum the opening note — then stay in the corridor."
        awaitingVoice = true
    }

    func resetRun(keepGhost: Bool) {
        songTime = 0
        quietDuration = 0
        outsideDuration = 0
        awaitingVoice = true
        envelope = .empty(melodyId: melody.id, inputMode: inputMode)
        if !keepGhost { ghost = nil }
        let opening = terrain.sample(at: 0)
        craftPitch = opening.center
        sungNormalized = opening.center
        targetNormalized = opening.center
        flightState = .idle
        statusMessage = "Hum to stay inside the song."
        scene?.resetPlayhead()
    }

    func setManualPitch(_ value: Double?) {
        manualPitch = value.map { min(1, max(0, $0)) }
    }

    func tick(dt: TimeInterval) {
        guard dt > 0, dt < 0.25 else { return }
        guard flightState == .armed || flightState == .flying else { return }

        let corridor = terrain.sample(at: songTime)
        targetNormalized = corridor.center

        let voiced: Bool
        let mapped: Double
        if livePitch.voiced, let hz = livePitch.hz {
            mapped = calibration.normalizedPitch(hz: hz)
            voiced = true
        } else if let manualPitch {
            mapped = manualPitch
            voiced = true
        } else {
            mapped = craftPitch
            voiced = false
        }

        if flightState == .armed || awaitingVoice {
            if voiced {
                flightState = .flying
                awaitingVoice = false
                statusMessage = "Stay inside the melody."
            } else {
                scene?.updatePlayhead(
                    time: 0,
                    craftPitch: craftPitch,
                    ghostPitch: ghost?.pitch(at: 0)?.pitch,
                    targetPitch: corridor.center
                )
                return
            }
        }

        songTime += dt
        craftPitch = FlightRules.ease(current: craftPitch, target: mapped, dt: dt)
        sungNormalized = craftPitch

        if voiced {
            quietDuration = 0
        } else {
            quietDuration += dt
        }

        if abs(craftPitch - corridor.center) > corridor.halfWidth {
            outsideDuration += dt
        } else {
            outsideDuration = 0
        }

        envelope.append(time: songTime, pitch: craftPitch, voiced: voiced)

        if FlightRules.shouldStall(quietDuration: quietDuration, elapsed: songTime) {
            finish(.stalled, message: "You went silent. The craft stalled.")
            return
        }
        if FlightRules.shouldCrash(
            sung: craftPitch,
            center: corridor.center,
            halfWidth: corridor.halfWidth,
            outsideDuration: outsideDuration
        ) {
            finish(.crashed, message: "You left the song.")
            return
        }
        if songTime >= terrain.duration {
            finish(.cleared, message: "You flew the phrase.")
            ghost = envelope
            return
        }

        scene?.updatePlayhead(
            time: songTime,
            craftPitch: craftPitch,
            ghostPitch: ghost?.pitch(at: songTime)?.pitch,
            targetPitch: corridor.center
        )
    }

    private func finish(_ state: FlightState, message: String) {
        flightState = state
        statusMessage = message
        envelope.duration = songTime
        if state == .cleared {
            ghost = envelope
        }
        scene?.updatePlayhead(
            time: songTime,
            craftPitch: craftPitch,
            ghostPitch: ghost?.pitch(at: songTime)?.pitch,
            targetPitch: terrain.sample(at: songTime).center
        )
        FeedbackManager.shared.play(state == .cleared ? .success : .fail)
    }
}
