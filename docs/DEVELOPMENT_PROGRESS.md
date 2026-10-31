# AirControl Development Progress

Updated: 2026-11-01

## Current checkpoint

- Phase 6 Air Keyboard implementation is available in draft PR #16. Local Tuist generation, strict SwiftLint, 35 macOS unit tests, and Release build passed before the Phase 7 branch was started. Korean IME behavior, focus retention in third-party apps, secure-field detection, camera gestures, and fullscreen behavior still need manual checks.
- Phase 7 is tracked by Issue #17 on branch `17-feat/gesture-intelligence`.
- One Euro cursor filtering and multi-display coordinate mapping are implemented and covered by unit tests.
- Calibration wizard now captures a normalized cursor area and pinch thresholds, stores a local per-user profile, and exposes mirror control and reset in Settings.
- The latest macOS unit-test run passed after adding calibration tests. Strict SwiftLint passed with zero violations.

## Manual verification still required

- Run the calibration wizard with the built-in camera and confirm cursor range and pinch thresholds feel correct.
- Verify cursor motion across the user's actual multi-display arrangement.
- Verify camera permission, Accessibility authorization, and physical hand tracking.

## Next work

1. Improve gesture confidence and state transitions using deterministic tests and existing hand-pose data contracts.
2. Audit camera lifecycle, frame metrics, and stop/restart behavior.
3. Complete UI/UX and workflow documentation.
4. Run Debug and Release builds, tests, and lint before PR updates.
5. Do not merge a PR while required CI checks fail or claim manual validation without evidence.
