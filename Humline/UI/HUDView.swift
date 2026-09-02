import SwiftUI

struct HUDView: View {
    @ObservedObject var controller: FlightController
    var onMenu: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Menu") {
                    FeedbackManager.shared.play(.buttonTap)
                    onMenu()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(controller.melody.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Picker("Input", selection: $controller.inputMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            HStack(alignment: .center, spacing: 16) {
                PitchNeedle(
                    sung: controller.sungNormalized,
                    target: controller.targetNormalized,
                    halfWidth: controller.melody.corridorHalfWidth
                )
                .frame(width: 160, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.statusMessage)
                        .font(.caption)
                    if controller.showDebugHUD || controller.livePitch.hz != nil {
                        Text(debugLine)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .foregroundStyle(HumlineTheme.ink)
    }

    private var debugLine: String {
        let hz = controller.livePitch.hz.map { String(format: "%.1f Hz", $0) } ?? "—"
        let midi = controller.livePitch.midi.map { String(format: "MIDI %.1f", $0) } ?? ""
        return "\(hz)  \(midi)  RMS \(String(format: "%.3f", controller.livePitch.rms))"
    }
}

struct PitchNeedle: View {
    var sung: Double
    var target: Double
    var halfWidth: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let corridorMin = max(0, target - halfWidth)
            let corridorMax = min(1, target + halfWidth)
            ZStack(alignment: .leading) {
                Capsule().fill(HumlineTheme.land)
                Capsule()
                    .fill(HumlineTheme.corridor.opacity(0.35))
                    .frame(width: max(8, (corridorMax - corridorMin) * width))
                    .offset(x: corridorMin * width)
                Circle()
                    .fill(HumlineTheme.craft)
                    .frame(width: height - 6, height: height - 6)
                    .offset(x: min(width - height + 6, max(0, sung * width - (height - 6) / 2)))
            }
        }
    }
}
