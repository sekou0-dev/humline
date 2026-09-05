import Foundation

enum InputMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case hum
    case whistle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hum: "Throat hum"
        case .whistle: "Whistle"
        }
    }

    var detail: String {
        switch self {
        case .hum: "Quiet hum. Works on the Tube."
        case .whistle: "Higher band. Still keep it soft."
        }
    }

    /// Search window for Yin, in Hz.
    var frequencyRange: ClosedRange<Double> {
        switch self {
        case .hum: 70...620
        case .whistle: 700...2800
        }
    }

    /// RMS floor. Throat-hum is quieter than a sung note.
    var energyFloor: Double {
        switch self {
        case .hum: 0.0025
        case .whistle: 0.002
        }
    }

    var unvoicedFloor: Double {
        energyFloor * 0.5
    }

    /// YIN CMND cutoff. Throat-hum is noisier than a whistle, so allow a slightly weaker period.
    var yinThreshold: Float {
        switch self {
        case .hum: 0.18
        case .whistle: 0.15
        }
    }
}
