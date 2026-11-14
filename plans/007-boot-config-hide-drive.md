# Plan 007: Configure `boot.py`: hide the CIRCUITPY drive and serial console unless a key is held at power-up

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git -C /Users/ysabhiram/Desktop/rp2040 diff --stat baseline-2026-11-14..HEAD -- boot.py kmk/bootcfg.py`
> Both must be unchanged (`boot.py` is still 0 bytes). Otherwise STOP.
>
> **This plan changes how the board shows up over USB. Do NOT deploy it to the
> device without the user present and the user having read "Rescue" below.**

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MED (a wrong pin choice hides the drive; recovery is always possible via safe mode)
- **Depends on**: plans/001-version-control-and-kmk-patch-record.md (for the Rescue section of `README.md`). Execute this plan LAST.
- **Category**: dx
- **Planned at**: tag `baseline-2026-11-14`, 2026-11-14

## Why this matters

`boot.py` is empty, so every computer the macropad is plugged into sees a `CIRCUITPY`
USB drive and a serial port next to the keyboard. Anyone can edit the firmware from
Finder, an accidental save can reload it mid-use, and it looks odd on a work laptop.
KMK ships `bootcfg()` for exactly this. In normal use it hides the drive and the serial
console. Holding one chosen key while plugging in brings both back for editing.
This plan does NOT turn on NKRO (sending any number of keys at once). With 9 keys and
the standard 6-key report that's unnecessary, and NKRO is less compatible with some BIOSes and KVMs.

## Current state

- `/Users/ysabhiram/Desktop/rp2040/boot.py`: empty (0 bytes).
- Matrix (`code.py`): `kbd.col_pins = (board.D0, board.D2, board.D9)`,
  `kbd.row_pins = (board.D1, board.D3, board.D8)`, `DiodeOrientation.COL2ROW`.
- `kmk/scanners/digitalio.py:45-47`: with `COL2ROW`, **cols are diode anodes and rows are cathodes**.
- `kmk/bootcfg.py:11-138`, `bootcfg(sense=..., source=..., cdc_console=True, storage=True, ...)`:
  - `sense` is set to an input with a pull-up (lines 32–35). `source` is set to an output driven LOW (lines 37–40).
  - For a matrix key, current flows anode → cathode, so `sense` must be the key's **column** (anode)
    and `source` its **row** (cathode). Pressing that key pulls `sense` LOW.
  - Lines 123–126: `if sense is None or not sense.value: return False`. If the key is held (sense LOW),
    the function returns early, so the drive and console stay **enabled**. If the key is not held,
    execution continues to lines 131–138, which run `usb_cdc.enable(console=False)` and
    `storage.disable_usb_drive()`.
  - It keeps the HID keyboard, mouse and consumer-control devices enabled by default (lines 18–21),
    which the media keys need.
- Chosen rescue key: `sense=board.D0` (col 0), `source=board.D1` (row 0). That's the key at
  matrix row 0, col 0. Which physical key that is depends on the wiring, and Step 3 finds it.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Syntax | `python3 -m py_compile /Users/ysabhiram/Desktop/rp2040/boot.py` | exit 0 |
| Drive visible (human) | `ls /Volumes/CIRCUITPY` | lists `code.py` etc. when the drive is enabled |

## Scope

**In scope**: `boot.py`, and `README.md` (append a "Boot modes" subsection).

**Out of scope**: `kmk/bootcfg.py` (vendored); `code.py`; enabling NKRO, MIDI changes or a custom USB VID/PID.

## Git workflow

- Branch `advisor/007-boot-config`; commit `feat: hide CIRCUITPY drive unless rescue key is held`. Do not push.

## Steps

### Step 1: Write `boot.py` with storage still ENABLED (dry run)

First deploy a version that only checks the rescue key wiring, so nothing gets hidden yet:

```python
import board
import digitalio

# Dry run: report whether the rescue key (row 0 / col 0) is held at boot.
sense = digitalio.DigitalInOut(board.D0)  # col 0 = diode anode
sense.switch_to_input(pull=digitalio.Pull.UP)
source = digitalio.DigitalInOut(board.D1)  # row 0 = diode cathode
source.switch_to_output(value=False)
print("rescue key held:", not sense.value)
sense.deinit()
source.deinit()
```

**Verify**: `python3 -m py_compile boot.py` → exit 0

### Step 2: Find the physical rescue key (human)

1. Deploy (README `## Deploy`).
2. Unplug, hold one key, and plug back in. Open `/Volumes/CIRCUITPY/boot_out.txt`; it ends with `rescue key held: True` or `False`.
3. Repeat with different keys until one gives `True`. That's the rescue key. Note which one it is (for example "top-left"). Without any key held, the result must be `False`.

**Verify**: exactly one key gives `True`, and no key held gives `False`. Otherwise STOP.

### Step 3: Write the real `boot.py`

Replace `boot.py` with:

```python
# Hold the rescue key (<FILL IN from Step 2, e.g. "top-left">) while plugging in
# to get the CIRCUITPY drive and serial console back for editing.
# Without it, the board appears as a keyboard only.
import board

from kmk.bootcfg import bootcfg

bootcfg(
    sense=board.D0,   # matrix col 0 (diode anode)
    source=board.D1,  # matrix row 0 (diode cathode)
    cdc_console=False,
    storage=False,
)
```

Replace `<FILL IN ...>` with the user's description from Step 2.

**Verify**: `python3 -m py_compile boot.py` → exit 0; `grep -c "FILL IN" boot.py` → `0`.

### Step 4: Document it in `README.md`

Under the existing `## Rescue` section, add a `### Boot modes` subsection. It should say: normal boot = keyboard only, and holding the rescue key (name it) while plugging in = drive and serial console visible. If that fails, use safe mode or the BOOT button as already described.

**Verify**: `grep -c "### Boot modes" README.md` → `1`.

### Step 5: On-device check (human, with the user present)

1. Deploy while the drive is still visible.
2. Unplug, then plug in normally: no `CIRCUITPY` drive appears (`ls /Volumes/CIRCUITPY` → "No such file or directory"), and keys and media keys still work.
3. Unplug, hold the rescue key, and plug in: `CIRCUITPY` appears.

## Test plan

Host: `py_compile`. Device: Steps 2 and 5. The dry run in Steps 1–2 exists so a wrong pin can't hide the drive.

## Done criteria

- [ ] `boot.py` compiles and contains `bootcfg(` with `sense=board.D0` and `source=board.D1`
- [ ] `README.md` has a `### Boot modes` subsection naming the rescue key
- [ ] Device checks 2 and 3 pass
- [ ] `plans/README.md` status row updated

## STOP conditions

- Step 2 gives `True` with no key held, or for more than one key. The wiring assumption (COL2ROW, D0 = col 0, D1 = row 0) is wrong, so report it and don't try other pins.
- After Step 5 the drive won't come back with the rescue key. Recover by entering safe mode (press reset once while the LED blinks right after plug-in; safe mode skips `boot.py`), then delete the contents of `/Volumes/CIRCUITPY/boot.py` and report.
- The user isn't available to do the physical checks. Leave `boot.py` at the Step 1 dry-run version or empty, and do NOT deploy Step 3.

## Maintenance notes

- `boot.py` only runs on a hard reset or power-up, not on auto-reload. Changes need an unplug and replug.
- If the matrix is ever rewired, redo Step 2 before redeploying.
- `cdc_console=False` also hides KMK's debug output. Hold the rescue key when debugging.
