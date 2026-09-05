import Foundation

/// One-euro filter in log-frequency space so octave jumps are scaled fairly.
final class PitchSmoother: @unchecked Sendable {
    private var minCutoff: Double
    private var beta: Double
    private var dCutoff: Double
    private var xHat: Double?
    private var dxHat: Double = 0
    private var lastTime: Double?

    init(minCutoff: Double = 2.8, beta: Double = 0.04, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    func reset() {
        xHat = nil
        dxHat = 0
        lastTime = nil
    }

    func filter(hz: Double, timestamp: Double) -> Double {
        let value = log2(max(hz, 20))
        defer { lastTime = timestamp }
        guard let previous = xHat, let lastTime else {
            xHat = value
            return hz
        }
        let dt = max(timestamp - lastTime, 1e-4)
        if abs(value - previous) >= 3.0 / 12.0 {
            xHat = value
            dxHat = 0
            return hz
        }
        let dx = (value - previous) / dt
        dxHat = lowpass(current: dx, previous: dxHat, cutoff: dCutoff, dt: dt)
        let cutoff = minCutoff + beta * abs(dxHat)
        let filtered = lowpass(current: value, previous: previous, cutoff: cutoff, dt: dt)
        xHat = filtered
        return pow(2, filtered)
    }

    private func lowpass(current: Double, previous: Double, cutoff: Double, dt: Double) -> Double {
        let tau = 1.0 / (2 * .pi * cutoff)
        let alpha = 1.0 / (1.0 + tau / dt)
        return previous + alpha * (current - previous)
    }
}
