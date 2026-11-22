# Plan 009: Switch layers with keys 7 + 9 when the knob is not fitted

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 90a66e4..HEAD -- code.py config_loader.py keymap.json configurator/`
> must be empty apart from this plan's own commits. Confirm `config_loader.py`
> builds combo actions with `self.action(c.get('action'), 0)` and `code.py`
> sets `encoder_handler.pins = ((board.D10, board.D7, board.D6),)`. Any other
> mismatch is a STOP condition.
>
> All paths are relative to the repository root, `~/Desktop/Personal_Projects/rp2040`.

## Status

- **Priority**: P1. Without it the pad cannot leave layer 0.
- **Effort**: S
- **Risk**: LOW. Changes are confined to configuration loading and one optional module. The existing fallback layout still applies if `keymap.json` is invalid.
- **Depends on**: none. Run this before plan 008.
- **Category**: bug
- **Planned at**: commit `90a66e4`, 2026-11-22

## Owner decisions (2026-11-22)

- When the knob is not fitted, pressing **keys 7 and 9 together** moves to the next layer.
- Layers **cycle forward only**, wrapping from the last layer back to the first. There is no "previous layer" combo.
- When the knob is fitted, **pressing the knob** moves to the next layer, as it does today.
- The knob is a future plan. The PCB has routed encoder headers (D10, D7, D6), but the knob is not in the enclosure yet.

## Why this matters

Every layer's only layer-switch action is `encoder.press`. The knob isn't fitted, so the pad is stuck on layer 0 (MEDIA), and the CODE and MEET layers are unreachable. Plans 003 to 006 cannot finish their device checks for those layers.

The pad cannot detect whether a knob is fitted. With no encoder, the pins read the same as a fitted knob at rest, so this needs an explicit setting.

## Current state

- `keymap.json` (version 1) already supports global `combos` and `layer` actions with `"layer": "next"`. See `configurator/FORMAT.md`.
- **Bug that blocks the obvious fix.** `config_loader.py` `Builder.build()` builds combo actions with `self.action(c.get('action'), 0)`, and `layer_target('next', here)` returns `(here + 1) % n`. A combo with `"layer": "next"` therefore always goes to layer 1, from every layer. It cannot cycle. Per-layer `encoder.press` actions cycle correctly, because each layer is built with its own index.
- `code.py` always creates `ToastEncoderHandler` with pins D10, D7 and D6, and appends it to `kbd.modules`.
- Positions in `combos[].keys` are 0-based. Keys 7 and 9 on the pad are positions `6` and `8`. The existing combo `[0, 2]` (keys 1 + 3, Lock screen) does not overlap.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Syntax | `python3 -m py_compile code.py config_loader.py layer_led.py macropad_display.py` | exit 0 |
| JSON | `python3 -m json.tool keymap.json > /dev/null` | exit 0 |
| Loader logic | the host check in Step 5 | prints `ok` |
| On-device (human) | deploy per `README.md` | Step 7 checklist passes |

## Scope

**In scope**:
- `config_loader.py`: the `knob` setting, a cycling next-layer action, and the default combo
- `code.py`: use the encoder only when the knob is fitted
- `keymap.json`: add `"knob": false` and the 7 + 9 combo
- `configurator/FORMAT.md`: document `knob` and the combo behaviour
- `configurator/index.html`: a "Knob fitted" setting, the default combo, and the simulator's cycling behaviour

**Out of scope**:
- `kmk/`. It's vendored. Implement the cycling action in project files.
- Any new layers, keys or visual redesign. That is plan 008.
- Plan 007.

## Git workflow

- Branch `fix/009-layer-switch-without-knob`; commit `fix: switch layers with keys 7+9 when the knob is not fitted`. Do not push. The repository has no remote.

## Steps

### Step 1: Add a cycling "next layer" action

Add a key whose press reads the active layer at that moment and moves to the next one, wrapping around. Put it in `config_loader.py`, or in a small project module if it needs KMK imports the loader doesn't have. It must change `keyboard.active_layers[0]` the same way KMK's `KC.TO` does, so `LayerDisplay` and `LayerLed` still notice the change.

Resolve `{"type": "layer", "mode": "to", "layer": "next"}` to this cycling key wherever the context is global: combos always, and encoder or key actions too if that keeps the code simpler. `"prev"` gets the same treatment for consistency, even though no default uses it.

**Verify**: `python3 -m py_compile config_loader.py` → exit 0. The code no longer passes a fixed `0` as the layer for combo actions with `"next"` or `"prev"`.

### Step 2: Add the `knob` setting

In `config_loader.py`, read `settings.get('knob', False)` as a boolean and include it in the built config, for example as `cfg['knob']`. A missing value means "not fitted".

**Verify**: `py_compile` → exit 0.

### Step 3: Never leave the pad stuck on one layer

In `Builder.build()`, when `knob` is false and no key, hold action or combo anywhere contains a `layer` action, append a default combo:

```json
{ "keys": [6, 8], "action": { "type": "layer", "mode": "to", "layer": "next", "label": "NEXT LYR" } }
```

Skip it when a combo on `[6, 8]` already exists. When there is only one layer, a cycling action is harmless, so add it anyway.

**Verify**: the host check in Step 5 covers this.

### Step 4: Use the encoder only when the knob is fitted

In `code.py`, create, configure and append `encoder_handler` to `kbd.modules` only when `cfg['knob']` is true. Everything that references `encoder_handler`, such as `toast_display`, must be guarded the same way. The fallback config in `config_loader.py` keeps its encoder section. It only applies when the knob is fitted.

**Verify**: `python3 -m py_compile code.py` → exit 0. `grep -n "encoder_handler" code.py` shows every use inside the knob-fitted branch.

### Step 5: Host check of the loader

`config_loader.py` must stay importable on the Mac. If KMK imports block that, isolate them so the check below runs. Run:

```bash
python3 - <<'EOF'
import json, config_loader as c
cfg = json.load(open('keymap.json'))
cfg['settings']['knob'] = False
cfg['combos'] = [x for x in cfg['combos'] if sorted(x['keys']) != [6, 8]]
for layer in cfg['layers']:
    layer['encoder']['press'] = {'type': 'none'}
