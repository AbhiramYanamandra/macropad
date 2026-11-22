# Plan 008 · slice 1 review and pad handoff

Review date: 2026-11-23 (Australia/Brisbane). Implementation began 2026-11-22.
Branch: `pilot/008-porcelain`. Slice commit: `2e94a82`; subsequent Step 4
corrections are recorded in this review's commit. **Stop before Step 5.**

## Authority, baseline and scope

Owner authorised plan 008 Steps 3–4, then stopping for the human pad check.
The owner also requested README images and an architecture diagram. The
architecture approval is recorded in `008-architecture.md`, binding reviewed
revision `e3844ee`, SHA-256
`85e347dd9d2c9995935f77da51504923c91516414dbcc5f68462d2d7499ce882`.

The updated drift check from `712a55f` was empty before implementation.
Starting HEAD was `d346f92`; the approved Porcelain hash still matched
`8d0638106955c8cb16c39a4ddbca5654a3f03890f31adfe63d3e9b1f33d3e413`.
The archived round-one image is expected baseline content, per owner clarification.
KAREN OS startup core `personal-first-1` reported project OK/no warnings.
Other KAREN OS documents were not loaded, per owner instruction.

Delivered: a native macOS 13+ Keys window, real keymap open/edit, all existing
pressed action types, Undo/Revert, shared menu-bar state, explicit later-slice
destinations, conflict checks, local backup/recovery and staged file replacement.
The README now includes native UI/device renders and a Mermaid architecture
figure. Those images are app renders with the real repository keymap, not
photographs or evidence of a connected physical pad.

Firmware, `keymap.json`, `configurator/`, `kmk/`, `lib/` and the approved mockup
are unchanged. No schema migration, signing certificate, installation,
publication, paid account or device write was performed. The local development
bundle is under `studio/.build/` and is ignored by Git.

## Separate review result

This was a separate source/requirements/visual pass by the same worker, not an
independent human or second-agent review. The correctness fixes below are
resolved. Visual **accept** items remain for the owner; deferred work is not
silently marked complete.

| Disposition | Finding / difference | Result or owner decision |
|---|---|---|
| Fix — resolved | Candidate assets were not revalidated when syncing a recovered draft. A draft naming a missing BMP could replace the prior JSON before final readback detected the problem. | A mock-pad test first reproduced the changed live bytes. Candidate references are now validated before staging/replacement; the test confirms original bytes remain. |
| Fix — resolved | The open-time BMP check accepted an inconsistent DIB-header/palette offset. | Reproduced with a mutated real bitmap; header/palette bounds are now checked at the open boundary. |
| Fix — resolved | An oversized candidate could exceed the limit enforced when reopening the file. | Candidate-size validation now runs before writing. A mock-pad test confirms no replacement. |
| Fix — resolved | Macro delay display narrowed arbitrary valid numeric data to a machine integer. | Display formatting no longer traps on a large delay; a UI-model check verifies numeric round-trip without integer narrowing. |
| Fix — resolved | Local working-draft recovery only checked layer count. | Recovery now checks pad identity, original-layout fingerprint and draft digest. A test restores on the correct pad and rejects a different selected folder. Volume identity uses the available stable UUID rather than relying on a transient device number. |
| Fix — resolved | Opening another destination needed an explicit non-editable state while validation is pending. | Added Opening; editing/sync are disabled until open completes, and stale connection polls cannot override a different selected destination. |
| Fix — resolved during implementation | Layer tabs were clipped; the native bitmap decoder produced a black OLED preview. | Responsive stage sizing/clipping and explicit one-bit palette decoding fix both. Final content renders and native inspection show complete tabs and the actual still bitmap. |
| Accept — owner review pending | Native system/rounded typography and SF Symbols substitute for the web mockup's Outfit/Work Sans and inline SVG set. | Preserves a local, dependency-free Mac build and the Porcelain palette/layout. Owner may accept this native treatment or request bundled-font/icon fidelity work. |
| Accept — owner review pending | The action selector includes **None** in addition to the five illustrated segments; native key/modifier controls and basic macro fields are more explicit than the stylised mockup. | Supports the complete current contract without losing actions. Owner decides whether this compact first-slice presentation is acceptable. |
| Defer — approved slice staging | The editor shows three actual layers, current labels/stills, and **selected** layer; it does not install the five mockup layers or pretend to show live pad state. | Matches the approved slice-1 boundary. Live telemetry and menu switching belong to slice 5. |
| Defer — approved slice staging | Hold/combo editing, recording/Run, layer management, icon editing and Display/animation tooling. | Existing configuration is preserved; the browser remains the working tool. These are later slices, with no new firmware features in slice 1. |
| Defer — manual lifecycle check | The menu-bar item is built and the app launches. After closing its window, the automation surface could not attach to a windowless app to exercise **Open Studio**. | Owner should check close → menu-bar Open Studio → Quit. Windowless automation timeout is not evidence that the app quit or that reopening passed. |
| Defer — Step 5 | Actual CIRCUITPY rename/replacement, flash/cache behaviour, auto-reload, physical actions, and reconnect identity. | Not established by APFS mock folders or fault injection. Complete the checklist below before device acceptance. |

## Verification observed

Environment: installed macOS 26.6.2, Xcode 27.0, Swift 6.4, arm64. App deployment
target is macOS 13; execution on macOS 13 itself was not tested. No dependencies
were downloaded and no signing certificate was needed for build/launch.

- `xcrun swift test --package-path studio --scratch-path studio/.build`:
  **14 core tests + 5 UI/session tests passed** after the review corrections.
  Session checks were rerun after the final Opening-state change.
