# Plan 003: Replace the 1–9 placeholder keymap with three useful layers (Media / Code / Meet)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git -C ~/Desktop/Personal_Projects/rp2040 diff --stat baseline-2026-11-14..HEAD -- code.py`
> If plan 002 has landed, `code.py` will show as changed. That's expected:
> check that it matches the "Current state" excerpt below (the post-002
> layout). Any other mismatch is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-version-control-and-kmk-patch-record.md, plans/002-tidy-code-py.md
- **Category**: direction
- **Planned at**: tag `baseline-2026-11-14`, 2026-11-14

## Why this matters

Right now the macropad's 9 keys type the digits `1`–`9`, and there's only one layer.
That's a wiring test, not a useful macropad. The `Layers` module is loaded but never
used. This plan adds three layers of real shortcuts for macOS (the user's computer is
a Mac): media/system, VS Code, and video calls. Pressing the encoder cycles through the
layers. Plans 004–006 build on the layer list and the `LAYER_NAMES` constant this plan adds.

## Current state

`~/Desktop/Personal_Projects/rp2040/code.py` after plan 002 (relevant parts):

```python
from kmk.modules.layers import Layers
...
layers = Layers()
encoder_handler = EncoderHandler()
encoder_handler.pins = ((board.D10, board.D7, board.D6),)  # (A, B, button)
kbd.modules = [layers, encoder_handler]
kbd.extensions.append(MediaKeys())
...
# ---- Keymap ------------------------------------------------------------
kbd.keymap = [
    [KC.N1, KC.N2, KC.N3, KC.N4, KC.N5, KC.N6, KC.N7, KC.N8, KC.N9],
]

# ---- Encoder map: one entry per layer: ((CCW, CW, press),) ------------
encoder_handler.map = [
    ((KC.VOLD, KC.VOLU, KC.MUTE),),
]
```

KMK facts this plan depends on (verified in the vendored source):

- **The encoder map MUST have exactly one entry per keymap layer.** `kmk/modules/encoder.py:292-307`
  looks up `self.map[layer_id][encoder_id][index]` where `layer_id = keyboard.active_layers[0]`,
  so a missing layer raises `IndexError` as soon as the encoder is turned on that layer.
- The encoder button sends its key with `keyboard.tap_key(key)` (`encoder.py:303-307`). Tapping
  `KC.TO(n)` switches to layer `n`, so cycling works with no custom code: layer 0's button
  is `KC.TO(1)`, layer 1's is `KC.TO(2)`, and layer 2's is `KC.TO(0)`.
- Layer keys `KC.MO`, `KC.TG`, `KC.TO`, `KC.DF`, `KC.LT` come from `kmk/modules/layers.py:39-80`.
- Modifier combos work as `KC.LCMD(KC.C)` (Cmd+C), nested `KC.LCMD(KC.LSFT(KC.P))`
  (Cmd+Shift+P). Modifier names in `kmk/keys.py:137-140`: `LCTL`, `LSFT`, `LALT`/`LOPT`, `LCMD`/`LGUI`.
- Key names verified in `kmk/keys.py`: `GRV`, `SLSH`, `MINS`, `EQL`, `SPC`, `UP`, `F5`, `ESC`, letters `A`–`Z`, digits `N1`–`N9`.
- Media keys from `kmk/extensions/media_keys.py:18-31`: `MUTE`, `VOLU`, `VOLD`, `MNXT`, `MPRV`, `MPLY`, `BRIU`, `BRID`.
- Typed strings use the Macros module: `from kmk.modules.macros import Macros`, add an instance
  to `kbd.modules`, then `KC.MACRO("text")`. `MacroIter` (`kmk/modules/macros.py:114-160`)
  types ASCII characters and shifts uppercase letters automatically.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Syntax | `python3 -m py_compile ~/Desktop/Personal_Projects/rp2040/code.py` | exit 0 |
| Shape check | the Python snippet in Step 3 | prints `OK 3 layers` |
| On-device (human) | deploy per `README.md` `## Deploy`, then `screen /dev/tty.usbmodem* 115200` | no `Traceback`; checklist in Step 4 passes |

## Scope

**In scope**: `code.py` only.

**Out of scope**: `kmk/**`, `boot.py`, the display entries (plan 004 changes them), and any LED code (plan 005).

## Git workflow

- Branch `advisor/003-real-keymap`; commit `feat: three-layer keymap with encoder layer cycling`. Do not push.

## Steps

### Step 1: Add the Macros module and layer names

In `code.py`:

1. Add `from kmk.modules.macros import Macros` to the import block (keep imports alphabetical by module path, matching the existing order).
2. In the "Modules / extensions" section, create `macros = Macros()` and change the modules line to
   `kbd.modules = [layers, macros, encoder_handler]`.
3. Just above the Keymap section, add:

```python
# Layer indices: keep LAYER_NAMES in the same order as kbd.keymap
MEDIA, CODE, MEET = 0, 1, 2
LAYER_NAMES = ("MEDIA", "CODE", "MEET")
```

**Verify**: `python3 -m py_compile ~/Desktop/Personal_Projects/rp2040/code.py` → exit 0

### Step 2: Replace the keymap and encoder map

Replace the whole Keymap section and Encoder map section with this. The comments give each key's physical position as it maps today: position `i` is the key that currently types digit `i+1`.