built = c.Builder(cfg).build()
assert built['knob'] is False
assert any(tuple(sorted(x['coords'])) == (6, 8) for x in built['combos']), 'default combo missing'
print('ok')
EOF
```

Adapt only the import line if the loader must be imported differently on the host. If it cannot run on the Mac at all, report that and rely on Step 7.

### Step 6: Update `keymap.json`, the format notes and the configurator

1. `keymap.json`: add `"knob": false` to `settings`, and add the 7 + 9 combo from Step 3 to `combos` explicitly, so it shows in the configurator.
2. `configurator/FORMAT.md`: document `"knob": false` under `settings` ("true when a rotary encoder is fitted; when false the encoder is ignored, and keys 7 + 9 switch to the next layer unless the keymap defines its own layer switch"). Document that `"next"` and `"prev"` cycle from the current layer in every context, including combos.
3. `configurator/index.html`:
   - Add `knob: false` to both default `settings` objects (around lines 247 and 342) and a "Knob fitted" toggle in the settings UI.
   - When the knob is off, mark the encoder controls "Knob · not fitted" and leave them editable. Porcelain shows the same state.
   - Make the simulator's combo and layer logic cycle from the current layer.

**Verify**:
- `python3 -m json.tool keymap.json > /dev/null` → exit 0
- Open `configurator/index.html` in Chrome, load `keymap.json`, and confirm the Knob fitted toggle is off.
- In **Try it**, pressing 7 and 9 together moves MEDIA → CODE → MEET → MEDIA.
- Save or download the keymap and confirm it still contains `"knob": false` and the combo.

### Step 7: On-device check (human)

1. Deploy `code.py`, `config_loader.py` and `keymap.json` per `README.md`. Boot shows the MEDIA screen, and serial shows no `Traceback` and no `keymap.json error`.
2. Press 7 and 9 together. The OLED and LED change to CODE. Again: MEET. Again: MEDIA.
3. Keys 7 and 9 pressed **alone** still do their own actions. Expect up to `combo_timeout` (80 ms) of delay on those two keys.
4. Keys 1 and 3 together still lock the screen.
5. The other keys on CODE and MEET now do their layer's actions. This also completes the layer parts of the device checks in plans 003 to 006.

## Test plan

- Host: `py_compile`, `json.tool` and the Step 5 check.
- Browser: the configurator checks in Step 6.
- Device: the Step 7 checklist. Item 2 is the regression test for the stuck-on-layer-0 bug.

## Done criteria

- [ ] All files compile, and `keymap.json` is valid JSON with `"knob": false` and the `[6, 8]` combo
- [ ] Combos with `"next"` cycle from the current layer
- [ ] No encoder module is created when `knob` is false
- [ ] The configurator has the toggle, and its simulator cycles correctly
- [ ] `git diff --stat -- kmk/` → empty
- [ ] `plans/README.md` row updated, and plans 003 to 006 device-check notes updated if Step 7 passed

## STOP conditions

- Cycling needs changes inside `kmk/`. Report it rather than patching vendored code.
- After the change, the OLED or LED stops following layer changes. `active_layers` is probably being changed in a way the display doesn't detect. Report with serial output.
- The 7 + 9 combo makes keys 7 or 9 unreliable on their own, for example dropped or doubled presses. Report it. Don't tune timeouts without the owner.
- Any existing `keymap.json` without `knob` fails to load. Missing must mean "not fitted".

## Maintenance notes

- When the knob is fitted: set "Knob fitted" on in the configurator and save. The knob press then cycles layers. The 7 + 9 combo stays as a backup until removed in the configurator.
- Plan 008's app must show the same toggle in Porcelain's "Knob · not fitted" row and keep these semantics.
