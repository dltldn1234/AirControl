# Development

## Requirements

- macOS 14 or later
- Xcode and the matching macOS SDK
- Tuist
- SwiftLint

## Local workflow

```sh
git status --short
tuist generate --no-open
swiftlint lint --strict
xcodebuild -project AirControl.xcodeproj -scheme AirControl -destination 'platform=macOS' test
xcodebuild -project AirControl.xcodeproj -scheme AirControl -configuration Release -destination 'platform=macOS' build
```

Tuist-generated project files and Derived Data are ignored. Edit `Project.swift` and files under `Sources/` or `Tests/`, then regenerate before Xcode builds.

## GitHub workflow

Create an Issue before implementation. Branch names use `<issue>-<type>/<work>`. Keep commits focused and use the repository's gitmoji commit convention. Open a PR with the issue number in its title; merge with a regular merge commit after required checks pass. Never force-push or overwrite unrelated work.

## Validation limits

Unit tests cover deterministic logic. They do not grant camera or Accessibility permission and do not prove input behavior in third-party apps. Record physical-camera, Korean IME, multi-monitor, window-control, and secure-field checks separately.

## GitHub Actions

`.github/workflows/macos.yml` provides the same generation, lint, test, and Release build checks as a manually dispatched workflow. It intentionally has no automatic push or pull-request trigger. Dispatching GitHub-hosted macOS workflows may consume included Actions minutes and can incur charges after the included allowance, so review the repository/account billing allowance before running it.
