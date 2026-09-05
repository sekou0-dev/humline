import Foundation

enum AppSettings {
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let inputModeKey = "inputMode"
    private static let debugUnlockKey = "debugUnlockAll"
    private static let hapticsKey = "hapticsEnabled"

    /// Shared defaults so tests snapshot the same store the app uses.
    static var store: UserDefaults = .standard

    static var hasCompletedOnboarding: Bool {
        get { store.bool(forKey: onboardingKey) }
        set { store.set(newValue, forKey: onboardingKey) }
    }

    static var inputMode: InputMode {
        get {
            if let raw = store.string(forKey: inputModeKey),
               let mode = InputMode(rawValue: raw) {
                return mode
            }
            return .hum
        }
        set { store.set(newValue.rawValue, forKey: inputModeKey) }
    }

    static var debugUnlockAll: Bool {
        get { store.bool(forKey: debugUnlockKey) }
        set { store.set(newValue, forKey: debugUnlockKey) }
    }

    static var hapticsEnabled: Bool {
        get {
            guard store.object(forKey: hapticsKey) != nil else { return true }
            return store.bool(forKey: hapticsKey)
        }
        set { store.set(newValue, forKey: hapticsKey) }
    }
}
