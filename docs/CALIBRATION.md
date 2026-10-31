# Calibration

Calibration is optional. Open Settings, start the camera, choose **Start Calibration**, then follow each prompt and capture the left, right, top, and bottom comfortable index-finger positions. Capture a relaxed open thumb-index pose and a comfortable pinch to derive separate pinch start and release thresholds.

The profile is stored in this macOS user's `UserDefaults`; camera frames are not saved. **Mirror camera coordinates** controls cursor mapping orientation. Reset restores default range and pinch thresholds. Re-run calibration if the camera, seating position, or typical hand distance changes.

The wizard uses normalized two-dimensional Vision joints and palm-relative pinch distance. It cannot infer reliable physical depth from a single camera. Complete a hands-on cursor check before relying on the saved values.
