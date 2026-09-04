import SpriteKit
import SwiftUI

private struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

struct GameContainerView: View {
    @ObservedObject var controller: FlightController
    var onMenu: () -> Void = {}

    @State private var scene: FlightScene?
    @State private var showCalibration = false
    @State private var sharePayload: SharePayload?
    @State private var shareFailedMessage: String?

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    HumlineTheme.sky.ignoresSafeArea()
                    if let scene {
                        SpriteView(scene: scene)
                            .ignoresSafeArea()
                    }
                }
                .onAppear {
                    bootScene(size: geo.size)
                    controller.startMicrophone()
                    if VoiceCalibrationStore.load()?.isValid != true {
                        showCalibration = true
                        controller.beginCalibration()
                    } else {
                        controller.arm()
                    }
                }
                .onChange(of: geo.size) { _, size in
                    bootScene(size: size)
                }
            }

            if controller.flightState.isTerminal {
                ResultsOverlay(
                    state: controller.flightState,
                    melodyTitle: controller.melody.title,
                    onRetry: retry,
                    onShare: shareFlight,
                    onMenu: onMenu
                )
            }

            if showCalibration {
                CalibrationView(tracker: controller.tracker, mode: controller.inputMode) { calibration in
                    controller.calibration = calibration
                    VoiceCalibrationStore.save(calibration)
                    HumlineAnalytics.signal("Calibration.completed", parameters: [
                        "inputMode": controller.inputMode.rawValue,
                    ])
                    showCalibration = false
                    controller.arm()
                }
            }
        }
        .onDisappear {
            controller.stopMicrophone()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !showCalibration, !controller.flightState.isTerminal {
                HUDView(controller: controller, onMenu: onMenu)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(item: $sharePayload, onDismiss: cleanupShareFile) { payload in
            ShareSheet(items: [payload.url])
        }
        .alert("Couldn't share", isPresented: Binding(
            get: { shareFailedMessage != nil },
            set: { if !$0 { shareFailedMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareFailedMessage ?? "")
        }
    }

    private func retry() {
        controller.arm()
    }

    private func bootScene(size: CGSize) {
        guard scene == nil, size.width > 1, size.height > 1 else { return }
        scene = controller.makeScene(size: size)
    }

    private func shareFlight() {
        let flight = SharedFlight(
            melodyId: controller.melody.id,
            melodyTitle: controller.melody.title,
            envelope: controller.envelope
        )
        guard let url = EnvelopeShare.writeTemporary(flight) else {
            shareFailedMessage = "The flight file couldn't be written."
            return
        }
        sharePayload = SharePayload(url: url)
        HumlineAnalytics.signal("Flight.shared", parameters: [
            "melodyId": controller.melody.id,
            "title": controller.melody.title,
            "inputMode": controller.inputMode.rawValue,
        ])
    }

    private func cleanupShareFile() {
        if let sharePayload {
            try? FileManager.default.removeItem(at: sharePayload.url)
        }
        sharePayload = nil
    }
}
