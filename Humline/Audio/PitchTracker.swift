import AVFoundation
import Combine
import Foundation

/// Live F0 from the microphone. Analysis itself is pure (`analyze`) so tests can feed sines.
@MainActor
final class PitchTracker: ObservableObject {
    @Published private(set) var latest: PitchReading = .silent

    var onReading: ((PitchReading) -> Void)?

    private let engine = AVAudioEngine()
    private let analyzer = PitchAnalyzer()
    private var isRunning = false
    private var interruptionObserver: NSObjectProtocol?

    var mode: InputMode {
        get { analyzer.mode }
        set { analyzer.mode = newValue }
    }

    func start() throws {
        guard !isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw PitchTrackerError.noInput
        }

        input.removeTap(onBus: 0)
        analyzer.reset()
        let analyzer = self.analyzer
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, time in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channel, count: frames))
            let reading = analyzer.process(
                samples: samples,
                sampleRate: buffer.format.sampleRate,
                hostTime: time.hostTime
            )
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latest = reading
                self.onReading?(reading)
            }
        }

        try engine.start()
        isRunning = true

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(rawType: rawType)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        latest = .silent
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Testable entry: Yin + RMS + energy gate + smoothing, no microphone.
    nonisolated static func analyze(
        samples: [Float],
        sampleRate: Double,
        mode: InputMode,
        smoother: PitchSmoother? = nil,
        timestamp: TimeInterval = 0
    ) -> PitchReading {
        let rms = YinDetector.rms(samples: samples)
        let range = mode.frequencyRange
        guard rms >= mode.unvoicedFloor else {
            smoother?.reset()
            return PitchReading(hz: nil, midi: nil, rms: rms, confidence: 0, voiced: false, timestamp: timestamp)
        }

        guard let detected = YinDetector.pitch(
            samples: samples,
            sampleRate: sampleRate,
            minFrequency: range.lowerBound,
            maxFrequency: range.upperBound,
            threshold: mode.yinThreshold
        ) else {
            return PitchReading(hz: nil, midi: nil, rms: rms, confidence: 0, voiced: false, timestamp: timestamp)
        }

        let hz: Double
        if let smoother {
            hz = smoother.filter(hz: detected.hz, timestamp: timestamp)
        } else {
            hz = detected.hz
        }

        let inBand = range.contains(detected.hz) || range.contains(hz)
        let voiced = rms >= mode.energyFloor && detected.confidence >= 0.4 && inBand
        return PitchReading(
            hz: hz,
            midi: YinDetector.midi(fromHz: hz),
            rms: rms,
            confidence: detected.confidence,
            voiced: voiced,
            timestamp: timestamp
        )
    }

    private func handleInterruption(rawType: UInt?) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        if type == .ended {
            try? engine.start()
        }
    }
}

enum PitchTrackerError: Error {
    case noInput
}

final class PitchAnalyzer: @unchecked Sendable {
    private let lock = NSLock()
    private var _mode: InputMode = .hum
    private let smoother = PitchSmoother()
    private var held: PitchReading?
    private static let holdDuration: TimeInterval = 0.28

    var mode: InputMode {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mode
        }
        set {
            lock.lock()
            _mode = newValue
            smoother.reset()
            held = nil
            lock.unlock()
        }
    }

    func reset() {
        lock.lock()
        smoother.reset()
        held = nil
        lock.unlock()
    }

    func process(samples: [Float], sampleRate: Double, hostTime: UInt64) -> PitchReading {
        process(samples: samples, sampleRate: sampleRate, timestamp: seconds(fromHostTime: hostTime))
    }

    func process(samples: [Float], sampleRate: Double, timestamp: TimeInterval) -> PitchReading {
        lock.lock()
        defer { lock.unlock() }
        let mode = _mode
        let reading = PitchTracker.analyze(
            samples: samples,
            sampleRate: sampleRate,
            mode: mode,
            smoother: smoother,
            timestamp: timestamp
        )
        return continuePitchLocked(reading, mode: mode)
    }

    /// Hold the last note through a brief Yin dropout, but never overwrite a newly detected Hz.
    func continuePitch(_ reading: PitchReading, mode: InputMode? = nil) -> PitchReading {
        lock.lock()
        defer { lock.unlock() }
        return continuePitchLocked(reading, mode: mode ?? _mode)
    }

    private func continuePitchLocked(_ reading: PitchReading, mode: InputMode) -> PitchReading {
        var reading = reading
        let previousHz = held?.hz

        if let newHz = reading.hz, reading.rms >= mode.unvoicedFloor {
            if let previousHz, newHz > 20 {
                let ratio = previousHz / newHz
                if ratio > 1.85, ratio < 2.25, mode.frequencyRange.contains(newHz * 2) {
                    let doubled = newHz * 2
                    reading = PitchReading(
                        hz: doubled,
                        midi: YinDetector.midi(fromHz: doubled),
                        rms: reading.rms,
                        confidence: max(reading.confidence, 0.4),
                        voiced: true,
                        timestamp: reading.timestamp
                    )
                }
            }
            held = reading
            return reading
        }

        if reading.hz == nil,
           reading.rms >= mode.unvoicedFloor,
           let held,
           reading.timestamp - held.timestamp <= Self.holdDuration {
            return PitchReading(
                hz: held.hz,
                midi: held.midi,
                rms: reading.rms,
                confidence: held.confidence,
                voiced: true,
                timestamp: reading.timestamp
            )
        }

        if reading.rms < mode.unvoicedFloor {
            self.held = nil
        }
        return reading
    }

    private func seconds(fromHostTime hostTime: UInt64) -> TimeInterval {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let nanos = Double(hostTime) * Double(info.numer) / Double(info.denom)
        return nanos / 1_000_000_000
    }
}
