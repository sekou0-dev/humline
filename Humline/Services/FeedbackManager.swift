import UIKit

@MainActor
final class FeedbackManager {
    static let shared = FeedbackManager()

    enum Event {
        case buttonTap
        case success
        case fail
    }

    private let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
        || ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil

    func play(_ event: Event) {
        guard !isTestEnvironment, AppSettings.hapticsEnabled else { return }
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
