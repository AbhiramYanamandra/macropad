# Macropad Studio · Porcelain

Native macOS 13+ editor, plan 008 slice 1. Build locally with the installed
Xcode/Swift toolchain. No dependencies, developer account or signing
certificate are required for this local build. This is not a distribution package.

```sh
./studio/scripts/build-app.sh
```

Open `studio/.build/Macropad Studio.app` in Finder. Choose **Open pad…** and
select the `CIRCUITPY` folder. The menu-bar item opens Studio after its window
is closed and offers Quit.

Select a layer and a key, edit **When pressed**, and use **Apply to draft**.
**Undo** (⌘Z) reverses applied key edits; **Revert** discards unapplied
inspector edits. **Sync to pad** (⌘S) writes only `keymap.json` to the chosen
folder. The label **selected** describes the editor; it is not live pad state.

Shortcut, media, text, layer and macro actions are editable. Each macro step
can tap, press, release, wait or type. Recording, Run, hold editing, combo
editing, Display and Layers management are later slices. Existing data for
those features is preserved. Use the browser configurator for them today.

Sync creates a prior-file backup, candidate and receipt in
`~/Library/Application Support/Macropad Studio/Recovery/<transaction-id>/`.
Applied edits are also retained in `working-draft.json`. To recover after
relaunching, open the same pad folder and choose **Settings → Recover locally
saved draft**; inspect it before syncing. Recovery verifies the selected pad,
the draft digest and the original layout fingerprint before applying it. Unapplied inspector edits are not
saved. A conflict blocks writes. **Inspect reconnected pad** compares the
actual file with the original and draft, without replaying a write.

## Checks

From the repository root:

```sh
xcrun swift test --package-path studio --scratch-path studio/.build
python3 -m py_compile config_loader.py
python3 checks/check_layer_switch.py
python3 studio/scripts/key-names.py --check
node checks/check_configurator.cjs
```

Set `STUDIO_EXPORT_DIR` to a disposable folder to export a Swift-written
keymap from the contract test. Set `STUDIO_SCREENSHOT_DIR` to an output folder
for native render snapshots from the UI tests. Use absolute output paths;
SwiftPM runs tests from the `studio/` package directory. The tests use temporary mock
pads, never `/Volumes/CIRCUITPY`. Mock filesystems do not establish USB/FAT
power-loss safety. Complete the human checklist in
[`plans/008-slice-1-review.md`](../plans/008-slice-1-review.md) before declaring
the slice validated on hardware.

Supported firmware key names are a snapshot of this repository's KMK keys and
MediaKeys, validated through `checks/host_config_loader.py`; update the resource
when upgrading KMK. No vendor code or keymap schema changes are needed here.
