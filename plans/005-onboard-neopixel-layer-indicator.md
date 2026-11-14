# Plan 005: Light the XIAO's onboard NeoPixel in a per-layer color

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git -C /Users/ysabhiram/Desktop/rp2040 diff --stat baseline-2026-11-14..HEAD -- code.py layer_led.py lib/`
> `code.py` will have changed from plans 002–004. Confirm it contains
> `MEDIA, CODE, MEET = 0, 1, 2` and a line `kbd.modules = [layers, macros, encoder_handler]`.
> `layer_led.py` must not exist yet. Any other mismatch is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/003-real-keymap-with-layers-and-macros.md (004 is not required)
- **Category**: direction
- **Planned at**: tag `baseline-2026-11-14`, 2026-11-14

## Why this matters

The OLED shows the layer (plan 004), but it dims after 20 s and turns off after 60 s.
The Seeed XIAO RP2040 has a WS2812 NeoPixel soldered on the board. It needs no wiring
and none of the 11 header pins, all of which are taken. A dim, always-on color dot
(blue = MEDIA, green = CODE, red = MEET) is a layer indicator that never sleeps.
Red for the meeting layer also works as a "you're in call mode" cue.

## Current state

- Board: Seeeduino XIAO RP2040, CircuitPython 10.0.0 (`boot_out.txt`). In CircuitPython's
  board definition the onboard NeoPixel is `board.NEOPIXEL` (GPIO12), and its power-enable
  pin is `board.NEOPIXEL_POWER` (GPIO11, must be driven high).
- `lib/` currently has NO `neopixel.mpy`. Contents: `adafruit_display_text/`,
  `adafruit_displayio_ssd1306.mpy`, three `.bmp` files.
- KMK module contract, `kmk/modules/__init__.py:5-45`: a `Module` subclass must implement
  `during_bootup`, `before_matrix_scan`, `after_matrix_scan`, `before_hid_send`,
  `after_hid_send`, `on_powersave_enable`, `on_powersave_disable` (the base methods raise
  `NotImplementedError`). `deinit` is optional. Each hook receives `keyboard`, and the active
  layer is `keyboard.active_layers[0]`.
- Safety net: `kmk/kmk_keyboard.py:315-327`. If a module's `during_bootup` raises, KMK logs it
  and drops that module, and the keyboard keeps working. So a wrong pin name can't brick input.
- Exemplar of a small module that only reacts to state: `kmk/modules/mouse_jiggler.py` (look at its hook layout).

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Library present | `ls /Users/ysabhiram/Desktop/rp2040/lib/neopixel.mpy` | file exists |
| Syntax | `python3 -m py_compile /Users/ysabhiram/Desktop/rp2040/code.py /Users/ysabhiram/Desktop/rp2040/layer_led.py` | exit 0 |
| Pin names (human, on device REPL) | in `screen /dev/tty.usbmodem* 115200`, press Ctrl-C then Enter, then type `import board; print(board.NEOPIXEL, board.NEOPIXEL_POWER)` | prints two pin objects, no `AttributeError`; press Ctrl-D to reboot afterwards |

## Scope

**In scope**:
- `layer_led.py` (create, project root)
- `code.py`
- `lib/neopixel.mpy` (added by the human, see Step 1)

**Out of scope**:
- `kmk/extensions/rgb.py`. KMK's RGB extension is built for LED strips with animations. It's overkill for one status pixel and its keys aren't needed here.
- Any change to the keymap or encoder map.

## Git workflow

- Branch `advisor/005-neopixel-layer-led`; commit `feat: onboard NeoPixel shows active layer`. Do not push.

## Steps

### Step 1: Get `neopixel.mpy` (human step)

The executor must not download files. Ask the user to:
1. Download the **Adafruit CircuitPython Library Bundle for version 10.x** from https://circuitpython.org/libraries.
2. Copy `lib/neopixel.mpy` from the unzipped bundle into `/Users/ysabhiram/Desktop/rp2040/lib/`.

**Verify**: `ls -l /Users/ysabhiram/Desktop/rp2040/lib/neopixel.mpy` → file exists and is larger than 1 KB. If it doesn't exist, STOP and wait for the user.

### Step 2: Create `layer_led.py`

```python
'''Onboard NeoPixel that shows the active KMK layer as a color.'''

