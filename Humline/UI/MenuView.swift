import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var phraseStore: PhraseStore
    @State private var phrases: [Melody] = MelodyLibrary.loadBundled()
    @State private var cover: Cover?
    @State private var pendingStart: (() -> Void)?
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private enum Cover: Identifiable {
        case onboarding
        case gym
        case game(FlightController)

        var id: String {
            switch self {
            case .onboarding: "onboarding"
            case .gym: "gym"
            case .game(let controller): controller.id.uuidString
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Humline")
                            .font(.largeTitle.weight(.bold))
                        Text("The land is the melody. You are the instrument.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)

                    MelodyRibbonView(melody: phrases.first ?? MelodyLibrary.fallbackPhrases[0])
                        .frame(height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(spacing: 10) {
                        Button("How to play") {
                            FeedbackManager.shared.play(.buttonTap)
                            HumlineAnalytics.signal("Menu.howToPlay")
                            cover = .onboarding
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button("Pitch gym") {
                            FeedbackManager.shared.play(.buttonTap)
                            HumlineAnalytics.signal("Menu.pitchGym")
                            cover = .gym
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }

                    Text("Phrases")
                        .font(.headline)
                        .padding(.top, 8)

                    ForEach(phrases) { melody in
                        PhraseRow(
                            melody: melody,
                            unlocked: phraseStore.isUnlocked(melody)
                        ) {
                            beginGame(melody)
                        }
                    }

                    if phrases.contains(where: { !phraseStore.isUnlocked($0) }) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Phrase pack")
                                .font(.headline)
                            Text("Eight more original phrases. No ads, no licensed songs.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Unlock \(phraseStore.priceText)") {
                                HumlineAnalytics.signal("Store.phrasePack.tapped")
                                Task { await phraseStore.purchase() }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Restore purchases") {
                                HumlineAnalytics.signal("Store.restore.tapped")
                                Task { await phraseStore.restore() }
                            }
                            .font(.caption)
                            if let status = phraseStore.statusMessage {
                                Text(status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }

                    Toggle("Haptics", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, newValue in
                            AppSettings.hapticsEnabled = newValue
                        }
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(HumlineTheme.sky.ignoresSafeArea())
            .foregroundStyle(HumlineTheme.ink)
            .onAppear {
                phrases = MelodyLibrary.loadBundled()
                if !AppSettings.hasCompletedOnboarding {
                    cover = .onboarding
                }
            }
        }
        .fullScreenCover(item: $cover, onDismiss: handleCoverDismiss) { item in
            switch item {
            case .onboarding:
                OnboardingView()
            case .gym:
                PitchGymView()
            case .game(let controller):
                GameContainerView(controller: controller) {
                    cover = nil
                }
                .interactiveDismissDisabled()
            }
        }
    }

    private func handleCoverDismiss() {
        phrases = MelodyLibrary.loadBundled()
        if let pendingStart {
            self.pendingStart = nil
            Task { @MainActor in
                pendingStart()
            }
        }
    }

    private func beginGame(_ melody: Melody) {
        FeedbackManager.shared.play(.buttonTap)
        guard phraseStore.isUnlocked(melody) else { return }
        let start = {
            cover = .game(FlightController(melody: melody))
        }
        if AppSettings.hasCompletedOnboarding {
            start()
        } else {
            pendingStart = start
            cover = .onboarding
        }
    }
}

private struct PhraseRow: View {
    let melody: Melody
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(melody.title)
                        .font(.headline)
                    Text(melody.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if unlocked {
                    Text("\(Int(melody.duration))s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(HumlineTheme.land, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.55)
    }
}

#Preview {
    MenuView()
        .environmentObject(PhraseStore())
}
