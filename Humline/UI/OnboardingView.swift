import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0

    private let demo = MelodyLibrary.fallbackPhrases[0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TabView(selection: $pageIndex) {
                    page(
                        symbol: "waveform",
                        title: "You are the instrument",
                        detail: "The pitch of your voice is altitude. Hum low to skim. Rise and you climb. Go silent and you stall."
                    )
                    .tag(0)

                    VStack(spacing: 16) {
                        MelodyRibbonView(melody: demo)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 24)
                        Text("The land is the melody")
                            .font(.title2.weight(.semibold))
                        Text("This hill is the first phrase. A held note is a valley. A leap of a fifth is a cliff. Stay inside the ribbon.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .tag(1)

                    page(
                        symbol: "mic",
                        title: "The microphone stays here",
                        detail: "Audio is processed on your iPhone and is never uploaded. Throat-hum is the default so you can play softly in public."
                    )
                    .tag(2)

                    page(
                        symbol: "square.and.arrow.up",
                        title: "Beat a flight, not a score",
                        detail: "A shared run is a recording of the pitch you flew. Someone else can race your ghost through the same song."
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(pageIndex == 3 ? "Start playing" : "Next") {
                    if pageIndex == 3 {
                        complete()
                    } else {
                        withAnimation { pageIndex += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                if pageIndex != 3 {
                    Button("Skip") { complete() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 24)
            .background(HumlineTheme.sky.ignoresSafeArea())
            .foregroundStyle(HumlineTheme.ink)
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { complete() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func page(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(HumlineTheme.corridor)
                .padding(.top, 24)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private func complete() {
        AppSettings.hasCompletedOnboarding = true
        FeedbackManager.shared.play(.buttonTap)
        dismiss()
    }
}

#Preview {
    OnboardingView()
}
