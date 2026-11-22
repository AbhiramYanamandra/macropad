# Macropad (XIAO RP2040 + KMK)

A 9-key macropad with a rotary encoder, a 128×32 OLED and the XIAO's onboard
RGB LED, running KMK on CircuitPython. What every key does lives in `keymap.json`,
which you edit with **Macropad Studio**, a G Hub-style app that runs in your browser.

## Customise it: Macropad Studio

1. Open `configurator/index.html` in **Chrome** (or Edge).
2. Click **Connect pad…** and choose the `CIRCUITPY` drive.
3. Click a key, the knob or the screen and pick what it does: shortcuts (or record
   one), media keys, typed text, multi-step macros, layer switching, or a separate
   action when the key is **held**.
4. **Combos**: press several keys together for another action (e.g. 1 + 3 = lock screen).
5. Press **▶ Try it** to see exactly what the pad will do: the OLED, the LED colour, and
   the keystrokes your computer would receive. You can use the number keys 1–9 for combos.
6. Click **Save to pad**. CircuitPython restarts and the new layout is live.

Safari and Firefox can't write to the drive. Use **Download keymap.json** and copy it onto `CIRCUITPY`.

## First-time install of this firmware

Copy these onto the `CIRCUITPY` drive (keep the existing `kmk/` and `lib/`):

```bash
rsync -av --exclude '.git' --exclude 'plans' --exclude 'configurator' --exclude '__pycache__' --exclude '.DS_Store' --exclude 'README.md' --exclude '.gitignore' /Users/ysabhiram/Desktop/Personal_Projects/rp2040/ /Volumes/CIRCUITPY/
```

Never add `--delete`. For the LED, also copy `neopixel.mpy` from the
[CircuitPython 10.x library bundle](https://circuitpython.org/libraries) into `CIRCUITPY/lib/`.
Without it everything else still works. Serial console: `screen /dev/tty.usbmodem* 115200` (quit with Ctrl-A then K).

## Files

| File | Role |
|---|---|
| `code.py` | Wiring only: pins, modules, display. Loads `keymap.json`. |
| `config_loader.py` | Turns `keymap.json` into KMK keys, macros, combos and hold actions. Falls back to a basic media layout if the file is broken. |
| `macropad_display.py` | Per-layer OLED screen, short text labels ("toasts"), wakes the screen on knob use. |
| `layer_led.py` | Onboard NeoPixel shows the layer colour. |
| `keymap.json` | Your layout (format: `configurator/FORMAT.md`). |
| `configurator/index.html` | Macropad Studio. |
| `plans/` | Upgrade plans written by the advisor review. |

## Hardware

Seeed XIAO RP2040, CircuitPython 10.0.0. All 11 GPIO pins are in use, so new parts must go on the I2C bus.

| Function | Pins |
|---|---|
| Matrix columns | D0, D2, D9 |
| Matrix rows | D1, D3, D8 (diodes COL2ROW) |
| Encoder A / B / button | D10 / D7 / D6 |
| OLED SSD1306 128×32 | SDA D4, SCL D5, address 0x3C, 400 kHz |
| Onboard NeoPixel | `board.NEOPIXEL` (GPIO12), power `board.NEOPIXEL_POWER` (GPIO11) |

Key positions 1–9 in the app are the keys that typed `1`–`9` in the original firmware.

## Local patches to vendored KMK

`kmk/extensions/display/ssd1306.py` imports `I2CDisplayBus` from `i2cdisplaybus`, because
CircuitPython 10 removed `displayio.I2CDisplay`. Reapply this after any KMK update.
`sh1106.py` is unpatched and unused.

## Rescue

If the pad misbehaves, use safe mode (it skips `code.py` and keeps the drive visible): press reset once
while the LED blinks right after plugging in. If that fails, hold BOOT while plugging in to get the
`RPI-RP2` drive and reflash CircuitPython. The pre-configurator firmware is saved in git:
`git checkout baseline-2026-11-14 -- code.py`.
