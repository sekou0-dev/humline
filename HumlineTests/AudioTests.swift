import Foundation
import Testing
@testable import Humline

struct InputModeTests {
    @Test func casesHaveDistinctRanges() {
        #expect(InputMode.hum.frequencyRange.lowerBound == 70)
        #expect(InputMode.hum.frequencyRange.upperBound == 450)
        #expect(InputMode.whistle.frequencyRange.lowerBound == 700)
        #expect(InputMode.whistle.frequencyRange.upperBound == 2800)
        #expect(InputMode.hum.frequencyRange.upperBound < InputMode.whistle.frequencyRange.lowerBound)
    }

    @Test func titlesAndDetailsAreNonEmpty() {
        for mode in InputMode.allCases {
            #expect(!mode.id.isEmpty)
            #expect(!mode.title.isEmpty)
            #expect(!mode.detail.isEmpty)
            #expect(mode.energyFloor > 0)
            #expect(mode.unvoicedFloor < mode.energyFloor)
        }
    }

    @Test func roundTripsThroughCodable() throws {
        let encoded = try JSONEncoder().encode(InputMode.whistle)
        let decoded = try JSONDecoder().decode(InputMode.self, from: encoded)
        #expect(decoded == .whistle)
    }
}

struct PitchSmootherTests {
    @Test func firstSamplePassesThrough() {
        let smoother = PitchSmoother()
        #expect(smoother.filter(hz: 220, timestamp: 0) == 220)
    }

    @Test func attenuatesASuddenJump() {
        let smoother = PitchSmoother()
        _ = smoother.filter(hz: 220, timestamp: 0)
        let next = smoother.filter(hz: 440, timestamp: 0.01)
        #expect(next > 220)
        #expect(next < 440)
    }

    @Test func resetAllowsPassThroughAgain() {
        let smoother = PitchSmoother()
        _ = smoother.filter(hz: 220, timestamp: 0)
        _ = smoother.filter(hz: 330, timestamp: 0.02)
        smoother.reset()
        #expect(smoother.filter(hz: 110, timestamp: 1) == 110)
    }
}

struct YinEdgeTests {
    @Test func midiAndHzRoundTrip() {
        for midi in [48.0, 60.0, 69.0, 72.0, 81.0] {
            let hz = YinDetector.hz(fromMidi: midi)
            #expect(abs(YinDetector.midi(fromHz: hz) - midi) < 0.0001)
        }
    }

    @Test func emptyAndTinyBuffersReturnNil() {
        #expect(YinDetector.pitch(samples: [], sampleRate: 44_100, minFrequency: 80, maxFrequency: 400) == nil)
        #expect(YinDetector.pitch(samples: [0.1, 0.2], sampleRate: 44_100, minFrequency: 80, maxFrequency: 400) == nil)
        #expect(YinDetector.rms(samples: []) == 0)
    }

    @Test func invertedRangeReturnsNil() {
        let samples = TestFixtures.sine(hz: 220)
        #expect(
            YinDetector.pitch(
                samples: samples,
                sampleRate: 44_100,
                minFrequency: 400,
                maxFrequency: 80
            ) == nil
        )
    }

    @Test func analyzerAppliesSmoother() {
        let smoother = PitchSmoother()
        let a = PitchTracker.analyze(
            samples: TestFixtures.sine(hz: 220),
            sampleRate: 44_100,
            mode: .hum,
            smoother: smoother,
            timestamp: 0
        )
        let b = PitchTracker.analyze(
            samples: TestFixtures.sine(hz: 330),
            sampleRate: 44_100,
            mode: .hum,
            smoother: smoother,
            timestamp: 0.02
        )
        #expect(a.voiced)
        #expect(b.voiced)
        #expect(abs((b.hz ?? 0) - 330) > 1)
    }

    @Test func quietToneIsUnvoiced() {
        let samples = TestFixtures.sine(hz: 220, amplitude: 0.0002)
        let reading = PitchTracker.analyze(samples: samples, sampleRate: 44_100, mode: .hum)
        #expect(!reading.voiced)
        #expect(reading.hz == nil)
    }
}
