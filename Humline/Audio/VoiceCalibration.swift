import Foundation

struct VoiceCalibration: Codable, Equatable, Sendable {
    var lowHz: Double
    var highHz: Double

    static let fallbackHum = VoiceCalibration(lowHz: 110, highHz: 330)

    var isValid: Bool {
        highHz > lowHz * 1.25
    }

    /// Comfortable high reaches the land top without needing the strained ceiling of the calibrated range.
    private static let playableHighFraction = 0.82

    /// Map a sung frequency onto 0...1 using the player's own range (log2).
    func normalizedPitch(hz: Double) -> Double {
        let lo = log2(max(lowHz, 20))
        let hi = log2(max(highHz, lowHz * 1.01))
        let playableHi = lo + (hi - lo) * Self.playableHighFraction
        let value = log2(max(hz, 20))
        return min(1, max(0, (value - lo) / (playableHi - lo)))
    }

    static func midiNormalized(_ midi: Double, minMidi: Double, maxMidi: Double) -> Double {
        if maxMidi <= minMidi { return 0.5 }
        return min(1, max(0, (midi - minMidi) / (maxMidi - minMidi)))
    }
}

enum VoiceCalibrationStore {
    private static let key = "voiceCalibration"

    static func load() -> VoiceCalibration? {
        guard let data = AppSettings.store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(VoiceCalibration.self, from: data)
    }

    static func save(_ calibration: VoiceCalibration) {
        if let data = try? JSONEncoder().encode(calibration) {
            AppSettings.store.set(data, forKey: key)
        }
    }

    static func clear() {
        AppSettings.store.removeObject(forKey: key)
    }
}
