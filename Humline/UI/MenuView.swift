import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var phraseStore: PhraseStore
    @State private var phrases: [Melody] = MelodyLibrary.loadBundled()
    @State private var activeController: FlightController?
    @State private var showOnboarding = false
    @State private var showGym = false
    @State private var pendingStart: (() -> Void)?
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

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
                    }
                    .padding(.top, 12)

                    MelodyRibbonView(melody: phrases.first ?? MelodyLibrary.fallbackPhrases[0])
                        .frame(height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(spacing: 10) {
                        Button("How to play") {
                            FeedbackManager.shared.play(.buttonTap)
                            showOnboarding = true
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button("Pitch gym") {
                            FeedbackManager.shared.play(.buttonTap)
                            showGym = true
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
                            Button("Unlock \(phraseStore.priceText)") {
                                Task { await phraseStore.purchase() }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Restore purchases") {
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
                    showOnboarding = true
                }
            }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if let pendingStart {
                self.pendingStart = nil
                pendingStart()
            }
        }) {
            OnboardingView()
        }
        .sheet(isPresented: $showGym) {
            PitchGymView()
        }
        .fullScreenCover(item: $activeController, onDismiss: {
            phrases = MelodyLibrary.loadBundled()
        }) { controller in
            GameContainerView(controller: controller) {
                activeController = nil
            }
            .interactiveDismissDisabled()
        }
    }

    private func beginGame(_ melody: Melody) {
        FeedbackManager.shared.play(.buttonTap)
        guard phraseStore.isUnlocked(melody) else { return }
        let start = {
            activeController = FlightController(melody: melody)
        }
        if AppSettings.hasCompletedOnboarding {
            start()
        } else {
            pendingStart = start
            showOnboarding = true
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
