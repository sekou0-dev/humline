import Foundation
import Testing
@testable import Humline

@Suite(.serialized)
struct AppSettingsTests {
    @Test func defaultsAndRoundTrip() throws {
        try TestSupport.withRestoredSettings {
            AppSettings.store.removeObject(forKey: "hapticsEnabled")
            AppSettings.store.removeObject(forKey: "inputMode")
            AppSettings.store.removeObject(forKey: "hasCompletedOnboarding")
            AppSettings.store.removeObject(forKey: "debugUnlockAll")

            #expect(AppSettings.hapticsEnabled)
            #expect(AppSettings.inputMode == .hum)
            #expect(!AppSettings.hasCompletedOnboarding)
            #expect(!AppSettings.debugUnlockAll)

            AppSettings.hapticsEnabled = false
            AppSettings.inputMode = .whistle
            AppSettings.hasCompletedOnboarding = true
            AppSettings.debugUnlockAll = true

            #expect(!AppSettings.hapticsEnabled)
            #expect(AppSettings.inputMode == .whistle)
            #expect(AppSettings.hasCompletedOnboarding)
            #expect(AppSettings.debugUnlockAll)
        }
    }

    @Test func unknownInputModeFallsBackToHum() throws {
        try TestSupport.withRestoredSettings {
            AppSettings.store.set("kazoo", forKey: "inputMode")
            #expect(AppSettings.inputMode == .hum)
        }
    }
}

@Suite(.serialized)
struct VoiceCalibrationStoreTests {
    @Test func saveLoadAndClear() throws {
        try TestSupport.withRestoredSettings {
            VoiceCalibrationStore.clear()
            #expect(VoiceCalibrationStore.load() == nil)

            let stored = VoiceCalibration(lowHz: 120, highHz: 280)
            VoiceCalibrationStore.save(stored)
            #expect(VoiceCalibrationStore.load() == stored)

            VoiceCalibrationStore.clear()
            #expect(VoiceCalibrationStore.load() == nil)
        }
    }

    @Test func clampsOutsideTheSungRange() {
        let calibration = VoiceCalibration(lowHz: 110, highHz: 330)
        #expect(calibration.normalizedPitch(hz: 50) == 0)
        #expect(calibration.normalizedPitch(hz: 800) == 1)
    }

    @Test func midiNormalizedHandlesDegenerateSpan() {
        #expect(VoiceCalibration.midiNormalized(64, minMidi: 60, maxMidi: 60) == 0.5)
        #expect(VoiceCalibration.midiNormalized(90, minMidi: 60, maxMidi: 72) == 1)
        #expect(VoiceCalibration.midiNormalized(10, minMidi: 60, maxMidi: 72) == 0)
    }
}

@MainActor
@Suite(.serialized)
struct PhraseStoreTests {
    @Test func freePhrasesAreUnlockedWithoutAPack() throws {
        try TestSupport.withRestoredSettings {
            AppSettings.debugUnlockAll = false
            let store = PhraseStore()
            #expect(store.isUnlocked(TestFixtures.drone))
            #expect(!store.isUnlocked(TestFixtures.paidPhrase))
            #expect(store.priceText == "£2.99")
            #expect(PhraseStore.phrasePackID == "com.catfordlabs.humline.phrasepack")
        }
    }

    @Test func debugUnlockOpensPaidPhrases() throws {
        try TestSupport.withRestoredSettings {
            AppSettings.debugUnlockAll = true
            let store = PhraseStore()
            #expect(store.isUnlocked(TestFixtures.paidPhrase))
        }
    }

    @Test func purchaseWithoutAProductExplainsTheMiss() async {
        let store = PhraseStore()
        await store.purchase()
        #expect(store.statusMessage == "Phrase pack is not available in this build yet.")
    }
}

struct EnvelopeShareTests {
    @Test func loadReturnsNilForMissingAndCorruptFiles() throws {
        let missing = URL(fileURLWithPath: "/tmp/humline-missing-\(UUID().uuidString).humline")
        #expect(EnvelopeShare.load(from: missing) == nil)

        let corrupt = FileManager.default.temporaryDirectory.appendingPathComponent("corrupt.humline")
        try Data("not json".utf8).write(to: corrupt)
        #expect(EnvelopeShare.load(from: corrupt) == nil)
        try FileManager.default.removeItem(at: corrupt)
    }

    @Test func writeUsesHumlineExtension() throws {
        let flight = SharedFlight(
            melodyId: "first-phrase",
            melodyTitle: "First Phrase",
            envelope: .empty(melodyId: "first-phrase", inputMode: .hum)
        )
        let url = try #require(EnvelopeShare.writeTemporary(flight))
        #expect(url.pathExtension == EnvelopeShare.fileExtension)
        #expect(EnvelopeShare.uti == "com.catfordlabs.humline.flight")
        try FileManager.default.removeItem(at: url)
    }

    @Test func appendThrottlesFasterThanFortyFiveHertz() {
        var envelope = PerformanceEnvelope.empty(melodyId: "drone", inputMode: .hum)
        envelope.append(time: 0, pitch: 0.2, voiced: true)
        envelope.append(time: 0.01, pitch: 0.9, voiced: true)
        #expect(envelope.points.count == 1)
        envelope.append(time: 0.05, pitch: 0.4, voiced: false)
        #expect(envelope.points.count == 2)
        #expect(envelope.pitch(at: -1)?.pitch == 0.2)
        #expect(envelope.pitch(at: 99)?.pitch == 0.4)
        #expect(PerformanceEnvelope.empty(melodyId: "x", inputMode: .hum).pitch(at: 0) == nil)
    }
}

struct PitchReadingTests {
    @Test func silentSentinel() {
        #expect(PitchReading.silent.hz == nil)
        #expect(!PitchReading.silent.voiced)
        #expect(PitchReading.silent.rms == 0)
    }
}

struct OnboardingPageTests {
    @Test func onlyTheLandPageShowsARibbon() {
        let ribbonPages = OnboardingPage.all.filter(\.showsRibbon)
        #expect(ribbonPages.map(\.title) == ["The land is the melody"])
        #expect(OnboardingPage.all[0].symbol == "waveform")
    }
}
