# Plan 004: Show a different OLED image per layer, and wake the screen on layer change

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 diff --stat baseline-2026-11-14..HEAD -- code.py macropad_display.py lib/`
> `code.py` will have changed from plans 002/003. Confirm it contains
> `LAYER_NAMES = ("MEDIA", "CODE", "MEET")` and the Display block quoted below.
> `macropad_display.py` must not exist yet. Any other mismatch is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/003-real-keymap-with-layers-and-macros.md
- **Category**: direction
- **Planned at**: tag `baseline-2026-11-14`, 2026-11-14

## Why this matters

After plan 003 the macropad has three layers, but nothing shows which one is active.
`lib/` already holds three 128×32 1-bit images (`manandmountain.bmp`, `goku.bmp`,
`turbulence.bmp`), and only one is used. KMK's Display extension can already show a
different image per layer, so this is mostly configuration. There's one real
bug to work around. The screen dims after 20 s and turns off after 60 s of *matrix*
inactivity, and encoder actions (including the press that switches layers) aren't matrix
events. So switching layers with the encoder while the screen is asleep would leave it
dark, which defeats the point of a layer indicator.

## Current state

- `code.py` Display block after plans 002/003:

```python
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
```

  and, further down, `MEDIA, CODE, MEET = 0, 1, 2` plus `LAYER_NAMES = ("MEDIA", "CODE", "MEET")`.
  The layer constants are defined *below* the Display block. Step 2 moves them up.

- `kmk/extensions/display/__init__.py` (vendored, do not edit):
  - `render(self, layer)` (lines 152–181) builds a `displayio.Group` from entries where
    `entry.layer == layer or entry.layer is None`, then sets `self.display.root_group`.
  - `before_matrix_scan` (lines 206–211) calls `render(active_layers[0])` only when the layer changes.
  - `after_matrix_scan` (lines 213–215) resets `self.timer_start = ticks_ms()` only on
    `sandbox.matrix_update`. Encoder taps never set this.
  - `dim()` (lines 245–279) runs every 50 ms. When `ticks_diff(now, timer_start)` is under
    `dim_time_ms`, it restores brightness and calls `self.display.wake()`.
  - So resetting `timer_start` inside `render` is enough to wake the screen on the next `dim()` tick.
- `ImageEntry(image=...)` opens the file at construction (`displayio.OnDiskBitmap(image)`, line 66).
  A missing file raises `OSError` at import time, before `kbd.go()`.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Syntax | `python3 -m py_compile /Users/ysabhiram/Desktop/Personal_Projects/rp2040/code.py /Users/ysabhiram/Desktop/Personal_Projects/rp2040/macropad_display.py` | exit 0 |
| Images present | `ls /Users/ysabhiram/Desktop/Personal_Projects/rp2040/lib/*.bmp` | lists `goku.bmp`, `manandmountain.bmp`, `turbulence.bmp` |
| On-device (human) | deploy per `README.md` `## Deploy` | Step 4 checklist passes |

## Scope

**In scope**:
- `macropad_display.py` (create, at the project root next to `code.py`)
- `code.py`

**Out of scope**:
- `kmk/extensions/display/__init__.py`. It's vendored. Do the fix by subclassing in `macropad_display.py` so a KMK update can't undo it.
- Creating or editing BMP files.

## Git workflow

- Branch `advisor/004-per-layer-oled-art`; commit `feat: per-layer OLED images, wake on layer change`. Do not push.

## Steps

### Step 1: Create `macropad_display.py`

```python
'''Project-local display tweaks on top of KMK's Display extension.

Kept outside kmk/ so upgrading the vendored KMK can't drop them.
'''

from supervisor import ticks_ms

from kmk.extensions.display import Display


class LayerDisplay(Display):
    '''Display that counts a layer change as activity.

    KMK only resets the dim/off timer on matrix events. Encoder taps
    (including the layer-cycling press) are not matrix events, so without
    this the screen could stay asleep after switching layers.
    '''

    def render(self, layer):
        self.timer_start = ticks_ms()
        super().render(layer)
```

**Verify**: `python3 -m py_compile /Users/ysabhiram/Desktop/Personal_Projects/rp2040/macropad_display.py` → exit 0

### Step 2: Move the layer constants above the Display block

In `code.py`, move these two lines (and their comment) from just above the Keymap section to just below the imports, before `# ---- Keyboard + matrix`:

```python
# Layer indices: keep LAYER_NAMES in the same order as kbd.keymap
MEDIA, CODE, MEET = 0, 1, 2
LAYER_NAMES = ("MEDIA", "CODE", "MEET")
```

**Verify**: `grep -n "MEDIA, CODE, MEET = 0, 1, 2" code.py` shows a line number smaller than `grep -n "display_ext = " code.py`.

### Step 3: Use `LayerDisplay` with one image per layer

In `code.py`:
1. Remove `Display` from `from kmk.extensions.display import Display, ImageEntry` so it reads `from kmk.extensions.display import ImageEntry`.
2. Add `from macropad_display import LayerDisplay`, after the `kmk.*` imports as its own group.
3. Replace the Display block with:

```python
# ---- Display (SSD1306 128x32 on I2C D4/D5) ----------------------------
i2c = busio.I2C(scl=board.D5, sda=board.D4)
display_ext = LayerDisplay(
    display=SSD1306(i2c=i2c),
    entries=[
        ImageEntry(image="lib/manandmountain.bmp", x=0, y=0, layer=MEDIA),
        ImageEntry(image="lib/goku.bmp", x=0, y=0, layer=CODE),
        ImageEntry(image="lib/turbulence.bmp", x=0, y=0, layer=MEET),
    ],
    height=32,
)
kbd.extensions.append(display_ext)
```

**Verify**:
- `python3 -m py_compile code.py macropad_display.py` → exit 0
- `grep -c "ImageEntry(image=" code.py` → `3`
- `grep -c "Display(" code.py` → `1` (only `LayerDisplay(`)

### Step 4: On-device check (human)

1. Boot: the MEDIA image (`manandmountain`) shows. No `Traceback` on serial.
2. Press the encoder: the screen switches to `goku`. Press again: `turbulence`. Again: `manandmountain`.
3. Leave it alone for more than 60 s until the screen turns off, then press the encoder once. The screen turns on showing the next layer's image within about 0.1 s.

## Test plan

- Host: `py_compile` of both files, plus the grep checks above.
- Device: the Step 4 checklist. Item 3 is the regression test for the wake bug.

## Done criteria

- [ ] `macropad_display.py` exists and compiles
- [ ] `code.py` compiles, has 3 `ImageEntry` lines and uses `LayerDisplay`
- [ ] `git diff --stat -- kmk/` → empty
- [ ] `plans/README.md` status row updated

## STOP conditions

- On the device: `OSError: [Errno 2]` mentioning a `.bmp`. An image is missing on the drive (maybe it wasn't deployed), so report it rather than swapping images.
- On the device: `ImportError: no module named 'macropad_display'`. The file wasn't copied to the drive root. Check the deploy, and if it's there and still failing, STOP.
- The screen does NOT wake in check 3. Report it with serial output. Don't start editing `kmk/`.

## Maintenance notes

- Swapping art: any 128×32, 1-bit (monochrome) BMP in `lib/` works. Larger images get clipped.
- Plan 006 extends `LayerDisplay` with a text toast. Keep the class in `macropad_display.py`.
- Turning the encoder (volume) still doesn't wake the screen, only layer changes do. Plan 006 addresses that.
