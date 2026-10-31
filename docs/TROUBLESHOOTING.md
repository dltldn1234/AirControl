# Troubleshooting

## Camera cannot start

Check **System Settings → Privacy & Security → Camera** for AirControl. Quit and reopen the app after changing access. Another app may be holding the camera.

If macOS temporarily interrupts camera capture, AirControl reports the interruption and releases active gestures. A fatal capture error stops the camera and disables cursor and keyboard input; start the camera again after resolving the reported condition.

## Cursor control does not enable

Start the camera, then allow AirControl in **System Settings → Privacy & Security → Accessibility**. Return to AirControl and try again. The app intentionally sends no cursor events without authorization.

## Pointer feels inverted or reaches screen edges too early

Use Settings → Calibration to set the mirrored coordinate mode and comfortable movement area. Keep the hand and wrist visible and well lit. Reset calibration to restore defaults.

## A window does not move or resize

Some apps do not expose writable window position or size attributes through macOS Accessibility. AirControl skips unsupported windows; it does not bypass macOS security.

## Gesture tracking is unstable

Center the hand in view, avoid strong backlighting, and keep the index fingertip visible. Reduce cursor sensitivity or increase smoothing. Stop and restart the camera if capture state becomes stale.
