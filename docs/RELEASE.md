# Local Release

Generate the Tuist project and build the Release configuration:

```sh
tuist generate --no-open
xcodebuild -project AirControl.xcodeproj -scheme AirControl -configuration Release -destination 'platform=macOS' build
```

A successful local build is not a signed or notarized distribution. This repository's local build has not been notarized. Before distributing outside the development Mac, configure an Apple Developer ID signing identity, sign the app, submit it for notarization, and verify Gatekeeper assessment. Do not publish an external release without explicit approval.
