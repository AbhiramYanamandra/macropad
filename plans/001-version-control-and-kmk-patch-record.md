# Plan 001: Put the macropad firmware under git and record the local KMK patch

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: there is no git repo yet, so compare the
> "Current state" excerpts below against the live files by reading them. Any
> mismatch is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: no git repo yet (snapshot of `/Users/ysabhiram/Desktop/Personal_Projects/rp2040`), 2026-11-14

## Why this matters

The project folder `/Users/ysabhiram/Desktop/Personal_Projects/rp2040` is a copy of a CircuitPython
board's `CIRCUITPY` drive. It has no version control. So a bad edit can't be undone,
and none of the later plans have a commit to check for drift against.
Someone also edited the vendored KMK library by hand
(`kmk/extensions/display/ssd1306.py`) so the OLED works on CircuitPython 10.
Nothing records that edit. Replacing the `kmk/` folder with a newer upstream
copy would silently undo it and break the display. When this plan lands, the
project is in git with a `baseline-2026-11-14` tag, and a README records the
hardware, the deploy command and the KMK patch.

## Current state

- Hardware (from `boot_out.txt`): `Adafruit CircuitPython 10.0.0 on 2025-10-01; Seeeduino XIAO RP2040 with rp2040`.
- Files at the project root:
  - `code.py`: the user's KMK firmware config (3×3 matrix, one rotary encoder, 128×32 SSD1306 OLED).
  - `boot.py`: empty (0 bytes).
  - `settings.toml`: empty (0 bytes).
  - `boot_out.txt`: written by CircuitPython on every boot. It's generated, not source.
  - `sd/placeholder.txt`: CircuitPython's default folder. Not used.
  - `kmk/`: vendored copy of the KMK firmware (plain `.py` files).
  - `lib/`: CircuitPython libraries (`adafruit_display_text/`, `adafruit_displayio_ssd1306.mpy`) and three 128×32 1-bit BMPs: `goku.bmp`, `manandmountain.bmp`, `turbulence.bmp`.
  - Several `.DS_Store` files (macOS junk).
- Pin usage in `code.py` (all 11 XIAO GPIO pins are used):
  - cols `board.D0, board.D2, board.D9`; rows `board.D1, board.D3, board.D8`; `DiodeOrientation.COL2ROW`
  - encoder `(board.D10, board.D7, board.D6)` = (pin A, pin B, push button)
  - I2C OLED `scl=board.D5, sda=board.D4`, address `0x3C`
- The local KMK patch, `kmk/extensions/display/ssd1306.py` (excerpt):

  ```python
  import adafruit_displayio_ssd1306  # Display-specific library
  import displayio

  from . import DisplayBase
  # NEW (works in CP10):
  from i2cdisplaybus import I2CDisplayBus
  ...
      def during_bootup(self, width, height, rotation):
          self.display = adafruit_displayio_ssd1306.SSD1306(
              I2CDisplayBus(self.i2c, device_address=self.device_address),
  ```

  CircuitPython 10 removed `displayio.I2CDisplay`. The patch switches to the
  `i2cdisplaybus.I2CDisplayBus` class. `kmk/extensions/display/sh1106.py:34` still uses
  `displayio.FourWire`, which is also removed in CP10. That file is unused here, so leave it alone.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Syntax check | `python3 -m py_compile /Users/ysabhiram/Desktop/Personal_Projects/rp2040/code.py` | exit 0, no output |
| Git state | `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 status --short` | empty after the commit |
| Tag exists | `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 tag -l baseline-2026-11-14` | prints `baseline-2026-11-14` |

## Scope

**In scope** (create only):
- `.gitignore` (create)
- `README.md` (create)
- the git repository itself (`git init`, one commit, one tag)

**Out of scope**:
- Any change to `code.py`, `boot.py`, `kmk/**` or `lib/**`. This plan only records the current state.
- Pushing to any remote, or creating a GitHub repo. The user decides that.
- Deleting `.DS_Store` files from disk. Ignore them in git instead.

## Git workflow

- Work on the default branch `main` (`git init -b main`). This plan creates the repo.
- A single commit, message: `chore: initial snapshot of macropad firmware`.
- Do NOT push.

## Steps

### Step 1: Create `.gitignore`

Create `/Users/ysabhiram/Desktop/Personal_Projects/rp2040/.gitignore` with exactly:

```
.DS_Store
boot_out.txt
__pycache__/
*.pyc
```

