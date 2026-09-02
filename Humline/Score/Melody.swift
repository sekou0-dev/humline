import Foundation

struct Melody: Codable, Identifiable, Equatable, Sendable, Hashable {
    var id: String
    var title: String
    var detail: String
    var tempo: Double
    var corridorHalfWidth: Double
    var isFree: Bool
    var notes: [Note]

    struct Note: Codable, Equatable, Sendable, Hashable {
        var midi: Double
        var beats: Double
    }

    var totalBeats: Double {
        notes.reduce(0) { $0 + $1.beats }
    }

    var duration: TimeInterval {
        guard tempo > 0 else { return 0 }
        return totalBeats * 60.0 / tempo
    }

    var minMidi: Double {
        notes.map(\.midi).min() ?? 60
    }

    var maxMidi: Double {
        notes.map(\.midi).max() ?? 72
    }

    var pitchSpan: (min: Double, max: Double) {
        let minValue = minMidi
        let maxValue = maxMidi
        if maxValue - minValue < 2 {
            return (minValue - 1, maxValue + 1)
        }
        return (minValue, maxValue)
    }
}

struct MelodyCatalog: Codable, Equatable, Sendable {
    var phrases: [Melody]
}

enum MelodyLibrary {
    static func loadBundled() -> [Melody] {
        if let url = Bundle.main.url(forResource: "melodies", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let catalog = try? JSONDecoder().decode(MelodyCatalog.self, from: data) {
            return catalog.phrases
        }
        return fallbackPhrases
    }

    static func phrase(id: String, in phrases: [Melody]? = nil) -> Melody? {
        (phrases ?? loadBundled()).first { $0.id == id }
    }

    static let fallbackPhrases: [Melody] = [
        Melody(
            id: "first-phrase",
            title: "First Phrase",
            detail: "A hill that rises and falls. Stay inside it.",
            tempo: 72,
            corridorHalfWidth: 0.18,
            isFree: true,
            notes: [
                .init(midi: 60, beats: 2),
                .init(midi: 62, beats: 2),
                .init(midi: 64, beats: 2),
                .init(midi: 62, beats: 2),
                .init(midi: 60, beats: 2),
            ]
        ),
    ]
}
