import Foundation

struct EnvelopePoint: Codable, Equatable, Sendable {
    var time: TimeInterval
    var pitch: Double
    var voiced: Bool
}

struct PerformanceEnvelope: Codable, Equatable, Sendable {
    var melodyId: String
    var points: [EnvelopePoint]
    var recordedAt: Date
    var inputMode: InputMode
    var duration: TimeInterval

    static func empty(melodyId: String, inputMode: InputMode) -> PerformanceEnvelope {
        PerformanceEnvelope(
            melodyId: melodyId,
            points: [],
            recordedAt: Date(),
            inputMode: inputMode,
            duration: 0
        )
    }

    mutating func append(time: TimeInterval, pitch: Double, voiced: Bool) {
        if let last = points.last, time - last.time < 1.0 / 45 {
            return
        }
        points.append(EnvelopePoint(time: time, pitch: pitch, voiced: voiced))
        duration = time
    }

    func pitch(at time: TimeInterval) -> EnvelopePoint? {
        guard !points.isEmpty else { return nil }
        if time <= points[0].time { return points[0] }
        if time >= points[points.count - 1].time { return points[points.count - 1] }

        var low = 0
        var high = points.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if points[mid].time <= time {
                low = mid
            } else {
                high = mid
            }
        }
        let a = points[low]
        let b = points[high]
        let span = b.time - a.time
        let t = span > 0 ? (time - a.time) / span : 0
        return EnvelopePoint(
            time: time,
            pitch: a.pitch + (b.pitch - a.pitch) * t,
            voiced: a.voiced && b.voiced
        )
    }
}

struct SharedFlight: Codable, Equatable, Sendable {
    var melodyId: String
    var melodyTitle: String
    var envelope: PerformanceEnvelope
}
