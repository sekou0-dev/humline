import Foundation

struct CorridorSample: Equatable, Sendable {
    var time: TimeInterval
    var center: Double
    var halfWidth: Double
}

struct TerrainGeometry: Equatable, Sendable {
    var samples: [CorridorSample]
    var duration: TimeInterval
    var halfWidth: Double

    func sample(at time: TimeInterval) -> CorridorSample {
        guard !samples.isEmpty else {
            return CorridorSample(time: time, center: 0.5, halfWidth: halfWidth)
        }
        if time <= samples[0].time { return samples[0] }
        if time >= samples[samples.count - 1].time { return samples[samples.count - 1] }

        var low = 0
        var high = samples.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if samples[mid].time <= time {
                low = mid
            } else {
                high = mid
            }
        }
        let a = samples[low]
        let b = samples[high]
        let span = b.time - a.time
        let t = span > 0 ? (time - a.time) / span : 0
        return CorridorSample(
            time: time,
            center: a.center + (b.center - a.center) * t,
            halfWidth: a.halfWidth + (b.halfWidth - a.halfWidth) * t
        )
    }

    func centerLine() -> [CorridorSample] { samples }
}

enum TerrainBuilder {
    /// Convert a melody into a time-parameterized pitch corridor.
    /// Leaps become short cliffs (~50 ms) so the land is the score.
    static func build(_ melody: Melody, cliffSeconds: TimeInterval = 0.05) -> TerrainGeometry {
        let span = melody.pitchSpan
        let secondsPerBeat = 60.0 / max(melody.tempo, 1)
        var samples: [CorridorSample] = []
        var time: TimeInterval = 0
        var lastCenter: Double?

        for note in melody.notes {
            let center = VoiceCalibration.midiNormalized(note.midi, minMidi: span.min, maxMidi: span.max)
            let noteEnd = time + note.beats * secondsPerBeat

            if let lastCenter, abs(center - lastCenter) > 0.0001 {
                let cliffEnd = min(time + cliffSeconds, noteEnd)
                samples.append(CorridorSample(time: time, center: lastCenter, halfWidth: melody.corridorHalfWidth))
                samples.append(CorridorSample(time: cliffEnd, center: center, halfWidth: melody.corridorHalfWidth))
            } else {
                samples.append(CorridorSample(time: time, center: center, halfWidth: melody.corridorHalfWidth))
            }

            samples.append(CorridorSample(time: noteEnd, center: center, halfWidth: melody.corridorHalfWidth))
            time = noteEnd
            lastCenter = center
        }

        return TerrainGeometry(samples: samples, duration: time, halfWidth: melody.corridorHalfWidth)
    }
}
