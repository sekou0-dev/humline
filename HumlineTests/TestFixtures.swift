import Foundation
@testable import Humline

enum TestFixtures {
    static let drone = Melody(
        id: "test-drone",
        title: "Drone",
        detail: "A held note used by unit tests.",
        tempo: 120,
        corridorHalfWidth: 0.35,
        isFree: true,
        notes: [.init(midi: 60, beats: 2)]
    )

    static let cliff = Melody(
        id: "test-cliff",
        title: "Cliff",
        detail: "A fifth leap used by unit tests.",
        tempo: 60,
        corridorHalfWidth: 0.1,
        isFree: true,
        notes: [
            .init(midi: 60, beats: 1),
            .init(midi: 67, beats: 1),
        ]
    )

    static let paidPhrase = Melody(
        id: "test-paid",
        title: "Paid Phrase",
        detail: "Locked until the phrase pack is owned.",
        tempo: 80,
        corridorHalfWidth: 0.12,
        isFree: false,
        notes: [.init(midi: 64, beats: 4)]
    )

    static func sine(hz: Double, sampleRate: Double = 44_100, count: Int = 4096, amplitude: Float = 0.6) -> [Float] {
        (0..<count).map { index in
            Float(sin(2 * Double.pi * hz * Double(index) / sampleRate) * Double(amplitude))
        }
    }
}

final class AnalyticsLog {
    var events: [(name: String, parameters: [String: String])] = []

    func names() -> [String] {
        events.map(\.name)
    }
}

enum TestSupport {
    static let settingKeys = [
        "hasCompletedOnboarding",
        "inputMode",
        "debugUnlockAll",
        "hapticsEnabled",
        "voiceCalibration",
    ]

    private static let settingsLock = NSLock()

    @MainActor
    static func withAnalyticsLog(_ body: (AnalyticsLog) throws -> Void) rethrows {
        let log = AnalyticsLog()
        let previous = HumlineAnalytics.recorder
        HumlineAnalytics.recorder = { name, parameters in
            log.events.append((name, parameters))
        }
        defer { HumlineAnalytics.recorder = previous }
        try body(log)
    }

    static func withRestoredSettings(_ body: () throws -> Void) rethrows {
        settingsLock.lock()
        defer { settingsLock.unlock() }
        let defaults = AppSettings.store
        let snapshot: [String: Any] = settingKeys.reduce(into: [:]) { dict, key in
            if let value = defaults.object(forKey: key) {
                dict[key] = value
            }
        }
        defer {
            for key in settingKeys {
                if let value = snapshot[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try body()
    }
}
