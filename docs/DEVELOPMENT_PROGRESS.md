# Development Progress

Updated: 2026-11-01

## Current checkpoint

- Phase 0 repository audit completed for the current local checkout.
- Phase 1-5 code is present: Tuist/macOS app, AVFoundation camera capture, Vision hand joints, cursor gestures, Accessibility-backed window manipulation, and visible-app switching. These features have not all been revalidated against physical camera input in this session.
- Phase 6 Issue [#15](https://github.com/dltldn1234/AirControl/issues/15) was created. Work is on branch `15-feat/air-keyboard`.
- Air Keyboard code is implemented locally: opt-in non-activating NSPanel, English/Korean layouts, CoreGraphics key events, fingertip hover/pinch selection, secure-field subrole guard, camera-loss cleanup, cursor/window gesture suppression, settings, and tests.
- Phase 6 actual target-app focus and Korean IME composition are NOT TESTED. Do not close Issue #15 or describe Phase 6 as fully validated until those manual checks are done.

## Verification at checkpoint

- `tuist generate --no-open`: passed.
- `swiftlint lint --strict`: passed with 0 violations.
- macOS arm64 `xcodebuild test`: 34 tests passed, 0 failed, 0 skipped.
- macOS arm64 Release `xcodebuild build`: passed.
- `git diff --check`: passed.
- Physical camera, Accessibility event delivery, full-screen Spaces behavior, and Korean IME: not tested.

## Next work

1. Review and manually validate Air Keyboard behavior in a normal text field and a Korean Dubeolsik input source.
2. Finish any failures, then submit the Phase 6 PR without merging if manual verification remains outstanding.
3. Continue with the calibration and gesture improvements in Phase 7, each on its own Issue-first branch.
4. Proceed through UI/UX, reliability, tests, packaging, and documentation without claiming unverified hardware behavior.

## Safety notes

- Camera images and typed text are not persisted or sent to a service.
- Synthetic key events require Accessibility access and are disabled by default.
- Secure-field prevention depends on target applications exposing their focused element subrole through Accessibility.
- Release builds are local and unsigned unless a valid signing identity is explicitly configured.
