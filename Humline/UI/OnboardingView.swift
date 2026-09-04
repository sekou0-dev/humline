import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = OnboardingPage.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageCard(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(isLastPage ? "Start playing" : "Next") {
                    if isLastPage {
                        complete(skipped: false)
                    } else {
                        withAnimation { pageIndex += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

                if !isLastPage {
                    Button("Skip") { complete(skipped: true) }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }
            .padding(.bottom, 12)
            .background(HumlineTheme.sky.ignoresSafeArea())
            .foregroundStyle(HumlineTheme.ink)
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { complete(skipped: true) }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var isLastPage: Bool {
        pageIndex == pages.count - 1
    }

    private func complete(skipped: Bool) {
        AppSettings.hasCompletedOnboarding = true
        FeedbackManager.shared.play(.buttonTap)
        HumlineAnalytics.signal(skipped ? "Onboarding.skipped" : "Onboarding.completed")
        dismiss()
    }
}

struct OnboardingPage: Identifiable {
    var id: String { title }
    var symbol: String
    var title: String
    var detail: String
    var showsRibbon: Bool = false

    static let all: [OnboardingPage] = [
        OnboardingPage(
            symbol: "waveform",
            title: "You are the instrument",
            detail: "The pitch of your voice is altitude. Hum a low note to fly low. Hum higher to climb. If you go silent, the craft stalls — it does not hover."
        ),
        OnboardingPage(
            symbol: "music.note.list",
            title: "The land is the melody",
            detail: "This hill is the first phrase, drawn as land. A held note is a valley. A leap of a fifth is a cliff. Stay inside the gold ribbon. Leave it and you crash.",
            showsRibbon: true
        ),
        OnboardingPage(
            symbol: "mic",
            title: "Find your range",
            detail: "Before the first flight you hum a comfortable low note, then a comfortable high note. Humline maps that range onto the phrase — you do not need concert pitch. Throat-hum is the default so you can play quietly."
        ),
        OnboardingPage(
            symbol: "lock.iphone",
            title: "The microphone stays here",
            detail: "Audio is processed on this iPhone and is never uploaded. “Beat my flight” shares a pitch envelope of the run, not a recording of your voice."
        ),
    ]
}

private struct OnboardingPageCard: View {
    let page: OnboardingPage

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                let compact = geo.size.height < 460
                Group {
                    if compact {
                        HStack(alignment: .top, spacing: 20) {
                            leadingVisual(compact: true)
                            copyColumn(alignment: .leading)
                        }
                    } else {
                        VStack(spacing: 16) {
                            leadingVisual(compact: false)
                            copyColumn(alignment: .center)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private func leadingVisual(compact: Bool) -> some View {
        if page.showsRibbon {
            MelodyRibbonView(melody: MelodyLibrary.fallbackPhrases[0])
                .frame(width: compact ? 180 : nil, height: compact ? 88 : 96)
                .frame(maxWidth: compact ? 180 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("A rising and falling hill shaped like the first phrase")
        } else {
            Image(systemName: page.symbol)
                .font(.system(size: compact ? 36 : 48, weight: .light))
                .foregroundStyle(HumlineTheme.corridor)
                .frame(width: compact ? 48 : nil)
                .accessibilityHidden(true)
        }
    }

    private func copyColumn(alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .center, spacing: 10) {
            Text(page.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(alignment)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
            InstructionText(text: page.detail, alignment: alignment)
        }
    }
}

#Preview {
    OnboardingView()
}
