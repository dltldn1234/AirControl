# Local Release

Generate the Tuist project and build the Release configuration:

```sh
tuist generate --no-open
xcodebuild -project AirControl.xcodeproj -scheme AirControl -configuration Release -destination 'platform=macOS' build
```

A successful local build is not a signed or notarized distribution. This repository's local build has not been notarized. Before distributing outside the development Mac, configure an Apple Developer ID signing identity, sign the app, submit it for notarization, and verify Gatekeeper assessment. Do not publish an external release without explicit approval.

The latest locally packaged universal Release build is at `/Users/isiu/Desktop/AirControl-builds/Release-2026-11-01-r4/`. Its ZIP SHA-256 is `00d4ea7563db56a8327857128a59a0fa20d42ae709e2357f25caa810256b3598`. The package was checked for x86_64 and arm64 slices, bundle metadata, and ZIP integrity; it was not launch-smoke-tested, Developer ID-signed, or notarized.
