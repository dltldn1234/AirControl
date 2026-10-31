# AirControl Development Progress

Updated: 2026-11-01

## Current checkpoint

- Phase 6 Air Keyboard was merged through PR #16. After integrating Phase 7 base changes to resolve a conflict, Tuist generation, strict SwiftLint (0 violations), 46 macOS arm64 tests, and Release build passed. Korean IME behavior, focus retention in third-party apps, secure-field detection, camera gestures, and fullscreen behavior still need manual checks.
- Phase 7 Issue #17 was merged through PR #18.
- One Euro cursor filtering and multi-display coordinate mapping are implemented and covered by unit tests.
- Calibration wizard now captures a normalized cursor area and pinch thresholds, stores a local per-user profile, and exposes mirror control and reset in Settings.
- The latest macOS unit-test run passed after adding calibration tests. Strict SwiftLint passed with zero violations.
- Phase 8 Issue #19 is in progress on branch `19-feat/native-ui-docs`; menu toggle state recovery and seven project guides have been added locally.
- No GitHub Actions CI workflow is configured yet; PRs currently have no remote status checks.

## Manual verification still required

- Run the calibration wizard with the built-in camera and confirm cursor range and pinch thresholds feel correct.
- Verify cursor motion across the user's actual multi-display arrangement.
- Verify camera permission, Accessibility authorization, and physical hand tracking.

## Next work

1. Improve gesture confidence and state transitions using deterministic tests and existing hand-pose data contracts.
2. Audit camera lifecycle, frame metrics, and stop/restart behavior.
3. Complete UI/UX and workflow documentation.
4. Add a minimal macOS CI workflow under an Issue-first branch, then run Debug and Release builds, tests, and lint.
5. Do not claim manual validation without evidence.

## Safety notes

- Camera images and typed text are not persisted or sent to a service.
- Synthetic key events require Accessibility access and are disabled by default.
- Secure-field prevention depends on target applications exposing their focused element subrole through Accessibility.
- Release builds are local and unsigned unless a valid signing identity is explicitly configured.
