# Plan 008: Rebuild Macropad Studio in the approved Porcelain design

> **Executor instructions**: Follow this plan step by step. This plan has an
> approval gate after Step 2. Do not start Step 3 until the owner has approved
> the architecture proposal in writing. If anything in the "STOP conditions"
> section occurs, stop and report. Do not improvise. When a step finishes,
> update this plan's row in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 9099584..HEAD -- configurator/ design-mockups/ keymap.json config_loader.py`
> must be empty, and `shasum -a 256 design-mockups/porcelain.html` must print
> `8d0638106955c8cb16c39a4ddbca5654a3f03890f31adfe63d3e9b1f33d3e413`.
> A different hash means the design changed after approval. That is a STOP condition.
>
> All paths in this plan are relative to the repository root. Plans 001 to 007
> use absolute paths under `/Users/ysabhiram/Desktop/rp2040`, which no longer
> exists; the repository now lives at `~/Desktop/Personal_Projects/rp2040`.

## Status

- **Priority**: P1
- **Effort**: L, split into slices. Steps 1 and 2 are S.
- **Risk**: MEDIUM. A new app that writes to the `CIRCUITPY` drive can break the pad's configuration.
- **Depends on**: none for Steps 1 and 2. Device checks in 003 to 006 are recommended before Step 5.
- **Category**: direction
- **Planned at**: commit `9099584`, 2026-11-22
- **KAREN OS**: first engineering pilot for KAREN OS (Phase 3). Record how much coordination it needed.

## Design approval

| Field | Value |
| --- | --- |
| Approved artefact | `design-mockups/porcelain.html` ("Macropad Studio · Porcelain, revised") |
| SHA-256 | `8d0638106955c8cb16c39a4ddbca5654a3f03890f31adfe63d3e9b1f33d3e413` |
| Approved by | Owner, 2026-11-22 |
| Scope of approval | Visual direction and interaction design only. It does not approve a technology stack, distribution method, hardware change or any code. |
| Superseded designs | `design-mockups/index.html`, `design-mockups/round-two/`, `design-mockups/round-three.html`, and the look of `configurator/index.html` |
| Revocation | Any edit to `porcelain.html` voids this approval until the owner re-approves the new hash |

## Why this matters

Macropad Studio works today as a browser app (`configurator/index.html`). It was built on 2026-11-14, before the design rounds. The owner's chosen direction, Porcelain, is different in kind as well as look:

- It is a **native Mac app** with an off-white palette, not a page in Chrome.
- It **lives in the menu bar**, with connection status, layers, test mode, Open Studio and Quit.
- The main window draws the pad from the owner's Fusion enclosure and edits each key: what happens **when pressed** (macros with recorded or built steps), **when held**, an **icon on the key** and what **shows on screen**.
- It has **Combos**, a **Display** section (layer screen, key pop-ups, sleep screen) and a frame-by-frame **animation editor** (pencil, eraser, bucket, frames, onion skin, speed, loop).
- It shows **"Knob · not fitted"** and names the device **"Macropad mk2"**.
- Changes go to the pad with **Sync to pad**.

The browser app also has limits Porcelain removes. It needs Chrome or Edge to write to the drive, and it can't sit in the menu bar.

## Current state

- `configurator/index.html` (about 78 KB): the browser app. Sections include Layers, Combos and "What your computer receives".
- `configurator/FORMAT.md`: the `keymap.json` format.
- `keymap.json` and `config_loader.py`: the firmware reads its whole configuration from `keymap.json` on the `CIRCUITPY` drive. **This file is the contract between any app and the pad.** A new app must read and write the same format, or change it deliberately with a firmware update.
- `macropad_display.py` and `layer_led.py`: the OLED and LED behaviour that the Display section configures.
- The firmware's display support is 1-bit images on a 128×32 SSD1306. Porcelain's animation editor implies a frame format the firmware does not support yet.

## Scope

**In scope**:
- An architecture proposal (Steps 1 and 2).
- After approval, a native Mac app in a new folder (proposed `studio/`) built in vertical slices.
- Firmware changes only where a slice needs them, each listed in the proposal.

