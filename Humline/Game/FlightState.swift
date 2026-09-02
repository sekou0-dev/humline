import Foundation

enum FlightState: Equatable, Sendable {
    case idle
    case calibrating
    case armed
    case flying
    case stalled
    case crashed
    case cleared

    var isTerminal: Bool {
        switch self {
        case .stalled, .crashed, .cleared: true
        default: false
        }
    }

    var allowsFlight: Bool {
        self == .flying
    }
}

enum FlightRules {
    static let stallSilence: TimeInterval = 0.18
    static let startGrace: TimeInterval = 0.45
    static let crashGrace: TimeInterval = 0.08
    static let craftFollowRate: Double = 10
    static let pixelsPerBeat: CGFloat = 160
    static let craftXFraction: CGFloat = 0.22
    static let craftRadius: CGFloat = 11

    static func shouldStall(quietDuration: TimeInterval, elapsed: TimeInterval) -> Bool {
        elapsed >= startGrace && quietDuration >= stallSilence
    }

    static func shouldCrash(sung: Double, center: Double, halfWidth: Double, outsideDuration: TimeInterval) -> Bool {
        abs(sung - center) > halfWidth && outsideDuration >= crashGrace
    }

    static func ease(current: Double, target: Double, dt: TimeInterval) -> Double {
        let follow = 1 - exp(-craftFollowRate * dt)
        return current + (target - current) * follow
    }
}
