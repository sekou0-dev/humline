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
    @Published private(set) var statusMessage = "Hum to stay inside the gold ribbon. Match the written pitch as the land rises and falls."
    @Published var inputMode: InputMode {
        didSet {
            tracker.mode = inputMode
            AppSettings.inputMode = inputMode
            if oldValue != inputMode {
                HumlineAnalytics.signal("Input.modeChanged", parameters: [
                    "inputMode": inputMode.rawValue,
                    "previous": oldValue.rawValue,
                ])
            }
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
                self?.ingest(reading)
            }
        } catch {
            statusMessage = "Microphone is unavailable. On Simulator, drag up and down on the screen to set pitch."
        }
    }

    func stopMicrophone() {
        tracker.onReading = nil
        tracker.stop()
    }

    func beginCalibration() {
        flightState = .calibrating
        statusMessage = "Hum a comfortable low note, then a high note, so the land matches your range."
    }

    func arm() {
        resetRun(keepGhost: true)
        flightState = .armed
        statusMessage = "Hum the opening pitch, then stay inside the gold ribbon. Silence stalls. Leaving the ribbon crashes."
        awaitingVoice = true
        HumlineAnalytics.signal("Phrase.started", parameters: phraseParameters(shared: ghost != nil))
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
        statusMessage = "Hum to stay inside the gold ribbon. Match the written pitch as the land rises and falls."
        scene?.resetPlayhead()
    }

    func setManualPitch(_ value: Double?) {
        manualPitch = value.map { min(1, max(0, $0)) }
    }

    func ingest(_ reading: PitchReading) {
        livePitch = reading
    }

    func tick(dt: TimeInterval) {
        guard dt > 0, dt < 0.25 else { return }
        guard flightState == .armed || flightState == .flying else { return }

        let corridor = terrain.sample(at: songTime)
        targetNormalized = corridor.center

        let mapped: Double
        let hasTone: Bool
        let pitched: Bool
        if livePitch.voiced, let hz = livePitch.hz {
            mapped = calibration.normalizedPitch(hz: hz)
            hasTone = true
            pitched = true
        } else if let manualPitch {
            mapped = manualPitch
            hasTone = true
            pitched = true
        } else if livePitch.rms >= inputMode.unvoicedFloor {
            mapped = craftPitch
            hasTone = true
            pitched = false
        } else {
            mapped = craftPitch
            hasTone = false
            pitched = false
        }

        if flightState == .armed || awaitingVoice {
            if hasTone {
                flightState = .flying
                awaitingVoice = false
                statusMessage = "Stay inside the gold ribbon. Match the written pitch as the land rises and falls."
                HumlineAnalytics.signal("Flight.started", parameters: phraseParameters(shared: ghost != nil))
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

        if hasTone {
            quietDuration = 0
        } else {
            quietDuration += dt
        }

        if abs(craftPitch - corridor.center) > corridor.halfWidth {
            outsideDuration += dt
        } else {
            outsideDuration = 0
        }

        envelope.append(time: songTime, pitch: craftPitch, voiced: pitched)

        if FlightRules.shouldStall(quietDuration: quietDuration, elapsed: songTime) {
            finish(.stalled, message: "You went silent. The craft stalled — keep a tone going, even a quiet one.")
            return
        }
        if FlightRules.shouldCrash(
            sung: craftPitch,
            center: corridor.center,
            halfWidth: corridor.halfWidth,
            outsideDuration: outsideDuration
        ) {
            finish(.crashed, message: "You left the gold ribbon. The land is the melody — match the written pitch.")
            return
        }
        if songTime >= terrain.duration {
            finish(.cleared, message: "You flew the phrase. Share this run so someone else can race your ghost.")
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
        let signalName: String
        switch state {
        case .stalled: signalName = "Flight.stalled"
        case .crashed: signalName = "Flight.crashed"
        case .cleared: signalName = "Flight.cleared"
        default: return
        }
        HumlineAnalytics.signal(signalName, parameters: runParameters())
    }

    private func phraseParameters(shared: Bool) -> [String: String] {
        [
            "melodyId": melody.id,
            "title": melody.title,
            "inputMode": inputMode.rawValue,
            "shared": shared ? "true" : "false",
        ]
    }

    private func runParameters() -> [String: String] {
        var parameters = phraseParameters(shared: ghost != nil)
        parameters["duration"] = String(format: "%.2f", songTime)
        parameters["progress"] = String(format: "%.2f", progress)
        return parameters
    }
}