**Verify**: `cat /Users/ysabhiram/Desktop/Personal_Projects/rp2040/.gitignore` → those 4 lines.

### Step 2: Create `README.md`

Create `/Users/ysabhiram/Desktop/Personal_Projects/rp2040/README.md` with these sections, filled in from "Current state" above:

1. `# Macropad (XIAO RP2040 + KMK)`, with a one-paragraph description.
2. `## Hardware`: board, CircuitPython version, and a pin table with these rows: matrix cols, matrix rows, diode orientation, encoder A/B/button, OLED SDA/SCL/address. Add a line saying all 11 GPIO pins (D0–D10) are in use, so new peripherals must go on the I2C bus (D4/D5). The onboard NeoPixel (GPIO12, power on GPIO11) is also free to use.
3. `## Deploy`: plug in the board, then copy the project to the drive with this command (put it in a `bash` code block):

   ```
   rsync -av --exclude '.git' --exclude 'plans' --exclude '.DS_Store' --exclude 'README.md' --exclude '.gitignore' /Users/ysabhiram/Desktop/Personal_Projects/rp2040/ /Volumes/CIRCUITPY/
   ```

   Note that CircuitPython auto-reloads when `code.py` changes. To read the serial console, use `screen /dev/tty.usbmodem* 115200` (quit with `Ctrl-A` then `K`). Say explicitly: never add `--delete` to the rsync command.
4. `## Local patches to vendored KMK`: list `kmk/extensions/display/ssd1306.py`. Explain that it imports `I2CDisplayBus` from the `i2cdisplaybus` module and uses it in `during_bootup`, because CircuitPython 10 removed `displayio.I2CDisplay`. Say it must be reapplied after any KMK update, and that `sh1106.py` is unpatched and unused.
5. `## Rescue`: if the board stops showing the `CIRCUITPY` drive, there are two ways back. (a) Safe mode: press the XIAO's reset button once during the ~1 s window right after power-up while the status LED blinks; safe mode skips `boot.py` and `code.py`, and the drive appears. (b) Hold the BOOT button while plugging in to get the `RPI-RP2` UF2 bootloader drive and reflash CircuitPython.

**Verify**: `grep -c "^## " /Users/ysabhiram/Desktop/Personal_Projects/rp2040/README.md` → `4` or more, and `grep -c "i2cdisplaybus" /Users/ysabhiram/Desktop/Personal_Projects/rp2040/README.md` → `1` or more.

### Step 3: Initialize git, commit, tag

```bash
cd /Users/ysabhiram/Desktop/Personal_Projects/rp2040 && git init -b main && git add -A && git commit -m "chore: initial snapshot of macropad firmware" && git tag baseline-2026-11-14
```

**Verify**:
- `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 status --short` → empty
- `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 ls-files | grep -c DS_Store` → `0`
- `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 ls-files | grep -c "^kmk/"` → greater than 50
- `git -C /Users/ysabhiram/Desktop/Personal_Projects/rp2040 tag -l baseline-2026-11-14` → `baseline-2026-11-14`

## Test plan

There is no code change, so there are no tests. `python3 -m py_compile code.py` must still exit 0.

## Done criteria

- [ ] `.gitignore` and `README.md` exist with the content above
- [ ] `git status --short` is empty; tag `baseline-2026-11-14` exists
- [ ] No `.DS_Store` or `boot_out.txt` is tracked
- [ ] `code.py`, `boot.py`, `kmk/` and `lib/` are unchanged on disk; this plan only created `.gitignore`, `README.md` and `.git/`
- [ ] `plans/README.md` status row updated

## STOP conditions

- `/Users/ysabhiram/Desktop/Personal_Projects/rp2040` is already a git repo (`git -C ... rev-parse` succeeds). Report it instead of re-initializing.
- `git commit` fails because no user name or email is configured. Do NOT set a global identity. Report back so the user can set it.
- `kmk/extensions/display/ssd1306.py` no longer contains `I2CDisplayBus`. That means the patch was reverted, so report it.

## Maintenance notes

- Every later plan uses `baseline-2026-11-14` as its drift-check base.
- When upgrading KMK: copy the new `kmk/` over the old one, run `git diff kmk/extensions/display/ssd1306.py`, and reapply the patch if upstream hasn't fixed it.
- Pushing to a private GitHub repo is a sensible follow-up, but that's the user's call.
