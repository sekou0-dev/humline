import Foundation
import TelemetryDeck

enum HumlineAnalytics {
    static let appID = "A25F65A7-B2EF-47C0-9508-E2622E465030"

    /// Test hook. Production never sets this; XCTest hosts skip the network path.
    static var recorder: ((String, [String: String]) -> Void)?

    static var isTestEnvironment: Bool {
        let process = ProcessInfo.processInfo
        let env = process.environment
        if env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil {
            return true
        }
        return process.arguments.contains("-ui-testing")
    }

    static func start() {
        guard !isTestEnvironment else { return }
        var config = TelemetryDeck.Config(appID: appID)
        config.defaultSignalPrefix = "Humline."
        #if DEBUG
        config.testMode = true
        #endif
        TelemetryDeck.initialize(config: config)
    }

    static func signal(_ name: String, parameters: [String: String] = [:]) {
        recorder?(name, parameters)
        guard !isTestEnvironment else { return }
        TelemetryDeck.signal(name, parameters: parameters)
    }
}
