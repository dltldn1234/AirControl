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
│   ├── Keyboard/        # Floating keyboard UI, state, and AppKit panel
│   ├── MenuBar/         # Menu bar experience and presentation state
│   └── Settings/        # Permission and gesture settings
└── Services/
    ├── Camera/          # AVFoundation capture
    ├── HandPose/        # Vision hand-joint detection
    ├── Gesture/         # Pinch and drag state machine
    ├── Keyboard/        # Key events, coordinate mapping, and pinch selection
    ├── Cursor/          # Mapping, smoothing, and CGEvent control
    └── Window/          # Accessibility-backed window and app controls
Tests/                   # Unit tests
```

## Camera tracking

Open the menu bar item and select **Start Camera**. After camera access is granted, AirControl displays the live preview, detected hand joints, hand-detection state, and frame rate. Select **Stop Camera** to stop capture and release its session inputs and outputs.

Start the camera before enabling cursor control. Cursor control starts OFF each time the app launches and requires AirControl to be allowed in **System Settings → Privacy & Security → Accessibility**. The index fingertip moves the cursor; a brief thumb-index pinch clicks, while a pinch held for about 450 ms begins a drag. Holding the index and middle fingers extended and moving vertically scrolls; thumb-middle pinches right-click. Releasing a gesture or losing hand tracking safely ends active input. Turn the toggle off or press **Esc** in the menu bar panel for an emergency stop. Cursor and scroll sensitivity, smoothing, pinch sensitivity, drag hold time, gesture toggles, scroll direction, and preview visibility are saved in UserDefaults.

## Permissions

The app bundle includes `NSCameraUsageDescription`. Camera access is requested only when the user selects **Start Camera**. If access is denied, allow it under **System Settings → Privacy & Security → Camera**.

Cursor input is never emitted unless the camera is running, the user has enabled cursor control, and macOS reports Accessibility authorization.

Settings includes a calibration wizard for the comfortable index-finger range and normalized pinch thresholds. Profiles stay in the current macOS user's preferences.

The tracking panel reports the current gesture, processed Vision FPS, inference latency, and estimated app CPU usage. Rendering updates are throttled separately from camera-frame inference.

Window and app controls are opt-in in Settings and require Accessibility permission. Hold an open palm to enter window mode, pinch and move to reposition the focused window, use two open hands to resize, and hold a fist to exit. A three-finger horizontal swipe switches among visible regular applications. Some apps do not expose writable AX window attributes; AirControl skips those windows. macOS Spaces and full-screen desktop navigation are not controlled.

## Air Keyboard

Air Keyboard is an optional non-activating floating panel controlled by the Vision index fingertip and thumb-index pinch. It supports English QWERTY and Korean Dubeolsik labels, basic editing keys, and settings for size, opacity, sensitivity, and feedback. It pauses cursor and window gestures while active and requires Accessibility access. Korean IME composition and focus retention vary by target app and must be checked manually. See [Air Keyboard documentation](docs/AIR_KEYBOARD.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Development setup and workflow](docs/DEVELOPMENT.md)
- [Gesture guide](docs/GESTURES.md)
- [Cursor calibration](docs/CALIBRATION.md)
- [Testing and manual QA](docs/TESTING.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Local release and signing](docs/RELEASE.md)
- [Air Keyboard](docs/AIR_KEYBOARD.md)

Unit tests do not verify physical hand tracking, real system input, Korean IME behavior, third-party Accessibility support, or multi-monitor ergonomics. These still require hands-on validation. Local Release builds are not signed or notarized for distribution.
