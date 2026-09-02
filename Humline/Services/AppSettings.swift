import Foundation

enum AppSettings {
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let inputModeKey = "inputMode"
    private static let debugUnlockKey = "debugUnlockAll"
    private static let hapticsKey = "hapticsEnabled"

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    static var inputMode: InputMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: inputModeKey),
               let mode = InputMode(rawValue: raw) {
                return mode
            }
            return .hum
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: inputModeKey) }
    }

    static var debugUnlockAll: Bool {
        get { UserDefaults.standard.bool(forKey: debugUnlockKey) }
        set { UserDefaults.standard.set(newValue, forKey: debugUnlockKey) }
    }

    static var hapticsEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: hapticsKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: hapticsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
    }
}
