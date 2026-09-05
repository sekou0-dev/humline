import Foundation

enum YinDetector {
    /// Fundamental frequency via the YIN cumulative-mean-normalized difference.
    static func pitch(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double,
        threshold: Float = 0.15
    ) -> (hz: Double, confidence: Double)? {
        let count = samples.count
        guard count >= 64, sampleRate > 0, maxFrequency > minFrequency else { return nil }

        let tauMin = max(2, Int((sampleRate / maxFrequency).rounded(.down)))
        let tauMax = min(count / 2 - 2, Int((sampleRate / minFrequency).rounded(.up)))
        guard tauMax > tauMin + 2 else { return nil }

        var mean: Float = 0
        for sample in samples { mean += sample }
        mean /= Float(count)

        var diff = [Float](repeating: 0, count: tauMax + 1)
        for tau in 1...tauMax {
            var sum: Float = 0
            let limit = count - tau
            for index in 0..<limit {
                let delta = (samples[index] - mean) - (samples[index + tau] - mean)
                sum += delta * delta
            }
            diff[tau] = sum
        }

        var cmnd = [Float](repeating: 1, count: tauMax + 1)
        var running: Float = 0
        for tau in 1...tauMax {
            running += diff[tau]
            if running > 0 {
                cmnd[tau] = diff[tau] * Float(tau) / running
            }
        }

        var tau = tauMin
        var found = false
        while tau < tauMax {
            if cmnd[tau] < threshold {
                while tau + 1 <= tauMax, cmnd[tau + 1] < cmnd[tau] {
                    tau += 1
                }
                found = true
                break
            }
            tau += 1
        }
        guard found, tau < tauMax else { return nil }

        tau = preferHigherOctave(tau: tau, cmnd: cmnd, tauMin: tauMin, threshold: threshold)

        var betterTau = Double(tau)
        if tau > 1, tau < tauMax {
            let s0 = Double(cmnd[tau - 1])
            let s1 = Double(cmnd[tau])
            let s2 = Double(cmnd[tau + 1])
            let denom = 2 * s1 - s2 - s0
            if abs(denom) > 1e-12 {
                betterTau += (s0 - s2) / (2 * denom)
            }
        }

        let hz = sampleRate / betterTau
        guard hz.isFinite, hz >= minFrequency * 0.9, hz <= maxFrequency * 1.1 else { return nil }
        let confidence = max(0, min(1, 1 - Double(cmnd[tau])))
        return (hz, confidence)
    }

    /// If a shorter period is also a YIN minimum, take it so a rising hum is not reported an octave down.
    private static func preferHigherOctave(tau: Int, cmnd: [Float], tauMin: Int, threshold: Float) -> Int {
        var chosen = tau
        var half = tau / 2
        while half >= tauMin {
            let isLocalMin = (half <= 1 || cmnd[half - 1] >= cmnd[half])
                && (half + 1 >= cmnd.count || cmnd[half + 1] >= cmnd[half])
            if isLocalMin, cmnd[half] < threshold * 1.25 {
                chosen = half
                half = chosen / 2
            } else {
                break
            }
        }
        return chosen
    }

    static func rms(samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return Double(sqrt(sum / Float(samples.count)))
    }

    static func midi(fromHz hz: Double) -> Double {
        69 + 12 * log2(hz / 440)
    }

    static func hz(fromMidi midi: Double) -> Double {
        440 * pow(2, (midi - 69) / 12)
    }
}
