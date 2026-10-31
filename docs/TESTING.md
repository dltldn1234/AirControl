# Testing

Run the local checks from the repository root:

```sh
tuist generate --no-open
swiftlint lint --strict
xcodebuild -project AirControl.xcodeproj -scheme AirControl -destination 'platform=macOS' test
xcodebuild -project AirControl.xcodeproj -scheme AirControl -configuration Release -destination 'platform=macOS' build
git diff --check
```

The unit suite covers cursor coordinate mapping and smoothing, calibration math and persistence, gesture state transitions, hand-pose conversion, and window geometry/state behavior.

## Manual test matrix

- Grant and deny camera access; start, stop, and restart capture.
- Enable/disable Accessibility access and verify no system events are emitted while unauthorized.
- Test cursor, clicks, drag release, scroll, calibration, and emergency stop with the built-in camera.
- Test Korean and English keyboard input in ordinary text fields; separately test secure fields and focus retention.
- Test window moves/resizing and app switching with supported and unsupported applications.
- Test the user's monitor arrangement, fullscreen behavior, sleep/wake, and camera disconnect.

Automated tests do not count as manual checks for these items.