**Out of scope** until separately approved:
- Deleting or replacing `configurator/`. It stays the working tool until the new app covers everything it does.
- Code signing, notarisation, distribution or an App Store listing.
- Hardware changes, including removing the knob. "Knob · not fitted" and "mk2" need the owner's confirmation first.
- Plan 007 (hiding the drive). It would block the app from writing `keymap.json`, so it has to be designed together with Sync to pad.

## Git workflow

- Branch `pilot/008-porcelain`. One commit per step or slice. Do not push. The repository has no remote.

## Steps

### Step 1: Inventory the design and the contract

Open `design-mockups/porcelain.html` in a browser and list every screen, control and state it shows. Map each one to:

- an existing `keymap.json` field (see `configurator/FORMAT.md`), or
- a firmware feature that already exists, or
- something new, for the app, the format or the firmware.

Save the result as `plans/008-inventory.md`.

**Verify**: every screen in Porcelain appears in the inventory, and every row is marked existing, app-only or needs-firmware.

### Step 2: Architecture proposal (owner approval required)

Write `plans/008-architecture.md`. It must include:

1. **Stack options**, compared on native feel, effort, how they write to `CIRCUITPY`, menu-bar support and long-term maintenance. Include at least:
   - SwiftUI with a `MenuBarExtra`
   - a web-technology shell (for example Tauri) that reuses parts of `configurator/index.html`
   - recommend one.
2. **Data flow**: app ↔ `keymap.json` ↔ `config_loader.py`, with a Mermaid diagram. Say how Sync to pad writes safely, for example by writing to a temporary file and renaming it, and what happens if the pad is unplugged mid-write.
3. **Format changes**: any `keymap.json` additions (key icons, animations), with a version field and backwards compatibility for the current firmware.
4. **Slices**: an ordered list. Proposed first slice: open the pad, show the Porcelain main window with the real keys and layers, edit a key's "when pressed" action, and Sync to pad.
5. **Verification** for each slice, including how to test without the hardware.
6. **Plan 007 interaction**, as described under Scope.
7. **Rollback**: the browser configurator keeps working throughout.

**Verify**: the owner approves `plans/008-architecture.md`, and the approval is recorded at the top of that file with the date and its SHA-256. **STOP here until that approval exists.**

### Step 3: First slice

Build exactly the first slice in the approved proposal, matching Porcelain visually. Compare screenshots side by side with the mockup.

**Verify**: the slice's checks from the proposal pass. A `keymap.json` written by the app loads unchanged in `configurator/index.html`, and `python3 -m py_compile config_loader.py` passes.

### Step 4: Review

A separate review pass compares the slice with Porcelain and the proposal, and lists differences as fix, accept or defer. The owner decides on anything marked accept or defer.

### Step 5: On-device check (human)

1. Connect the pad and open the app. It shows Connected and the current layer.
2. Change one key's action, then Sync to pad. CircuitPython restarts, and the key does the new action.
3. Open the same `keymap.json` in the browser configurator. It loads without errors.

### Step 6: Next slices

Repeat Steps 3 to 5 for each later slice in the approved order. Each slice is its own commit and its own row update.

## Test plan

- Host: unit tests for reading and writing `keymap.json` against `configurator/FORMAT.md`; `py_compile` for any firmware change.
- Visual: side-by-side screenshots against `porcelain.html` for every slice.
- Device: the Step 5 checklist for every slice that changes what reaches the pad.

## Done criteria (this plan, through the first slice)

- [ ] `plans/008-inventory.md` exists and covers every Porcelain screen
- [ ] `plans/008-architecture.md` is approved and hash-recorded
- [ ] The first slice works on the device and passes review
- [ ] The browser configurator still works
- [ ] `plans/README.md` row updated

## STOP conditions

- `porcelain.html` no longer matches the approved hash.
- The proposal needs a hardware change, or depends on "Knob · not fitted" or "mk2", before the owner confirms them.
- A `keymap.json` change would stop the current firmware from loading existing files.
- Writing to `CIRCUITPY` fails or corrupts `keymap.json` in testing. Restore from Git and report.
- Anything would need signing certificates, paid developer accounts or other spending.

## Maintenance notes

- `keymap.json` is the single contract. Document every format change in `configurator/FORMAT.md` in the same commit.
- Keep the browser configurator until the owner retires it in writing.
