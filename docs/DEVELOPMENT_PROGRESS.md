# AirControl Development Progress

Updated: 2026-11-01

## Current checkpoint

- Phase 6 Air Keyboard was merged through PR #16. After integrating Phase 7 base changes to resolve a conflict, Tuist generation, strict SwiftLint (0 violations), 46 macOS arm64 tests, and Release build passed. Korean IME behavior, focus retention in third-party apps, secure-field detection, camera gestures, and fullscreen behavior still need manual checks.
- Phase 7 Issue #17 was merged through PR #18.
- One Euro cursor filtering and multi-display coordinate mapping are implemented and covered by unit tests.
- Calibration wizard now captures a normalized cursor area and pinch thresholds, stores a local per-user profile, and exposes mirror control and reset in Settings.
- The latest macOS unit-test run passed after adding calibration tests. Strict SwiftLint passed with zero violations.
- Phase 8 Issue #19 was merged through PR #20; menu control state recovery and project documentation are on `main`.
- Phase 8 remains partial: the full Dashboard, Camera Preview, Settings, Air Keyboard, and accessibility design audit was not completed.
- Phase 9–10 Issue #21 was merged through PR #22.
- Camera stop now detaches and drains the serial frame queue before removing session resources; CPU timing resets across restart. FPS and CPU calculations reject invalid intervals and have deterministic tests.
- A manually dispatched macOS CI workflow is configured. It has not been run; GitHub-hosted macOS minutes can incur charges beyond the account allowance.
- Phase 11/14 Issue #23 was merged through PR #24; a local universal Release app and ZIP were created and opened once as a smoke test. They have only an ad-hoc linker signature; Developer ID signing and notarization are not configured.
- Current artifacts: `/Users/isiu/Desktop/AirControl-builds/Release-2026-11-01/AirControl.app` and `/Users/isiu/Desktop/AirControl-builds/Release-2026-11-01/AirControl-local.zip`; ZIP integrity, universal x86_64/arm64 architecture, bundle identifier, and macOS 14 minimum were checked.
- Follow-up Issue #25 adds camera interruption and fatal runtime-error reporting; it is in progress on branch `25-fix/camera-runtime-state`.
- The latest local suite passed 51 tests, with zero SwiftLint violations and a successful Release build.

## Manual verification still required

- Run the calibration wizard with the built-in camera and confirm cursor range and pinch thresholds feel correct.
- Verify cursor motion across the user's actual multi-display arrangement.
- Verify camera permission, Accessibility authorization, and physical hand tracking.

## Next work

1. Finish Issue #23 with the QA matrix, app bundle integrity checks, and final local verification.
2. Continue gesture confidence, customization, and state transition work if evidence identifies specific gaps.
3. Do not claim manual validation without evidence.

## Safety notes

- Camera images and typed text are not persisted or sent to a service.
- Synthetic key events require Accessibility access and are disabled by default.
- Secure-field prevention depends on target applications exposing their focused element subrole through Accessibility.
- Local Release builds have only the platform ad-hoc linker signature; Developer ID signing and notarization are not configured.
