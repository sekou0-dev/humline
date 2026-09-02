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
        case .hum: 80...420
        case .whistle: 700...2800
        }
    }

    /// RMS floor. Throat-hum is quieter than a sung note.
    var energyFloor: Double {
        switch self {
        case .hum: 0.004
        case .whistle: 0.003
        }
    }

    var unvoicedFloor: Double {
        energyFloor * 0.55
    }
}