import board
import digitalio
import neopixel

from kmk.modules import Module


class LayerLed(Module):
    def __init__(self, colors, brightness=0.05):
        # colors: tuple of (r, g, b), indexed by layer number
        self.colors = colors
        self.brightness = brightness
        self._last_layer = None
        self._pixel = None
        self._power = None

    def during_bootup(self, keyboard):
        self._power = digitalio.DigitalInOut(board.NEOPIXEL_POWER)
        self._power.switch_to_output(value=True)
        self._pixel = neopixel.NeoPixel(
            board.NEOPIXEL, 1, brightness=self.brightness, auto_write=True
        )

    def before_matrix_scan(self, keyboard):
        layer = keyboard.active_layers[0]
        if layer != self._last_layer:
            self._last_layer = layer
            self._pixel[0] = self.colors[layer % len(self.colors)]

    def after_matrix_scan(self, keyboard):
        return

    def before_hid_send(self, keyboard):
        return

    def after_hid_send(self, keyboard):
        return

    def on_powersave_enable(self, keyboard):
        self._pixel[0] = (0, 0, 0)

    def on_powersave_disable(self, keyboard):
        self._last_layer = None  # force a repaint on the next scan

    def deinit(self, keyboard):
        if self._pixel:
            self._pixel.deinit()
        if self._power:
            self._power.deinit()
```

**Verify**: `python3 -m py_compile /Users/ysabhiram/Desktop/rp2040/layer_led.py` → exit 0

### Step 3: Wire it into `code.py`

1. Add `from layer_led import LayerLed` to the project-local import group (next to `from macropad_display import LayerDisplay` if plan 004 landed, or else right after the `kmk.*` imports).
2. Right after the line `MEDIA, CODE, MEET = 0, 1, 2`, add:

```python
LAYER_COLORS = ((0, 80, 255), (0, 255, 0), (255, 0, 0))  # MEDIA blue, CODE green, MEET red
```

3. Change `kbd.modules = [layers, macros, encoder_handler]` to:

```python
layer_led = LayerLed(LAYER_COLORS)
kbd.modules = [layers, macros, encoder_handler, layer_led]
```

   `LAYER_COLORS` must be defined above this line. If the layer constants are still below the modules section (plan 004 not applied), move the constants block up first, as plan 004 Step 2 describes.

**Verify**:
- `python3 -m py_compile code.py layer_led.py` → exit 0
- `grep -n "LAYER_COLORS = " code.py` shows a line number smaller than `grep -n "LayerLed(LAYER_COLORS)" code.py`

### Step 4: On-device check (human)

1. Run the REPL pin check from the Commands table. Then reboot with Ctrl-D.
2. After boot, the onboard LED is dim blue. Press the encoder: green. Press again: red. Again: blue.
3. Keys and encoder still work as in plan 003.
4. Serial shows no `during_bootup` error mentioning `LayerLed`.

## Test plan

- Host: `py_compile`, plus the ordering grep.
- Device: the Step 4 checklist.

## Done criteria

- [ ] `lib/neopixel.mpy` exists
- [ ] `layer_led.py` exists and compiles
- [ ] `code.py` compiles and includes `layer_led` in `kbd.modules`
- [ ] `git diff --stat -- kmk/` → empty
- [ ] `plans/README.md` status row updated

## STOP conditions

- `lib/neopixel.mpy` is missing after asking the user.
- The REPL check raises `AttributeError` for `NEOPIXEL` or `NEOPIXEL_POWER`. The board definition differs from what this plan assumes, so report `dir(board)` output instead of guessing GPIO numbers.
- The LED stays off but serial shows no error. Report it; don't try other pins.

## Maintenance notes

- `LAYER_COLORS` must have at least as many entries as layers. The `%` keeps it from crashing but wraps colors around.
- Brightness 0.05 is deliberately dim. A WS2812 at full brightness right next to an OLED is glaring.
- The XIAO also has a 3-color user LED (separate from the NeoPixel). It's unused, and this plan leaves it alone.
