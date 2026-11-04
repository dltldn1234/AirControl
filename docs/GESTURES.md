# Gestures

Cursor and window control are opt-in. Start the camera first; enable cursor control in the menu bar panel or Settings. Press Escape in the control panel for emergency stop.

| Gesture | Current action | Notes |
| --- | --- | --- |
| Index fingertip movement | Move pointer | Requires a confidently tracked index tip. |
| Brief thumb-index pinch and release | Left click | A held pinch crosses the configurable drag delay and starts dragging. |
| Brief pinch mapped to Double click | Double click | Posts a native two-click sequence; the same click cooldown prevents repeated activation. |
| Release after a drag | End drag | Tracking loss and stop also release the held button. |
| Index and middle fingers extended, vertical motion | Scroll | Cursor motion is suppressed while scrolling. |
| Thumb-middle pinch and release | Right click | Controlled by the right-click settings. |
| Open palm held | Enter window-control mode | Requires the setting and Accessibility permission. |
| Pinch and move in window mode | Move selected/focused window | Depends on AX support from the target app. |
| Two tracked open hands | Resize window | Requires two-hand resizing to be enabled. |
| Three-finger horizontal swipe | Switch visible regular app | Does not switch Spaces or full-screen desktops. |
| Hand keyboard mode | Select and activate virtual key | Keyboard is opt-in and independent of cursor input. |

Gesture thresholds and behavior can vary with camera framing, lighting, hand pose, and Vision confidence. Use Settings to tune supported sensitivities and calibrate the cursor range. Pinch and scroll actions are gated by a configurable minimum landmark-confidence threshold; if confidence falls during a pinch, a pending click is cancelled and any active drag is released.

Settings lets you map thumb-index and thumb-middle pinches independently to left click, double click, right click, drag, or disabled. Drag follows the configured hold delay. If both pinches use the same action, Settings shows a duplicate-mapping warning; the closer recognized pinch source determines which mapping is active. Synthetic click actions require Accessibility permission and are not sent while cursor control is off.
