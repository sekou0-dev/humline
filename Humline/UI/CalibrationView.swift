import SwiftUI

struct CalibrationView: View {
    @ObservedObject var tracker: PitchTracker
    var mode: InputMode
    var onComplete: (VoiceCalibration) -> Void

    @State private var step: Step = .low
    @State private var captured: [Double] = []
    @State private var lowHz: Double?
    @State private var elapsed: TimeInterval = 0

    private let captureLength: TimeInterval = 1.4

    enum Step {
        case low, high

        var title: String {
            switch self {
            case .low: "Find your range"
            case .high: "Now the high note"
            }
        }

        var message: String {
            switch self {
            case .low:
                "Hum a comfortable low note and hold it. Humline listens for about a second, then asks for a high note. This maps your voice onto the height of the land."
            case .high:
                "Now hum a comfortable high note and hold it. After this, the bottom of the corridor is your low, and the top is your high."
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                InstructionText(text: step.message)

                if let hz = tracker.latest.hz {
                    Text(String(format: "%.0f Hz", hz))
                        .font(.system(.title, design: .monospaced).weight(.medium))
                        .foregroundStyle(HumlineTheme.corridor)
                } else {
                    Text("Listening for a steady tone…")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ProgressView(value: min(1, elapsed / captureLength))
                    .tint(HumlineTheme.corridor)

                InstructionText(text: mode.detail, font: .caption)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HumlineTheme.sky.opacity(0.72).ignoresSafeArea())
        .onAppear {
            tracker.mode = mode
            captured = []
            elapsed = 0
        }
        .onReceive(tracker.$latest) { reading in
            capture(reading)
        }
    }

    private func capture(_ reading: PitchReading) {
        if reading.voiced, let hz = reading.hz {
            captured.append(hz)
            elapsed += 1.0 / 30.0
        }
        guard elapsed >= captureLength, !captured.isEmpty else { return }
        let median = Self.median(captured)
        captured = []
        elapsed = 0
        switch step {
        case .low:
            lowHz = median
            step = .high
        case .high:
            let low = lowHz ?? median / 1.6
            var calibration = VoiceCalibration(lowHz: min(low, median), highHz: max(low, median))
            if !calibration.isValid {
                calibration.highHz = calibration.lowHz * 1.8
            }
            onComplete(calibration)
        }
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
