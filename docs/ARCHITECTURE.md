# Architecture

AirControl is a macOS 14+ menu bar app built with SwiftUI and AppKit. Tuist generates the Xcode project from `Project.swift`; source folders are grouped by feature and service.

## Runtime flow

1. `AirControlApp` creates the menu bar and Settings scenes. `AirControlAppDelegate` forces accessory-app behavior and stops system input on launch and exit.
2. `CameraTrackingViewModel` owns the camera service and publishes throttled presentation state.
3. `CameraManager` owns the AVFoundation capture session and sends frames to `HandPoseDetector` off the UI path.
4. `GestureRecognizer` maps Vision joints into cursor, click, drag, right-click, and scroll actions.
5. `CursorControlCoordinator` serializes gesture and window-control work. `CursorController` independently serializes CoreGraphics events and gates them on the user's explicit enable state and Accessibility trust.
6. `WindowControlCoordinator` and `WindowManager` perform best-effort Accessibility API window actions. Applications that reject writable AX attributes are skipped.
7. `FloatingKeyboardWindow` and keyboard services implement an opt-in non-activating panel with a separate input path.

## Safety boundaries

- Camera capture starts only after the user requests it and macOS grants camera access.
- Cursor and keyboard input start disabled and require the relevant user action and Accessibility permission.
- Tracking loss, camera stop, emergency stop, and app termination release held mouse or modifier state.
- Camera frames and typed text are not persisted by the app.
- Accessibility behavior depends on each target app and macOS privacy settings.

## Project layout

- `Sources/App`: app and lifecycle
- `Sources/Features`: menu bar, camera dashboard, settings, keyboard UI
- `Sources/Services`: camera, Vision, gestures, cursor, keyboard, and windows
- `Tests`: deterministic unit tests for mapping, state machines, and geometry
