import Testing
import Foundation
@testable import Humline

struct YinDetectorTests {
    @Test func detectsLowHumSine() {
        let samples = sine(hz: 220, sampleRate: 44_100, count: 4096)
        let reading = PitchTracker.analyze(samples: samples, sampleRate: 44_100, mode: .hum)
        #expect(reading.voiced)
        #expect(abs((reading.hz ?? 0) - 220) < 4)
        #expect(abs((reading.midi ?? 0) - YinDetector.midi(fromHz: 220)) < 0.4)
        #expect(reading.rms > 0.1)
    }

    @Test func detectsMidHumSine() {
        let samples = sine(hz: 330, sampleRate: 44_100, count: 4096)
        let reading = PitchTracker.analyze(samples: samples, sampleRate: 44_100, mode: .hum)
        #expect(reading.voiced)
        #expect(abs((reading.hz ?? 0) - 330) < 6)
    }

    @Test func detectsHighHumSine() {
        let samples = sine(hz: 520, sampleRate: 44_100, count: 4096)
        let reading = PitchTracker.analyze(samples: samples, sampleRate: 44_100, mode: .hum)
        #expect(reading.voiced)
        #expect(abs((reading.hz ?? 0) - 520) < 10)
    }

    @Test func detectsWhistleSine() {
        let samples = sine(hz: 880, sampleRate: 44_100, count: 4096)
        let reading = PitchTracker.analyze(samples: samples, sampleRate: 44_100, mode: .whistle)
        #expect(reading.voiced)
        #expect(abs((reading.hz ?? 0) - 880) < 10)
    }

    @Test func silenceIsUnvoiced() {
        let samples = [Float](repeating: 0, count: 2048)
        let reading = PitchTracker.analyze(samples: samples, sampleRate: 44_100, mode: .hum)
        #expect(!reading.voiced)
        #expect(reading.hz == nil)
        #expect(reading.rms < 0.001)
    }

    @Test func humRangeCannotReportWhistleFrequency() {
        let samples = sine(hz: 1760, sampleRate: 44_100, count: 4096)
        let reading = PitchTracker.analyze(samples: samples, sampleRate: 44_100, mode: .hum)
        if let hz = reading.hz {
            #expect(InputMode.hum.frequencyRange.contains(hz))
            #expect(abs(hz - 1760) > 200)
        }
    }
}

struct VoiceCalibrationTests {
    @Test func mapsRangeEnds() {
        let calibration = VoiceCalibration(lowHz: 110, highHz: 330)
        #expect(calibration.isValid)
        #expect(calibration.normalizedPitch(hz: 110) == 0)
        #expect(abs(calibration.normalizedPitch(hz: 330) - 1) < 0.001)
        #expect(calibration.normalizedPitch(hz: 190.5) > 0.3)
        #expect(calibration.normalizedPitch(hz: 190.5) < 0.7)
        #expect(calibration.normalizedPitch(hz: 280) >= 0.95)
    }

    @Test func midiNormalizedUsesMelodySpan() {
        #expect(VoiceCalibration.midiNormalized(60, minMidi: 60, maxMidi: 72) == 0)
        #expect(VoiceCalibration.midiNormalized(72, minMidi: 60, maxMidi: 72) == 1)
        #expect(abs(VoiceCalibration.midiNormalized(66, minMidi: 60, maxMidi: 72) - 0.5) < 0.001)
    }

    @Test func invalidWhenRangeTooSmall() {
        #expect(!VoiceCalibration(lowHz: 200, highHz: 210).isValid)
    }

    @Test func calibrationMedian() {
        #expect(CalibrationView.median([1, 3, 2]) == 2)
        #expect(CalibrationView.median([1, 2, 3, 4]) == 2.5)
    }
}

struct OnboardingCopyTests {
    @Test func pagesCoverTheFullLoop() {
        let pages = OnboardingPage.all
        #expect(pages.count == 4)
        #expect(pages.map(\.title) == [
            "You are the instrument",
            "The land is the melody",
            "Find your range",
            "The microphone stays here",
        ])
        for page in pages {
            #expect(page.detail.count > 80)
            #expect(!page.detail.contains("…"))
            #expect(page.detail.hasSuffix("."))
        }
        #expect(pages[0].detail.contains("stalls"))
        #expect(pages[1].detail.contains("gold ribbon"))
        #expect(pages[2].detail.contains("comfortable low"))
        #expect(pages[3].detail.contains("never uploaded"))
    }
}