```python
# ---- Keymap ------------------------------------------------------------
# Positions 0..8 = the keys that typed 1..9 before this change.
kbd.keymap = [
    # MEDIA: media + macOS system
    [
        KC.MPRV,              KC.MPLY,              KC.MNXT,
        KC.LCMD(KC.C),        KC.LCMD(KC.V),        KC.MUTE,
        KC.LCMD(KC.LSFT(KC.N4)), KC.LCTL(KC.UP),    KC.LCMD(KC.SPC),
    ],  # prev/play/next; copy/paste/system mute; screenshot-area/Mission Control/Spotlight
    # CODE: VS Code (macOS default bindings)
    [
        KC.LCMD(KC.P),        KC.LCMD(KC.LSFT(KC.P)), KC.LCMD(KC.SLSH),
        KC.LCMD(KC.B),        KC.LCTL(KC.GRV),      KC.LCMD(KC.S),
        KC.F5,                KC.LCMD(KC.LSFT(KC.F)), KC.LCMD(KC.LSFT(KC.Z)),
    ],  # quick open/palette/comment; sidebar/terminal/save; debug/search/redo
    # MEET: Zoom (macOS default bindings) + canned text
    [
        KC.LCMD(KC.LSFT(KC.A)), KC.LCMD(KC.LSFT(KC.V)), KC.LCMD(KC.LSFT(KC.S)),
        KC.LALT(KC.Y),        KC.LCMD(KC.LSFT(KC.H)), KC.LCMD(KC.W),
        KC.MACRO("Be right back"), KC.MACRO("Sounds good"), KC.ESC,
    ],  # mute/video/share; raise hand/chat/close; canned replies/esc
]

# ---- Encoder map: one entry per layer: ((CCW, CW, press),) ------------
# Press always advances to the next layer (wraps around).
encoder_handler.map = [
    ((KC.VOLD, KC.VOLU, KC.TO(CODE)),),                    # MEDIA
    ((KC.LCMD(KC.MINS), KC.LCMD(KC.EQL), KC.TO(MEET)),),   # CODE: zoom out/in
    ((KC.VOLD, KC.VOLU, KC.TO(MEDIA)),),                   # MEET
]
```

Note for the user (copy into the commit message body): system mute moved from the encoder button to MEDIA position 5 (the key that used to type `6`), because the encoder button now cycles layers.

**Verify**: `python3 -m py_compile ~/Desktop/Personal_Projects/rp2040/code.py` → exit 0

### Step 3: Host-side shape check

Run this from `~/Desktop/Personal_Projects/rp2040`. It parses `code.py` without importing it (on the Mac, `import board` would fail):

```bash
python3 - <<'EOF'
import ast
src = open("code.py").read()
tree = ast.parse(src)
km = em = names = None
for node in ast.walk(tree):
    if isinstance(node, ast.Assign):
        t = node.targets[0]
        if isinstance(t, ast.Attribute) and t.attr == "keymap": km = node.value
        if isinstance(t, ast.Attribute) and t.attr == "map": em = node.value
        if isinstance(t, ast.Name) and t.id == "LAYER_NAMES": names = node.value
assert km is not None and em is not None and names is not None, "missing keymap/map/LAYER_NAMES"
assert all(len(layer.elts) == 9 for layer in km.elts), "every layer needs 9 keys"
assert len(km.elts) == len(em.elts) == len(names.elts), "keymap, encoder map, LAYER_NAMES lengths differ"
print("OK", len(km.elts), "layers")
EOF
```

**Verify**: prints `OK 3 layers`.

### Step 4: On-device check (human)

Deploy, then with the serial console open:
1. No `Traceback` appears.
2. On the MEDIA layer, the top-middle key toggles play/pause, and turning the encoder changes volume.
3. Press the encoder: in a text editor, the key that used to type `1` now opens VS Code quick open (Cmd+P) when VS Code is focused.
4. Press the encoder again (MEET), focus a text field, and the key that used to type `7` types `Be right back`.
5. Press the encoder a third time: back on MEDIA (play/pause works again).

If the executor can't reach the device, mark the plan `DONE (device check pending)` and hand this checklist to the user.

## Test plan

- Host: `py_compile` plus the AST shape check in Step 3 (it catches the encoder-map/keymap length mismatch that would crash on the device).
- Device: the Step 4 checklist.

## Done criteria

- [ ] `py_compile` exits 0
- [ ] Step 3 snippet prints `OK 3 layers`
- [ ] `grep -c "KC.N[1-9]" code.py` → `0`
- [ ] `grep -c "LAYER_NAMES" code.py` → `1` or more
- [ ] Only `code.py` changed (`git status --short` shows ` M code.py` plus `plans/README.md`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- The device shows `IndexError` from `encoder.py`. The encoder map and keymap lengths don't match even though Step 3 passed, so report instead of patching `kmk/`.
- `KC.MACRO` raises `AttributeError` on the device. That means the Macros module isn't in `kbd.modules`; check Step 1. If it's still failing after the check, STOP.
- The user says the physical key positions don't match the comments (for example, the wiring is rotated). Ask the user for the physical order rather than guessing.

## Maintenance notes

- Adding a layer means four changes: a keymap row, an encoder map entry, a `LAYER_NAMES` entry and the `TO(...)` chain. Rerun the Step 3 check after.
- These shortcuts assume macOS and default app bindings. If the user switches to Windows, swap `LCMD` for `LCTL`.
- Plans 004 (per-layer OLED image), 005 (LED color) and 006 (status text) all key off `LAYER_NAMES` and the layer indices.
