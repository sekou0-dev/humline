import SwiftUI

struct ResultsOverlay: View {
    let state: FlightState
    let melodyTitle: String
    var onRetry: () -> Void
    var onShare: () -> Void
    var onMenu: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(title)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                InstructionText(text: detail)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { buttons }
                    VStack(spacing: 10) { buttons }
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.35).ignoresSafeArea())
    }

    @ViewBuilder
    private var buttons: some View {
        Button("Retry") {
            FeedbackManager.shared.play(.buttonTap)
            onRetry()
        }
        .buttonStyle(.borderedProminent)

        if state == .cleared {
            Button("Beat my flight") {
                FeedbackManager.shared.play(.buttonTap)
                onShare()
            }
            .buttonStyle(.bordered)
        }

        Button("Menu") {
            FeedbackManager.shared.play(.buttonTap)
            onMenu()
        }
        .buttonStyle(.bordered)
    }

    private var title: String {
        switch state {
        case .cleared: "Phrase complete"
        case .stalled: "Stalled"
        case .crashed: "Off the song"
        default: "Run ended"
        }
    }

    private var detail: String {
        switch state {
        case .cleared:
            "You stayed inside \(melodyTitle). Share the envelope and let someone race your ghost."
        case .stalled:
            "Silence is a stall, not a hover. Keep a tone going — even a quiet one."
        case .crashed:
            "The ribbon is the melody. Match the written pitch, not a random altitude."
        default:
            melodyTitle
        }
    }
}
