import SwiftUI

struct CameraTrackingView: View {
    @StateObject private var viewModel = CameraTrackingViewModel()
    @AppStorage("cursorControlEnabled") private var cursorControlEnabled = false
    @AppStorage("showsCameraPreview") private var showsCameraPreview = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if viewModel.isRunning && showsCameraPreview {
                    CameraPreview(session: viewModel.cameraManager.captureSession)
                    HandJointOverlay(joints: viewModel.joints)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.08))
                    Text(
                        viewModel.isRunning
                            ? "Camera preview is hidden in settings"
                            : "Start the camera to preview hand tracking"
                    )
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                Label(viewModel.status, systemImage: viewModel.joints.isEmpty ? "hand.raised" : "hand.raised.fill")
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(String(format: "%.0f FPS", viewModel.framesPerSecond))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            HStack {
                Text(String(format: "Vision %.0f ms", viewModel.inferenceMilliseconds))
                Spacer()
                Text(String(format: "CPU %.0f%%", viewModel.cpuUsagePercent))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)

            Label("Gesture: \(viewModel.gestureStatus.rawValue)", systemImage: "hand.draw")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                if viewModel.isRunning || viewModel.isStarting {
                    viewModel.stopCamera()
                } else {
                    viewModel.startCamera()
                }
            } label: {
                Label(
                    viewModel.isRunning || viewModel.isStarting ? "Stop Camera" : "Start Camera",
                    systemImage: viewModel.isRunning || viewModel.isStarting ? "stop.fill" : "camera.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isStarting)

            Toggle("Enable cursor control", isOn: $cursorControlEnabled)
                .onChange(of: cursorControlEnabled) { _, enabled in
                    viewModel.setCursorControlEnabled(enabled)
                }
                .disabled(!viewModel.isRunning && !viewModel.cursorControlEnabled)

            if viewModel.cursorControlEnabled {
                Button("Emergency Stop · Esc") {
                    viewModel.emergencyStop()
                    cursorControlEnabled = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                .frame(maxWidth: .infinity)
            }

            HStack {
                Image(
                    systemName: viewModel.accessibilityAuthorized
                        ? "checkmark.shield.fill"
                        : "exclamationmark.shield.fill"
                )
                Text(
                    viewModel.accessibilityAuthorized
                        ? "Accessibility access granted"
                        : "Accessibility access required"
                )
                Spacer()
                if !viewModel.accessibilityAuthorized {
                    Button("Request Access") { viewModel.requestAccessibilityAccess() }
                }
            }
            .font(.caption)
            .foregroundStyle(viewModel.accessibilityAuthorized ? Color.secondary : Color.orange)
        }
        .onKeyPress(.escape) {
            viewModel.emergencyStop()
            cursorControlEnabled = false
            return .handled
        }
        .focusable()
    }
}

private struct HandJointOverlay: View {
    let joints: [HandJoint]

    var body: some View {
        Canvas { context, size in
            for joint in joints {
                let point = CGPoint(
                    x: (1 - joint.normalizedX) * size.width,
                    y: (1 - joint.normalizedY) * size.height
                )
                let marker = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: marker), with: .color(.green))
            }
        }
        .allowsHitTesting(false)
    }
}