- Core checks cover current/missing-knob v1 files; all action/macro step types;
  holds, encoders, combos and unknown-field preservation; precise large integer
  preservation; bitmap interpretation; candidate validation; symlink/path escape;
  external edits/volume mismatch; duplicate sync; every sync checkpoint;
  simulated read-only/full/partial-write/bad-stage failures; and post-replacement
  disconnect/reconciliation.
- Native UI automation opened a disposable `studio/.build/MockPad`, edited an
  action and label, applied/reverted via keyboard Undo, switched editor layers,
  and synced the mock folder. The saved key became a text action containing
  `studio test`. A later smoke check verified label Apply/Undo on the reviewed
  bundle and the fixed tabs/OLED. No `/Volumes/CIRCUITPY` was opened or written.
- Chrome imported the native-written mock keymap and displayed its text action,
  hold action and both combos without a format error. Separately,
  `node studio/scripts/check-browser.cjs <native-output> <mock-output>` confirms
  the actual browser normalizer preserves both files semantically unchanged.
- Both native outputs load through `checks/host_config_loader.py` using actual
  KMK keys; all three layers, `knob: false` and combo positions `(0,2)` and
  `(6,8)` remain. This adapter stubs hardware/time/scheduling; it does not test
  USB or execute macros on the Mac.
- `python3 -m py_compile config_loader.py`, `python3 checks/check_layer_switch.py`,
  `node checks/check_configurator.cjs`, and
  `python3 studio/scripts/key-names.py --check` pass. The resource matches 301
  names resolved from the vendored firmware.
- Compared the browser-rendered approved Keys mockup with the native content
  render and actual native window screenshot. Palette, rail/stage/inspector,
  recessed 3×3 wells, selection, knob label, still OLED and real data are present.
  Differences are classified above; this is not a pixel-identical acceptance.
- Final `git diff --check` and firmware/configurator scope checks pass. The README
  image/relative-file links were checked locally. Runtime snapshots omit user
  paths; compiled products and mock keymaps remain ignored.

Native render evidence: [Keys window](../docs/images/studio-keys.png) and
[device preview](../docs/images/macropad-preview.png). Visual reference:
[`porcelain.html`](../design-mockups/porcelain.html). See also the
[Studio build/recovery guide](../studio/README.md).

## What to test on the pad — owner, Step 5

1. Keep `CIRCUITPY` visible and copy its current `keymap.json` to your Mac as a
   recovery baseline. No new firmware is required for this slice; use the
   existing plan-009 firmware. Keep the rescue instructions available.
2. Run `./studio/scripts/build-app.sh`, open
   `studio/.build/Macropad Studio.app` in Finder, then choose **Open pad…** and
   select the actual `CIRCUITPY` folder. Confirm three real layers/keys, the
   static screen preview and **Knob · not fitted**. **Selected** is the editor
   layer; use 7+9 to switch the physical pad.
3. In the editor, select a convenient key on the MEDIA layer and temporarily
   set **When pressed → Text**, with a short ASCII string such as
   `studio test` and label `TEST`. **Apply to draft**. Check Undo once, then
   reapply. **Sync to pad**. Expect **Saved to pad; firmware reload not verified**.
4. Check the serial console for no `Traceback`/`keymap.json error`, and press the
   edited physical key in a blank text document. Confirm it types the string
   exactly once and its label/toast appears as expected. This validates the
   real volume's replacement/reload behaviour; the app's save message alone
   does not.
5. Confirm 7+9 cycles MEDIA → CODE → MEET → MEDIA, each single key 7/9 still
   works, 1+3 still locks the screen, and unrelated actions/holds remain intact.
   Check OLED/LED follow the physical layer (LED requires `neopixel.mpy`).
6. In Chrome, import the same on-pad `keymap.json` into the browser configurator.
   Confirm the edited action, all layers, hold actions, encoder settings and
   combos load without errors. Do not save over it unless you intend an edit.
7. With an applied but **unsynced** draft, disconnect the pad. Confirm Studio
   retains the draft and disables Sync. Reconnect, use **Inspect reconnected
   pad**, and confirm the original file is recognised before an explicit retry.
   Do not deliberately unplug during flash writes as part of the basic check.
8. Close the Studio window, reopen it from its menu-bar item, then test Quit.
   Check keyboard focus/Tab navigation and that ⌘Z/⌘S do the expected actions.
9. Restore the temporary test key to its original action, apply and sync, then
   verify it on the pad. Report any differences listed for owner acceptance.

If a real sync fails, JSON becomes invalid, the pad is unresponsive, or an
individual key drops/doubles: **stop and report the error**. Restore the saved
known config with owner oversight (safe mode if needed); do not tune timeouts,
change firmware or blindly retry. A post-replacement error is uncertain until
readback identifies old/new/invalid data on the same selected pad. Prior-file
backups are in the app's local Recovery directory; no automatic restore runs.

## Coordination and next action

One worker; zero delegated agents. One drift clarification from the owner
established the new baseline; no additional product clarification was required
while building. Sandbox prompts were needed for Git metadata and Swift caches.
Native automation occasionally needed rebinding after modal/window changes;
Chrome import and the native edit/sync workflow were eventually observed.
Exact elapsed coordination time was not measured; no performance claim is made.

Step 3 is delivered for review; Step 4's separate pass and corrections are done.
The full plan remains **IN PROGRESS** for owner acceptance of the visual items
and the Step 5 hardware checklist. No push, merge or deployment is implied.
Next safe action: owner reviews the two Accept items, then performs Step 5.
