import SwiftUI

struct CalibrationView: View {
    @ObservedObject var tracker: PitchTracker
    var mode: InputMode
    var onComplete: (VoiceCalibration) -> Void

    @State private var step: Step = .low
    @State private var captured: [Double] = []
    @State private var lowHz: Double?
    @State private var message = "Hum a comfortable low note."
    @State private var elapsed: TimeInterval = 0

    private let captureLength: TimeInterval = 1.4

    enum Step {
        case low, high
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Find your range")
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let hz = tracker.latest.hz {
                Text(String(format: "%.0f Hz", hz))
                    .font(.system(.title, design: .monospaced).weight(.medium))
                    .foregroundStyle(HumlineTheme.corridor)
            } else {
                Text("Listening…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(1, elapsed / captureLength))
                .tint(HumlineTheme.corridor)
                .padding(.horizontal, 40)

            Text(mode.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            message = "Now a comfortable high note."
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
