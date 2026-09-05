import Foundation
import Testing
@testable import Humline

struct MelodyCatalogTests {
    @Test func bundledPhrasesAreWellFormed() {
        let phrases = MelodyLibrary.loadBundled()
        #expect(phrases.count == 12)

        let ids = phrases.map(\.id)
        #expect(Set(ids).count == ids.count)

        for phrase in phrases {
            #expect(!phrase.title.isEmpty)
            #expect(!phrase.detail.isEmpty)
            #expect(phrase.tempo > 0)
            #expect(phrase.corridorHalfWidth > 0)
            #expect(!phrase.notes.isEmpty)
            #expect(phrase.totalBeats > 0)
            #expect(phrase.duration > 0)
            #expect(phrase.minMidi <= phrase.maxMidi)
            #expect(phrase.pitchSpan.min < phrase.pitchSpan.max)
        }

        #expect(phrases.filter(\.isFree).map(\.id) == [
            "first-phrase",
            "held-valley",
            "stepwise-hill",
            "small-leap",
        ])
    }

    @Test func lookupById() {
        let phrases = MelodyLibrary.loadBundled()
        #expect(MelodyLibrary.phrase(id: "fifth-cliff", in: phrases)?.title == "Fifth Cliff")
        #expect(MelodyLibrary.phrase(id: "missing", in: phrases) == nil)
        #expect(MelodyLibrary.phrase(id: "first-phrase")?.id == "first-phrase")
    }

    @Test func durationUsesTempo() {
        let slow = Melody(
            id: "slow",
            title: "Slow",
            detail: "",
            tempo: 60,
            corridorHalfWidth: 0.1,
            isFree: true,
            notes: [.init(midi: 60, beats: 3)]
        )
        #expect(abs(slow.duration - 3) < 0.0001)
        #expect(Melody(id: "zero", title: "", detail: "", tempo: 0, corridorHalfWidth: 0.1, isFree: true, notes: [.init(midi: 60, beats: 1)]).duration == 0)
    }

    @Test func narrowSpanIsExpanded() {
        let span = TestFixtures.drone.pitchSpan
        #expect(span.max - span.min >= 2)
    }

    @Test func jsonRoundTrip() throws {
        let catalog = MelodyCatalog(phrases: [TestFixtures.drone, TestFixtures.paidPhrase])
        let data = try JSONEncoder().encode(catalog)
        let decoded = try JSONDecoder().decode(MelodyCatalog.self, from: data)
        #expect(decoded == catalog)
    }
}

struct TerrainEdgeTests {
    @Test func emptyMelodyHasZeroDuration() {
        let empty = Melody(id: "empty", title: "", detail: "", tempo: 80, corridorHalfWidth: 0.1, isFree: true, notes: [])
        let terrain = TerrainBuilder.build(empty)
        #expect(terrain.duration == 0)
        #expect(terrain.samples.isEmpty)
        #expect(terrain.sample(at: 1).center == 0.5)
    }

    @Test func samplesClampOutsideThePhrase() {
        let terrain = TerrainBuilder.build(TestFixtures.drone)
        let before = terrain.sample(at: -1)
        let after = terrain.sample(at: terrain.duration + 4)
        #expect(before.center == terrain.samples.first?.center)
        #expect(after.center == terrain.samples.last?.center)
    }

    @Test func interpolatesBetweenSamples() {
        let terrain = TerrainGeometry(
            samples: [
                CorridorSample(time: 0, center: 0, halfWidth: 0.1),
                CorridorSample(time: 2, center: 1, halfWidth: 0.2),
            ],
            duration: 2,
            halfWidth: 0.1
        )
        let mid = terrain.sample(at: 1)
        #expect(abs(mid.center - 0.5) < 0.0001)
        #expect(abs(mid.halfWidth - 0.15) < 0.0001)
        #expect(terrain.centerLine().count == 2)
    }

    @Test func cliffIsShorterThanTheHeldNotes() {
        let terrain = TerrainBuilder.build(TestFixtures.cliff, cliffSeconds: 0.05)
        let justBefore = terrain.sample(at: 0.99)
        let justAfter = terrain.sample(at: 1.06)
        #expect(justBefore.center < 0.2)
        #expect(justAfter.center > 0.8)
    }
}
