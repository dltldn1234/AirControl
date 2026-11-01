# Final QA Matrix

Updated: 2026-11-01. PASS means the stated software/build evidence exists; it does not imply a camera or third-party app was physically tested.

| # | Check | Status | Evidence / boundary |
| --- | --- | --- | --- |
| 1 | App launches | PASS | Local Release `.app` launched as a separate process and quit normally. |
| 2 | Camera connects | NOT TESTED | No camera capture session was exercised during this packaging pass. |
| 3 | Hand joints are detected | NOT TESTED | Vision code builds; no live hand input was observed. |
| 4 | Real cursor moves | NOT TESTED | CoreGraphics path is covered by logic/build checks, not a live permissioned session. |
| 5 | Left/right/double click works | NOT TESTED | Recognition and click-state sequence are unit tested; live system events require Accessibility permission and physical gesture validation. |
| 6 | Drag works | NOT TESTED | State-machine release tests exist; live system drag was not performed. |
| 7 | Scroll works | NOT TESTED | Scroll direction/state logic has unit coverage; live app scrolling was not performed. |
| 8 | Window move and resize work | NOT TESTED | AX geometry/state tests exist; target-app behavior was not performed. |
| 9 | App switching works | NOT TESTED | App activation was not verified interactively. |
| 10 | Air Keyboard appears | NOT TESTED | Panel code builds and unit tests pass; live overlay/fullscreen behavior was not checked. |
| 11 | Text and editing keys work | NOT TESTED | Synthetic events require Accessibility and a target app. |
| 12 | Korean IME input works | NOT TESTED | Must be checked with the user's active macOS input source in a real text field. |
| 13 | Gestures do not conflict | NOT TESTED | Deterministic unit tests pass; simultaneous live modes were not exercised. |
| 14 | Tracking loss is safe | PASS | Unit tests cover drag release, keyboard recognizer reset, and stop cleanup; physical tracking-loss behavior remains unverified. |
| 15 | Emergency stop works | NOT TESTED | Escape handling is implemented; no live event session was used. |
| 16 | Settings persist | PASS | Calibration profile round-trip is unit tested; full UI settings persistence was not manually checked. |
| 17 | macOS build succeeds | PASS | Tuist generation and Debug test build passed; Release build passed. |
| 18 | Automated tests pass | PASS | Latest suite: 69 passed, 0 failed, 0 skipped. Includes camera permission-state presentation, paired mouse event safety, double-click action/cooldown/event-state sequence, bounded frame buffering, Korean Dubeolsik mapping, camera selection fallback, and lifecycle generation tests; camera start/stop hardware races, live camera enumeration/capture, live permission transitions, latency, and Korean IME composition remain NOT TESTED. |
| 19 | Documentation is current | PASS | README and architecture, development, gesture, calibration, testing, troubleshooting, release, keyboard, and QA docs are present. |
| 20 | Local app bundle is ready | PASS | Latest Release `.app` and ZIP are at `/Users/isiu/Desktop/AirControl-builds/Release-2026-11-01-r4/`. Info.plist, ZIP extraction, and universal x86_64/arm64 executable were verified; bundle ID is `com.dltldn1234.AirControl`, minimum macOS is 14.0, and ZIP SHA-256 is `00d4ea7563db56a8327857128a59a0fa20d42ae709e2357f25caa810256b3598`. Bundle has an ad-hoc linker signature; Developer ID signing/notarization is not included. This r4 artifact was not launch-smoke-tested. |

## Phase status

- Camera lifecycle follow-up #41: stale start completion is generation-guarded and teardown blocks duplicate starts; permission-dialog race remains NOT TESTED with physical AVFoundation capture.

- Camera selection #39: built-in/external device picker and safe device fallback are implemented in source; real device enumeration and switching are NOT TESTED.
- Configurable double-click #43: pinch mapping and CoreGraphics click-state sequence have unit/build coverage; live Accessibility event delivery is NOT TESTED.
- Paired click dispatch #45: both button events are constructed before either is posted; unit coverage verifies incomplete pairs post nothing. Live Accessibility dispatch is NOT TESTED.
- Camera permission presentation #50: General and Camera settings share accurate AVFoundation authorization copy, and General refreshes after app activation; permission transition behavior is covered by unit tests but has not been changed through the live System Settings UI.
- Accessibility permission refresh #52: General settings refreshes AX trust on appearance and app activation and after the explicit request action; the live transition through System Settings remains NOT TESTED.

- Performance follow-up #35: bounded latest-frame queue is covered by unit tests; before/after camera latency and CPU comparison remains NOT TESTED.

- Phase 0: PASS — repository, project, and workflow audited.
- Phases 1–7: IMPLEMENTED IN SOURCE — build and deterministic tests pass; cursor smoothing, calibration, per-pinch action mapping, conflict feedback, and safe settings export/import are included. Camera, system input, AX, IME, and multi-display interaction remain manually unverified.
- Phase 8: PARTIAL — menu status guidance, rejected-toggle recovery, and project docs are improved. The full screen-by-screen visual/accessibility design audit is not complete.
- Phases 9–10: PARTIAL — camera stop/frame queue cleanup, metrics guards, tests, and a manual-dispatch macOS workflow are implemented. The remote workflow has not been dispatched.
- Phase 11: PASS FOR LOCAL PACKAGE — Release `.app` and ZIP are available; signed/notarized distribution is not prepared.
- Phase 12: PASS — requested project documentation has been added.
- Phase 13: PASS FOR MERGED WORK — Issues, issue-numbered branches, focused commits, PRs, and merge commits used; no force pushes.
- Phase 14: PARTIAL — matrix and software verification are recorded; physical interaction checks remain NOT TESTED.
