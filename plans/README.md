# Implementation Plans

> **Tracking moved to GitHub issues on 2026-11-23.** Priority, status and discussion
> now live in the [issues](https://github.com/AbhiramYanamandra/macropad/issues), and
> every change arrives as a pull request. The plan files below stay as the detailed
> steps that issues link to. The status column is kept up to date by each PR.

Written by the improve skill on 2026-11-14 for the XIAO RP2040 + KMK macropad
(3×3 matrix, one rotary encoder, 128×32 SSD1306 OLED, CircuitPython 10.0.0).
Do them in the order below unless the dependencies say otherwise. Each executor:
read the whole plan before starting, follow its STOP conditions, and update your row when done.

The project had no git repo when these were written. Plan 001 creates it plus the
tag `baseline-2026-11-14`, which every later plan uses for its drift check.

There is no host test harness (the code imports `board`, which only exists on the
microcontroller). Each plan's checks are `python3 -m py_compile` and small AST checks
on the Mac, plus a human checklist on the device. Plans can be marked
`DONE (device check pending)` when no one can reach the hardware.

## Execution order & status

| Plan | Title | Priority | Effort | Depends on | Status |
|------|-------|----------|--------|------------|--------|
| [001](001-version-control-and-kmk-patch-record.md) | Git repo, README, record the local KMK patch | P1 | S | — | DONE (git + tag `baseline-2026-11-14` + root `README.md`) |
| [002](002-tidy-code-py.md) | Tidy `code.py` (dead import, layout, debug switch) | P3 | S | 001 | REJECTED: superseded, `code.py` was rewritten for the configurator |
| [003](003-real-keymap-with-layers-and-macros.md) | Three-layer keymap (Media / Code / Meet), encoder press cycles layers | P1 | S | 001, 002 | DONE (device check pending): delivered as the default `keymap.json`, editable in Macropad Studio. Issue #5. |
| [004](004-per-layer-oled-art.md) | Per-layer OLED image + wake screen on layer change | P2 | S | 003 | DONE (device check pending): `macropad_display.py` `LayerDisplay`. Issue #5. |
| [005](005-onboard-neopixel-layer-indicator.md) | Onboard NeoPixel shows layer color | P3 | S | 003 (needs `lib/neopixel.mpy` from the user) | DONE (device check pending; `lib/neopixel.mpy` still needed): `layer_led.py`. Issue #5. |
| [006](006-oled-status-toasts.md) | OLED text toasts (layer name, `VOL+`/`ZOOM-`) | P3 | M | 004 | DONE (device check pending): toasts for keys and the encoder, I2C at 400 kHz. Issue #5. |
| [007](007-boot-config-hide-drive.md) | `boot.py`: hide drive and serial unless the rescue key is held | P2 | S | 001; run last, user present | BLOCKED: waits for plan 008's Sync to pad design, because hiding the drive stops the app writing `keymap.json`. Issue #10. |
| [008](008-porcelain-redesign.md) | Rebuild Macropad Studio as the approved Porcelain native Mac app (architecture proposal first, then slices) | P1 | L | 009; approval gate after Step 2 | IN PROGRESS: slice 1 merged to main in PR #1 (2026-11-22). Pad check is issue #3; slices 2 to 5 are issues #6 to #9 |
| [009](009-layer-switch-without-knob.md) | Keys 7 + 9 cycle layers when the knob is not fitted; `knob` setting; fix combos always jumping to layer 1 | P1 | S | none; run before 008 | DONE (device check pending): merged to main 2026-11-22 after review; host checks pass; still open: configurator Try it check in Chrome and the Step 7 pad checklist. Issue #4. |

Status values: TODO | IN PROGRESS | DONE | DONE (device check pending) | BLOCKED (with a one-line reason) | REJECTED (with a one-line reason)

> **2026-11-14 update:** the user asked for a G Hub-style configurator, so plans
> 003–006 were built directly as a configurable firmware (`config_loader.py` +
> `keymap.json`) plus a browser app (`configurator/index.html`). The plan files
> stay as design notes. Their device checklists (Step 4/5 in each) are still the right
> on-hardware tests. Plan 007 is unchanged and still TODO.

## Dependency notes

- 001 comes first: it creates the git baseline every drift check uses, and the README Rescue section that 007 relies on.
- 002 before 003: 003's "Current state" excerpts assume the tidied, sectioned `code.py`.
- 003 before 004/005/006: they all depend on the `MEDIA, CODE, MEET` constants, `LAYER_NAMES`, and the encoder button cycling layers with `KC.TO(...)`.
- 004 before 006: 006 extends the `LayerDisplay` class that 004 creates in `macropad_display.py`.
- 005 and 004 are independent. If 005 runs first, it moves the layer-constants block itself (see its Step 3).
- 007 goes last, because it hides the `CIRCUITPY` drive. Every other plan's on-device checks are easier while the drive is visible.

## Idea not planned (from the advisor report)

- Fitting the knob. The PCB already has routed encoder headers (D10, D7, D6) and the firmware supports `encoder` actions; what is missing is an enclosure design that looks right. Until then the knob is "not fitted", and layer switching needs a non-knob action (see plan 008, "The knob").

- Extra inputs over I2C (a seesaw rotary encoder via KMK's `I2CEncoder`, or a second OLED). All 11 GPIO pins are taken, so this needs new hardware. Revisit once the user picks a part.
- Per-app automatic layer switching through a script on the computer talking over USB serial (`bootcfg(cdc_data=True)`). This is large and would conflict with plan 007's serial changes unless designed together, so it needs a trial run first.

## Findings considered and rejected

- `kmk/extensions/display/__init__.py:199-201` deletes list entries while iterating them. It's a real upstream bug, but it only triggers for split keyboards (`entry.side`). Not applicable here, and it's in vendored code.
- `kmk/extensions/display/sh1106.py:34` uses `displayio.FourWire`, which was removed in CP10. The file is unused (the display is an SSD1306), so it's only documented in plan 001.
- Precompiling `kmk/` to `.mpy` for faster boot: there's no measured problem, and it adds a build step plus a version-pinned `mpy-cross`. Not worth it yet.
- Enabling NKRO: 9 keys fit easily in the 6-key report, and NKRO costs compatibility.
