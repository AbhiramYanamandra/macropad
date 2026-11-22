# Plan 006: Show short text "toasts" on the OLED (layer name, encoder action)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 diff --stat baseline-2026-11-14..HEAD -- code.py macropad_display.py`
> Both will have changed (plans 002–004). Confirm `macropad_display.py` matches
> the "Current state" excerpt exactly, and that `code.py` uses `LayerDisplay(`
> and `EncoderHandler()`. Any mismatch is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED (display refresh timing could make the encoder feel laggy; there's a fallback)
- **Depends on**: plans/004-per-layer-oled-art.md
- **Category**: direction
- **Planned at**: tag `baseline-2026-11-14`, 2026-11-14

## Why this matters

After plan 004 the OLED shows a different picture per layer, but a picture doesn't
name the layer. Turning the encoder also gives no feedback and doesn't wake the screen.
This plan overlays a small inverted text tag in the bottom-right corner of the screen.
It shows the layer name (`MEDIA` / `CODE` / `MEET`) for about 1.2 s after a layer change,
and the action (`VOL+`, `ZOOM-`, ...) on each encoder turn. Encoder turns also wake the screen.

## Current state

`/Users/ysabhiram/Desktop/Personal_Projects/rp2040/macropad_display.py` (created by plan 004):

```python
'''Project-local display tweaks on top of KMK's Display extension.

Kept outside kmk/ so upgrading the vendored KMK can't drop them.
'''

from supervisor import ticks_ms

from kmk.extensions.display import Display


class LayerDisplay(Display):
    ...
    def render(self, layer):
        self.timer_start = ticks_ms()
        super().render(layer)
```

`code.py` (after plans 002–004, relevant parts):

```python
from kmk.modules.encoder import EncoderHandler
...
MEDIA, CODE, MEET = 0, 1, 2
LAYER_NAMES = ("MEDIA", "CODE", "MEET")
...
encoder_handler = EncoderHandler()
encoder_handler.pins = ((board.D10, board.D7, board.D6),)  # (A, B, button)
...
i2c = busio.I2C(scl=board.D5, sda=board.D4)
display_ext = LayerDisplay(
    display=SSD1306(i2c=i2c),
    entries=[ ...3 ImageEntry lines... ],
    height=32,
)
...
encoder_handler.map = [
    ((KC.VOLD, KC.VOLU, KC.TO(CODE)),),                    # MEDIA
    ((KC.LCMD(KC.MINS), KC.LCMD(KC.EQL), KC.TO(MEET)),),   # CODE: zoom out/in
    ((KC.VOLD, KC.VOLU, KC.TO(MEDIA)),),                   # MEET
]
```

Vendored facts (do not edit these files):
- `kmk/extensions/display/__init__.py`. `Display.render` (152–181) creates a new
  `displayio.Group` and sets it as `self.display.root_group`. The `self.display` wrapper
  exposes `root_group` as a get/set property (lines 100–106), so after `super().render()`
  you can `self.display.root_group.append(...)`. `before_matrix_scan(self, sandbox)`
  (206–211) handles dimming and re-rendering. `self.width` and `self.height` are 128 and 32.
  It already imports `terminalio` and `from adafruit_display_text import label`, and the
  library is in `lib/adafruit_display_text/`.
- `kmk/modules/encoder.py:292-301`. `EncoderHandler.on_move_do(self, keyboard, encoder_id, state)`
  is called as a bound method (via a lambda at lines 280–283), so a subclass override works.
  `state['direction']` is `-1` for counter-clockwise and `1` for clockwise.
- `kmk/kmktime.py` provides `ticks_diff` (used by the display extension).
- `label.Label` is a `displayio.Group` subclass, so `.hidden = True/False` shows or hides it.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Syntax | `python3 -m py_compile /Users/ysabhiram/Desktop/Personal_Projects/rp2040/code.py /Users/ysabhiram/Desktop/Personal_Projects/rp2040/macropad_display.py` | exit 0 |
| Shape check | Step 4 snippet | prints `OK` |
| On-device (human) | deploy per `README.md` `## Deploy` | Step 5 checklist passes |

## Scope

**In scope**: `macropad_display.py`, `code.py`.

**Out of scope**: everything under `kmk/`; the keymap and encoder key assignments; `layer_led.py`.

## Git workflow

- Branch `advisor/006-oled-toasts`; commit `feat: OLED toasts for layer name and encoder actions`. Do not push.

## Steps

### Step 1: Add toast support to `LayerDisplay`

Replace the body of `macropad_display.py` below the docstring with:

```python
from supervisor import ticks_ms

import terminalio
from adafruit_display_text import label

from kmk.extensions.display import Display
from kmk.kmktime import ticks_diff
from kmk.modules.encoder import EncoderHandler


class LayerDisplay(Display):
    '''Display that counts a layer change as activity and can show a
    short inverted text "toast" in the bottom-right corner.
    '''

    def __init__(self, *args, layer_names=None, toast_ms=1200, **kwargs):
        super().__init__(*args, **kwargs)
        self.layer_names = layer_names
        self.toast_ms = toast_ms
        self._toast = None
        self._toast_at = 0

    def render(self, layer):
        self.timer_start = ticks_ms()
        super().render(layer)
        # render() replaced root_group, so attach a fresh toast label to it
        self._toast = label.Label(
            terminalio.FONT,
            text=' ',
            color=0x000000,
            background_color=0xFFFFFF,
            anchor_point=(1.0, 1.0),
            anchored_position=(self.width - 1, self.height - 1),
            padding_left=1,
            padding_right=1,
        )
        self._toast.hidden = True
        self.display.root_group.append(self._toast)
        if self.layer_names and 0 <= layer < len(self.layer_names):
            self.show_toast(self.layer_names[layer])

    def show_toast(self, text):
        if self._toast is None:
            return
        self._toast.text = text
        self._toast.hidden = False
        self._toast_at = ticks_ms()
        self.timer_start = self._toast_at  # counts as activity: wakes the screen

    def before_matrix_scan(self, sandbox):
        super().before_matrix_scan(sandbox)
        if (
            self._toast is not None
            and not self._toast.hidden
            and ticks_diff(ticks_ms(), self._toast_at) > self.toast_ms
        ):
            self._toast.hidden = True


class ToastEncoderHandler(EncoderHandler):
    '''EncoderHandler that also shows a toast for each turn.

    toast_display: a LayerDisplay. labels: per layer, (ccw_text, cw_text).
    Both are set after construction, because code.py builds the display
    after the modules.
    '''

    def __init__(self):
        super().__init__()
        self.toast_display = None
        self.labels = None

    def on_move_do(self, keyboard, encoder_id, state):
        super().on_move_do(keyboard, encoder_id, state)
        if self.toast_display is None or not self.labels:
            return
        layer = keyboard.active_layers[0]
        if layer < len(self.labels):
            text = self.labels[layer][0 if state['direction'] == -1 else 1]
            self.toast_display.show_toast(text)
```

Keep the module docstring at the top of the file.

**Verify**: `python3 -m py_compile /Users/ysabhiram/Desktop/Personal_Projects/rp2040/macropad_display.py` → exit 0

### Step 2: Use the new classes in `code.py`

1. Change `from macropad_display import LayerDisplay` to `from macropad_display import LayerDisplay, ToastEncoderHandler`.
2. Delete the line `from kmk.modules.encoder import EncoderHandler`, which is now unused.
3. Change `encoder_handler = EncoderHandler()` to `encoder_handler = ToastEncoderHandler()`.
4. In the `LayerDisplay(...)` call, add the keyword argument `layer_names=LAYER_NAMES,`.
5. Directly below the encoder map assignment (`encoder_handler.map = [...]`), add:

```python
# Toast text per layer: (counter-clockwise, clockwise); same order as the map
ENCODER_LABELS = (("VOL-", "VOL+"), ("ZOOM-", "ZOOM+"), ("VOL-", "VOL+"))
encoder_handler.labels = ENCODER_LABELS
encoder_handler.toast_display = display_ext
```

**Verify**:
- `python3 -m py_compile code.py macropad_display.py` → exit 0
- `grep -c "EncoderHandler()" code.py` → `1` (only `ToastEncoderHandler()`)
- `grep -c "from kmk.modules.encoder import" code.py` → `0`

### Step 3: Raise the I2C clock to 400 kHz

Each toast redraws part of the screen. At the default 100 kHz I2C clock, a redraw can stall
the main loop long enough to drop encoder steps. SSD1306 modules support 400 kHz. Change:

```python
i2c = busio.I2C(scl=board.D5, sda=board.D4)
```
to
```python
i2c = busio.I2C(scl=board.D5, sda=board.D4, frequency=400_000)
```

**Verify**: `grep -c "frequency=400_000" code.py` → `1`

### Step 4: Host-side shape check

From `/Users/ysabhiram/Desktop/Personal_Projects/rp2040`:

```bash
python3 - <<'EOF'
import ast
tree = ast.parse(open("code.py").read())
vals = {}
for n in ast.walk(tree):
    if isinstance(n, ast.Assign):
        t = n.targets[0]
        if isinstance(t, ast.Name): vals[t.id] = n.value
        if isinstance(t, ast.Attribute) and t.attr in ("keymap", "map"): vals[t.attr] = n.value
assert len(vals["ENCODER_LABELS"].elts) == len(vals["map"].elts) == len(vals["keymap"].elts) == len(vals["LAYER_NAMES"].elts)
assert all(len(p.elts) == 2 for p in vals["ENCODER_LABELS"].elts)
print("OK")
EOF
```

**Verify**: prints `OK`.

### Step 5: On-device check (human)

1. Boot: the MEDIA image shows with a `MEDIA` tag bottom-right that disappears after about 1 s. No `Traceback`.
2. Turn the encoder clockwise: volume goes up and `VOL+` flashes. Turn it quickly through 10 detents: the volume changes by about 10 steps (none dropped).
3. Press the encoder: the image changes and `CODE` flashes. Turn it: `ZOOM+` / `ZOOM-` flash.
4. Wait more than 60 s until the screen is off, then turn the encoder: the screen wakes.

## Test plan

- Host: `py_compile` plus the Step 4 AST check (keeps `ENCODER_LABELS` in sync with the layers).
- Device: the Step 5 checklist. Item 2 is the lag regression test, and item 4 is the wake test.

## Done criteria

- [ ] Both files compile; the Step 4 check prints `OK`
- [ ] `grep -c "ToastEncoderHandler()" code.py` → `1`; `grep -c "layer_names=LAYER_NAMES" code.py` → `1`
- [ ] `git diff --stat -- kmk/` → empty
- [ ] `plans/README.md` status row updated

## STOP conditions

- Device: `AttributeError: 'NoneType' object has no attribute 'append'` from `render`. `root_group` isn't what this plan assumes, so report it.
- Device check 2 drops steps even at 400 kHz. Don't try to tune timing. Delete the `encoder_handler.toast_display = display_ext` line to turn off encoder toasts (layer-name toasts stay), and report it.
- Device: the display shows garbage or stays blank after the 400 kHz change. Revert just Step 3 and report. Some SSD1306 clones with long wires can't run at 400 kHz.

## Maintenance notes

- New layers need entries in `LAYER_NAMES`, `ENCODER_LABELS`, the keymap, the encoder map and `LAYER_COLORS` (plan 005). The Step 4 check covers the first four.
- A toast only refreshes part of the display. If someone later adds lots of text entries per layer, check for lag again.
- Deferred: showing the real host volume level would need the computer to send it (for example over USB serial). That's a separate, larger project.
