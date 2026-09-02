import SwiftUI

struct PitchGymView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tracker = PitchTracker()
    @State private var mode: InputMode = AppSettings.inputMode

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Input", selection: $mode) {
                    ForEach(InputMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, newValue in
                    tracker.mode = newValue
                    AppSettings.inputMode = newValue
                }

                VStack(spacing: 8) {
                    Text(hzText)
                        .font(.system(size: 44, weight: .medium, design: .monospaced))
                    Text(midiText)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(String(format: "RMS %.3f   conf %.2f", tracker.latest.rms, tracker.latest.confidence))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                PitchNeedle(
                    sung: sungNormalized,
                    target: 0.5,
                    halfWidth: 0.12
                )
                .frame(height: 40)
                .padding(.horizontal, 24)

                Text(mode.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("This gym proves the tracker before a flight. Hum and whistle should lock to a stable Hz.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Spacer()
            }
            .padding()
            .background(HumlineTheme.sky.ignoresSafeArea())
            .foregroundStyle(HumlineTheme.ink)
            .navigationTitle("Pitch gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                tracker.mode = mode
                try? tracker.start()
            }
            .onDisappear {
                tracker.stop()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var hzText: String {
        if let hz = tracker.latest.hz {
            return String(format: "%.1f Hz", hz)
        }
        return "—"
    }

    private var midiText: String {
        if let midi = tracker.latest.midi {
            return String(format: "MIDI %.1f", midi)
        }
        return tracker.latest.voiced ? "voiced" : "silence"
    }

    private var sungNormalized: Double {
        guard let hz = tracker.latest.hz else { return 0 }
        let calibration = VoiceCalibrationStore.load() ?? .fallbackHum
        return calibration.normalizedPitch(hz: hz)
    }
}
