# AirControl

AirControl is a native macOS menu bar app for hand-gesture tracking and opt-in cursor control. It uses SwiftUI and AppKit, with a Tuist-generated Xcode project and a service-oriented MVVM structure.

The app uses AVFoundation for live camera capture, Vision for hand-joint detection, and CoreGraphics events for optional system cursor control.

## Requirements

- macOS 14 or later
- Xcode with the macOS SDK
- [Tuist](https://tuist.io/)
- [SwiftLint](https://github.com/realm/SwiftLint)

## Generate, build, test, and lint

```sh
tuist generate --no-open
xcodebuild -project AirControl.xcodeproj -scheme AirControl -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project AirControl.xcodeproj -scheme AirControl -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
swiftlint lint --strict
```

## Structure

```text
Sources/
├── App/                 # SwiftUI app entry and AppKit lifecycle adapter
├── Features/
│   ├── MenuBar/         # Menu bar experience and presentation state
│   └── Settings/        # Permission and status presentation
└── Services/
    ├── Camera/          # AVFoundation capture
    ├── HandPose/        # Vision hand-joint detection
    ├── Gesture/         # Pinch and drag state machine
    └── Cursor/          # Mapping, smoothing, and CGEvent control
Tests/                   # Unit tests
```

## Camera tracking

Open the menu bar item and select **Start Camera**. After camera access is granted, AirControl displays the live preview, detected hand joints, hand-detection state, and frame rate. Select **Stop Camera** to stop capture and release its session inputs and outputs.

Start the camera before enabling cursor control. Cursor control starts OFF each time the app launches and requires AirControl to be allowed in **System Settings → Privacy & Security → Accessibility**. The index fingertip moves the cursor; a brief thumb-index pinch clicks, while a pinch held for about 450 ms begins a drag. Releasing the pinch or losing hand tracking releases the mouse button. Turn the toggle off or press **Esc** in the menu bar panel for an emergency stop. Sensitivity, smoothing, pinch sensitivity, drag hold time, and preview visibility are saved in UserDefaults.

## Permissions

The app bundle includes `NSCameraUsageDescription`. Camera access is requested only when the user selects **Start Camera**. If access is denied, allow it under **System Settings → Privacy & Security → Camera**.

Cursor input is never emitted unless the camera is running, the user has enabled cursor control, and macOS reports Accessibility authorization.
