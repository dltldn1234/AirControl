# AirControl

AirControl is a native macOS menu bar app scaffold for future hand-gesture controls. It uses SwiftUI and AppKit, with a Tuist-generated Xcode project and a service-oriented MVVM structure.

> Phase 1 only establishes the project foundation. Camera tracking and macOS input events are not implemented.

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

## Permissions

The app bundle includes `NSCameraUsageDescription` so the camera purpose is declared before camera capture is implemented. Phase 1 does not request camera access.

Future system cursor input will require the user to grant AirControl access under **System Settings → Privacy & Security → Accessibility**. Phase 1 does not request Accessibility access or post system input events.
