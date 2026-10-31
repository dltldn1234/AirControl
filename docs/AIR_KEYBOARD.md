# Air Keyboard

Air Keyboard is an opt-in camera input mode. It reuses the existing Vision hand joints and treats the index fingertip as the pointer. A thumb-index pinch selects the highlighted key once; the pinch must be released before another selection can occur.

## Start and stop

1. Start the camera from the menu bar panel.
2. Grant AirControl Accessibility access in **System Settings → Privacy & Security → Accessibility**.
3. Turn on **Enable Air Keyboard**. The floating panel appears without becoming the key or main window.
4. Move the index fingertip over a key and pinch briefly. Turn the mode off, stop the camera, or use **Emergency Stop · Esc** to stop input.

While Air Keyboard is active, cursor and window gesture processing is paused. Existing cursor-control preference is retained and resumes when the keyboard mode ends. Air Keyboard is OFF when the app launches.

## Layout and input

The layout is data-driven and includes English QWERTY and Korean Dubeolsik labels, number/symbol keys, Space, Enter, Backspace, Shift, Caps Lock, and an input-source shortcut. Shift is a one-key sticky modifier. Key events use physical macOS virtual key codes so the active input source can perform normal text composition.

The **한/영** key sends Control-Space. Its effect depends on the input-source shortcut configured in macOS. Select or configure the Korean Dubeolsik input source in macOS before expecting Korean IME composition. AirControl does not insert text through the clipboard and does not record typed content.

Accessibility permission is checked before each event. The input engine skips a focused accessibility element whose subrole identifies it as a secure text field. Secure-field identification depends on the target app's Accessibility implementation; do not use Air Keyboard for passwords or other secrets.

## Settings

Settings stores keyboard scale, opacity, key-selection sensitivity, selected layout, and input feedback in UserDefaults. The keyboard can be dragged by its background and resized from its window edges. **Reset Keyboard Position** returns it to the bottom center of its screen.

## Verification boundaries

Automated tests cover layout rows, key-code mapping, mirrored coordinate mapping, key hit testing and boundary hysteresis, pinch de-duplication, tracking-loss reset, permission gating, and cursor-mode suppression. They do not prove that a particular app retains focus, that Control-Space matches the user's macOS shortcut, or that Korean IME composition works in that app. Verify those behaviors manually in a normal text field before regular use. Full-screen-space behavior and multiple-display hand calibration also need manual checks.
