import SwiftUI

struct HUDView: View {
    @ObservedObject var controller: FlightController
    var onMenu: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button("Menu") {
                    FeedbackManager.shared.play(.buttonTap)
                    onMenu()
                }
                .buttonStyle(.bordered)

                Text(controller.melody.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Input", selection: $controller.inputMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            PitchNeedle(
                sung: controller.sungNormalized,
                target: controller.targetNormalized,
                halfWidth: controller.melody.corridorHalfWidth
            )
            .frame(height: 28)

            InstructionText(
                text: controller.statusMessage,
                font: .subheadline,
                color: HumlineTheme.ink.opacity(0.9),
                alignment: .leading
            )

            if controller.showDebugHUD || controller.livePitch.hz != nil {
                Text(debugLine)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HumlineTheme.sky.opacity(0.82))
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
                    .frame(width: height - 4, height: height - 4)
                    .offset(x: min(width - height + 4, max(0, sung * width - (height - 4) / 2)))
            }
        }
    }
}
