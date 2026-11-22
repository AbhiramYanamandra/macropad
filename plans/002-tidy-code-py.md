# Plan 002: Remove dead code from `code.py` and add a debug switch

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 diff --stat baseline-2026-11-14..HEAD -- code.py`
> If `code.py` changed since the baseline, compare the excerpts below against
> the live file. A mismatch is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-version-control-and-kmk-patch-record.md
- **Category**: tech-debt
- **Planned at**: tag `baseline-2026-11-14`, 2026-11-14

## Why this matters

`code.py` is the whole user-owned firmware. It has an unused import, commented-out
entries and loose `print` calls. It's also laid out in an order that makes the next
plans (layers, per-layer images, an LED) harder to drop in. Cleaning it up first keeps
the feature plans small and their diffs easy to review. There is no behavior change.

## Current state

`/Users/ysabhiram/Desktop/Personal_Projects/rp2040/code.py` (66 lines), key parts:

```python
1   print("Starting")
3   import board
4   import busio
5   from i2cdisplaybus import I2CDisplayBus      # unused in this file
...
30          # TextEntry(text="KMK Ready", x = 0, y = 0, layer = 0),
31          # TextEntry(text="Layer: 0", x = 0, y = 16, layer = 0),
32          ImageEntry(image="lib/manandmountain.bmp", x=0, y=0, layer=0),
...
62  print("Rows:", len(kbd.row_pins), "Cols:", len(kbd.col_pins))
63  print("Starting keyboard...")
65  if __name__ == "__main__":
66      kbd.go()
```

`TextEntry` is imported on line 13 but only used in the commented-out lines.
`I2CDisplayBus` is used inside `kmk/extensions/display/ssd1306.py`, not in `code.py`.
KMK's debug switch lives in `kmk/utils.py:15-48`. A module-global `_debug_enabled`
starts as `None`, which means "log automatically whenever a serial console is
connected". Setting `Debug().enabled = True/False` (the `enabled` setter on the
`Debug` class) forces it on or off. There is NO `kbd.debug_enabled` attribute in this KMK version.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Syntax | `python3 -m py_compile /Users/ysabhiram/Desktop/Personal_Projects/rp2040/code.py` | exit 0 |
| On-device (human) | deploy per README `## Deploy`, then open serial with `screen /dev/tty.usbmodem* 115200` | `Starting keyboard...` printed, no `Traceback`; keys still type 1–9; encoder still changes volume; OLED still shows the image |

## Scope

**In scope**: `code.py` only.

**Out of scope**: `kmk/**` (vendored library), `boot.py`, the keymap contents (plan 003 changes those).

## Git workflow

- Branch `advisor/002-tidy-code-py`; one commit `refactor: tidy code.py layout`. Do not push.

## Steps

### Step 1: Restructure `code.py` into labeled sections, same behavior

Rewrite `code.py` so it has this order and content. Every value must stay identical to the current file.

```python
import board
import busio

from kmk.extensions.display import Display, ImageEntry
from kmk.extensions.display.ssd1306 import SSD1306
from kmk.extensions.media_keys import MediaKeys
from kmk.keys import KC
from kmk.kmk_keyboard import KMKKeyboard
from kmk.modules.encoder import EncoderHandler
from kmk.modules.layers import Layers
from kmk.scanners import DiodeOrientation
from kmk.utils import Debug

# None = KMK logs only while a serial console is attached (KMK default);
# True/False forces logging on/off.
DEBUG = None
if DEBUG is not None:
    Debug().enabled = DEBUG

# ---- Keyboard + matrix -------------------------------------------------
kbd = KMKKeyboard()
kbd.col_pins = (board.D0, board.D2, board.D9)
kbd.row_pins = (board.D1, board.D3, board.D8)
kbd.diode_orientation = DiodeOrientation.COL2ROW

# ---- Modules / extensions ---------------------------------------------
layers = Layers()
encoder_handler = EncoderHandler()
encoder_handler.pins = ((board.D10, board.D7, board.D6),)  # (A, B, button)
kbd.modules = [layers, encoder_handler]
kbd.extensions.append(MediaKeys())

# ---- Display (SSD1306 128x32 on I2C D4/D5) ----------------------------
i2c = busio.I2C(scl=board.D5, sda=board.D4)
display_ext = Display(
    display=SSD1306(i2c=i2c),
    entries=[
        ImageEntry(image="lib/manandmountain.bmp", x=0, y=0, layer=0),
    ],
    height=32,
)
kbd.extensions.append(display_ext)

# ---- Keymap ------------------------------------------------------------
kbd.keymap = [
    [KC.N1, KC.N2, KC.N3, KC.N4, KC.N5, KC.N6, KC.N7, KC.N8, KC.N9],
]

# ---- Encoder map: one entry per layer: ((CCW, CW, press),) ------------
encoder_handler.map = [
    ((KC.VOLD, KC.VOLU, KC.MUTE),),
]

if __name__ == "__main__":
    print("Starting keyboard...")
    kbd.go()
```

Keep `"lib/manandmountain.bmp"` exactly as it is. The path is relative to the drive root.

**Verify**:
- `python3 -m py_compile /Users/ysabhiram/Desktop/Personal_Projects/rp2040/code.py` → exit 0
- `grep -c "I2CDisplayBus\|TextEntry\|# TextEntry" /Users/ysabhiram/Desktop/Personal_Projects/rp2040/code.py` → `0`
- `grep -o "board\.D[0-9]*" /Users/ysabhiram/Desktop/Personal_Projects/rp2040/code.py | wc -l` → `11` (6 matrix + 3 encoder + 2 I2C pins)

### Step 2: On-device check (human)

Ask the user to deploy and confirm the behavior hasn't changed (see the Commands table). If you can't reach the device, mark the plan `DONE (device check pending)` and list the exact checks for the user.

## Test plan

There is no host test harness: the code imports `board`, which only exists on CircuitPython. The verification is `py_compile` plus the on-device checklist.

## Done criteria

- [ ] `py_compile` exits 0
- [ ] `grep -o "board\.D[0-9]*" code.py | wc -l` → `11`
- [ ] `grep -c "I2CDisplayBus" code.py` → `0`
- [ ] `git diff --stat baseline-2026-11-14 -- . ':!code.py' ':!plans'` → empty
- [ ] `plans/README.md` status row updated

## STOP conditions

- On the device, the serial output shows `ImportError` or the display stays blank after this change. Revert with `git checkout baseline-2026-11-14 -- code.py` and report.
- You feel the need to edit anything under `kmk/`.

## Maintenance notes

- Plans 003–006 add code into the labeled sections. Keep the section headers.
- The `print("Starting")` that used to run before the imports is gone. If boot hangs during an import, set `DEBUG = True` or temporarily add a print back.