struct TerrainBuilderTests {
    @Test func corridorFollowsHeldNoteThenFifth() {
        let melody = Melody(
            id: "cliff",
            title: "Cliff",
            detail: "",
            tempo: 60,
            corridorHalfWidth: 0.1,
            isFree: true,
            notes: [
                .init(midi: 60, beats: 1),
                .init(midi: 67, beats: 1),
            ]
        )
        let terrain = TerrainBuilder.build(melody, cliffSeconds: 0.05)
        #expect(abs(terrain.duration - 2) < 0.001)

        let valley = terrain.sample(at: 0.4)
        let mountain = terrain.sample(at: 1.4)
        #expect(valley.center < 0.15)
        #expect(mountain.center > 0.85)
        #expect(abs(mountain.center - valley.center) > 0.7)
        #expect(valley.halfWidth == 0.1)
    }

    @Test func firstPhraseIsAHill() {
        let melody = MelodyLibrary.fallbackPhrases[0]
        let terrain = TerrainBuilder.build(melody)
        let start = terrain.sample(at: 0).center
        let peak = terrain.sample(at: terrain.duration * 0.4).center
        let end = terrain.sample(at: terrain.duration).center
        #expect(peak > start)
        #expect(abs(end - start) < 0.05)
    }

    @Test func bundledCatalogHasTwelvePhrases() {
        let phrases = MelodyLibrary.loadBundled()
        #expect(phrases.count == 12)
        #expect(phrases.filter(\.isFree).count == 4)
        #expect(phrases.contains { $0.id == "fifth-cliff" })
        #expect(phrases.contains { $0.id == "the-score" })
    }
}

struct FlightRulesTests {
    @Test func stallAfterSilencePastGrace() {
        #expect(!FlightRules.shouldStall(quietDuration: FlightRules.stallSilence, elapsed: 0.2))
        #expect(!FlightRules.shouldStall(quietDuration: 0.5, elapsed: 0.2))
        #expect(FlightRules.shouldStall(quietDuration: FlightRules.stallSilence, elapsed: 0.5))
        #expect(!FlightRules.shouldStall(quietDuration: 0.05, elapsed: 1))
    }

    @Test func crashOutsideCorridorAfterGrace() {
        #expect(!FlightRules.shouldCrash(sung: 0.5, center: 0.5, halfWidth: 0.1, outsideDuration: 1))
        #expect(!FlightRules.shouldCrash(sung: 0.8, center: 0.5, halfWidth: 0.1, outsideDuration: 0.01))
        #expect(FlightRules.shouldCrash(sung: 0.8, center: 0.5, halfWidth: 0.1, outsideDuration: FlightRules.crashGrace))
    }

    @Test func easeMovesTowardTarget() {
        let next = FlightRules.ease(current: 0, target: 1, dt: 0.1)
        #expect(next > 0)
        #expect(next < 1)
    }

    @Test func terminalStates() {
        #expect(FlightState.stalled.isTerminal)
        #expect(FlightState.crashed.isTerminal)
        #expect(FlightState.cleared.isTerminal)
        #expect(!FlightState.flying.isTerminal)
        #expect(FlightState.flying.allowsFlight)
    }
}

struct PerformanceEnvelopeTests {
    @Test func recordsAndSamplesGhost() {
        var envelope = PerformanceEnvelope.empty(melodyId: "first-phrase", inputMode: .hum)
        envelope.append(time: 0, pitch: 0.2, voiced: true)
        envelope.append(time: 1, pitch: 0.8, voiced: true)
        let mid = envelope.pitch(at: 0.5)
        #expect(mid != nil)
        #expect(abs((mid?.pitch ?? 0) - 0.5) < 0.001)
    }

    @Test func roundTripsThroughShareFile() throws {
        var envelope = PerformanceEnvelope.empty(melodyId: "first-phrase", inputMode: .whistle)
        envelope.append(time: 0.2, pitch: 0.4, voiced: true)
        let flight = SharedFlight(melodyId: "first-phrase", melodyTitle: "First Phrase", envelope: envelope)
        let url = try #require(EnvelopeShare.writeTemporary(flight))
        let loaded = try #require(EnvelopeShare.load(from: url))
        #expect(loaded.melodyId == "first-phrase")
        #expect(loaded.envelope.points.count == 1)
        try FileManager.default.removeItem(at: url)
    }
}

private func sine(hz: Double, sampleRate: Double, count: Int) -> [Float] {
    (0..<count).map { index in
        Float(sin(2 * Double.pi * hz * Double(index) / sampleRate) * 0.6)
    }
}
