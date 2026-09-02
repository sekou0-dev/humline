import Foundation

struct PitchReading: Equatable, Sendable {
    var hz: Double?
    var midi: Double?
    var rms: Double
    var confidence: Double
    var voiced: Bool
    var timestamp: TimeInterval

    static let silent = PitchReading(
        hz: nil,
        midi: nil,
        rms: 0,
        confidence: 0,
        voiced: false,
        timestamp: 0
    )
}
