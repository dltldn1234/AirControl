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
- Latest artifacts (built from `main` after PR #46): `/Users/isiu/Desktop/AirControl-builds/Release-2026-11-01-r3/AirControl.app` and `/Users/isiu/Desktop/AirControl-builds/Release-2026-11-01-r3/AirControl-local.zip`; ZIP integrity, universal x86_64/arm64 architecture, bundle identifier, and macOS 14 minimum were checked. The ZIP SHA-256 is `afd5c5b7639eb0ccdfdabeb2b409478e4b5589c3a51e9a7f42bb542012010b20`.
- Follow-up Issue #25 was merged through PR #26 and adds camera interruption and fatal runtime-error reporting.
- Follow-up Issue #27 was merged through PR #28 and adds per-pinch action mapping and duplicate-action feedback.
- Issue #29 was merged through PR #30 and adds allowlisted JSON settings export/import.
- Imported settings validate value ranges and string enums and force cursor, keyboard, window, and app-switch controls off.
- The latest local suite passed 59 tests, with zero SwiftLint violations. Tuist generation, Debug build, Release build, ZIP integrity, and launching/quitting the menu bar app all passed.

## Latest continuation: bounded frame processing

- Issue #35 coalesces cursor/window processing input to the newest pending camera frame. This bounds queued work to one pending frame while keeping gesture state serialized on the existing processing queue.
- Empty frames are retained when they replace an older pending frame, so tracking-loss handling is not hidden by the coalescer.
- Added tests for newest-frame selection, scheduler re-arming, and empty-frame retention. Latest macOS arm64 suite: 62 passed, 0 failed, 0 skipped; Debug build and strict SwiftLint pass.
- Live latency/CPU comparison requires camera use and remains unmeasured. No performance improvement percentage is claimed.

## Latest continuation: Korean keyboard mapping

- Issue #37 corrected the Korean Dubeolsik middle row to map its nine letter keys to physical `a` through `l`; the English ten-key row remains unchanged.
- Added a regression test for all nine Korean labels and absence of a semicolon key. Latest macOS arm64 suite: 63 passed, 0 failed, 0 skipped; Debug build and strict SwiftLint pass.
- This validates the layout mapping only. Actual Korean IME composition and the configured Control-Space shortcut still require manual validation in a regular text field.

## Latest continuation: camera selection

- Issue #39 adds built-in/external camera discovery, a saved camera choice, permission/empty/disconnected states, refresh on device attach/detach, and safe fallback to the built-in front camera or first available device.
- The selected device applies on the next camera start; switching an active capture session is intentionally not implied.
- Camera preference/fallback tests are included. Live device enumeration and external camera capture still require manual hardware validation.

## Latest continuation: camera start/stop lifecycle

- Issue #41 adds monotonically increasing camera lifecycle generations. A stop invalidates a pending start, waits for it to settle, and then tears down the capture session.
- Camera UI now represents and disables duplicate actions while stopping; stale start completions cannot restore the running state.
- Added deterministic generation invalidation coverage. Latest macOS arm64 suite: 65 passed, 0 failed, 0 skipped; Release build and strict SwiftLint pass. The camera permission-prompt race has not been exercised against physical AVFoundation hardware.

## Latest continuation: configurable double click

- Issue #43 adds `Double click` to both pinch action pickers and preserves it through settings export/import validation.
- A short pinch emits one double-click action after release. Click and double-click share a cooldown to prevent repeated activation; long holds do not turn the double-click mapping into a drag.
- The cursor event queue posts two left-button down/up pairs with click states 1 and 2, only while control is enabled and Accessibility is trusted.
- Added recognition cooldown, click-state sequence, and settings round-trip coverage. macOS arm64 suite: 67 passed, 0 failed, 0 skipped; Release build passed; strict SwiftLint reported 0 violations in 43 files.
- Actual system double-click delivery through Accessibility and a hand gesture remains NOT TESTED.

## Latest continuation: paired mouse click dispatch

- Issue #45 routes left click, right click, and each click in a double-click through a paired event path that constructs both down and up events before posting either one.
- This avoids posting a button-down when construction of its corresponding release event fails. Existing Accessibility and control-enabled gates remain in place.
- Added a test proving an incomplete event pair posts nothing and a complete pair posts both events. The test validates planning only and never posts system input.
- macOS arm64 suite: 68 passed, 0 failed, 0 skipped; Release build passed; strict SwiftLint reported 0 violations in 43 files.

## Manual verification still required

- Run the calibration wizard with the built-in camera and confirm cursor range and pinch thresholds feel correct.
- Verify cursor motion across the user's actual multi-display arrangement.
- Verify camera permission, Accessibility authorization, and physical hand tracking.

## Next work

1. Complete physical-camera, Accessibility, Korean IME, window control, app switching, and multi-monitor checks when the user is available.
2. Dispatch macOS CI only after reviewing the repository's Actions billing allowance.
3. Developer ID signing and notarization require the user's Apple Developer credentials.
4. Do not claim manual validation without evidence.

## Safety notes

- Camera images and typed text are not persisted or sent to a service.
- Synthetic key events require Accessibility access and are disabled by default.
- Secure-field prevention depends on target applications exposing their focused element subrole through Accessibility.
- Local Release builds have only the platform ad-hoc linker signature; Developer ID signing and notarization are not configured.
