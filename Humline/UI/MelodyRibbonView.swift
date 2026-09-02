import SwiftUI

struct MelodyRibbonView: View {
    var melody: Melody

    var body: some View {
        let terrain = TerrainBuilder.build(melody)
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(HumlineTheme.land))

            var ribbon = Path()
            var midline = Path()
            let samples = stride(from: 0.0, through: terrain.duration, by: max(terrain.duration / 80, 0.02)).map {
                terrain.sample(at: $0)
            }
            guard let first = samples.first, terrain.duration > 0 else { return }

            func point(time: TimeInterval, pitch: Double) -> CGPoint {
                CGPoint(
                    x: CGFloat(time / terrain.duration) * size.width,
                    y: size.height - CGFloat(pitch) * size.height
                )
            }

            ribbon.move(to: point(time: first.time, pitch: first.center - first.halfWidth))
            for sample in samples {
                ribbon.addLine(to: point(time: sample.time, pitch: sample.center - sample.halfWidth))
            }
            for sample in samples.reversed() {
                ribbon.addLine(to: point(time: sample.time, pitch: sample.center + sample.halfWidth))
            }
            ribbon.closeSubpath()
            context.fill(ribbon, with: .color(HumlineTheme.corridor.opacity(0.35)))

            midline.move(to: point(time: first.time, pitch: first.center))
            for sample in samples.dropFirst() {
                midline.addLine(to: point(time: sample.time, pitch: sample.center))
            }
            context.stroke(midline, with: .color(HumlineTheme.corridor), lineWidth: 2)
        }
        .background(HumlineTheme.land)
    }
}
