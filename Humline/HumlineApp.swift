import SwiftUI

@main
struct HumlineApp: App {
    @StateObject private var phraseStore = PhraseStore()
    @State private var incomingFlight: SharedFlight?

    init() {
        HumlineAnalytics.start()
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") {
            AppSettings.hasCompletedOnboarding = true
            AppSettings.debugUnlockAll = !arguments.contains("-keep-locked")
            VoiceCalibrationStore.save(.fallbackHum)
        }
    }

    var body: some Scene {
        WindowGroup {
            MenuView()
                .environmentObject(phraseStore)
                .preferredColorScheme(.dark)
                .task { await phraseStore.start() }
                .onOpenURL { url in
                    incomingFlight = EnvelopeShare.load(from: url)
                }
                .fullScreenCover(item: incomingBinding) { flight in
                    IncomingFlightView(flight: flight)
                        .environmentObject(phraseStore)
                }
        }
    }

    private var incomingBinding: Binding<SharedFlight?> {
        Binding(
            get: { incomingFlight },
            set: { incomingFlight = $0 }
        )
    }
}

private struct IncomingFlightView: View {
    let flight: SharedFlight
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let melody = MelodyLibrary.phrase(id: flight.melodyId) {
            IncomingGameView(melody: melody, envelope: flight.envelope, onMenu: { dismiss() })
        } else {
            VStack(spacing: 16) {
                Text("Unknown phrase")
                    .font(.title2.weight(.semibold))
                Text("This flight was recorded on “\(flight.melodyTitle)”, which is not in this build.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(HumlineTheme.sky.ignoresSafeArea())
        }
    }
}

private struct IncomingGameView: View {
    @StateObject private var controller: FlightController
    var onMenu: () -> Void

    init(melody: Melody, envelope: PerformanceEnvelope, onMenu: @escaping () -> Void) {
        _controller = StateObject(wrappedValue: FlightController(melody: melody, ghost: envelope))
        self.onMenu = onMenu
    }

    var body: some View {
        GameContainerView(controller: controller, onMenu: onMenu)
    }
}

extension SharedFlight: Identifiable {
    var id: String { "\(melodyId)-\(envelope.recordedAt.timeIntervalSince1970)" }
}
