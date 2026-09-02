import UIKit

@MainActor
final class FeedbackManager {
    static let shared = FeedbackManager()

    enum Event {
        case buttonTap
        case success
        case fail
    }

    func play(_ event: Event) {
        guard AppSettings.hapticsEnabled else { return }
        switch event {
        case .buttonTap:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .fail:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
