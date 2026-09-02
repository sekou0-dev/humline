import SwiftUI

struct ResultsOverlay: View {
    let state: FlightState
    let melodyTitle: String
    var onRetry: () -> Void
    var onShare: () -> Void
    var onMenu: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
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
        }
        .padding(28)
        .frame(maxWidth: 480)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.35).ignoresSafeArea())
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
