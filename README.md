# AirControl

AirControl is a native macOS menu bar app scaffold for future hand-gesture controls. It uses SwiftUI and AppKit, with a Tuist-generated Xcode project and a service-oriented MVVM structure.

The current foundation includes live camera preview and Vision hand-joint tracking. macOS cursor and gesture controls are planned for a later phase.

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
    ├── Camera/          # CameraManager placeholder
    ├── HandPose/        # HandPoseDetector placeholder
    ├── Gesture/         # GestureRecognizer placeholder
    └── Cursor/          # CursorController placeholder
Tests/                   # Unit tests
```

## Camera tracking

Open the menu bar item and select **Start Camera**. After camera access is granted, AirControl displays the live preview, detected hand joints, hand-detection state, and frame rate. Select **Stop Camera** to stop capture and release its session inputs and outputs.

## Permissions

The app bundle includes `NSCameraUsageDescription`. Camera access is requested only when the user selects **Start Camera**. If access is denied, allow it under **System Settings → Privacy & Security → Camera**.

Future system cursor input will require the user to grant AirControl access under **System Settings → Privacy & Security → Accessibility**. Cursor control is not implemented yet.
