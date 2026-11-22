# Porcelain design and contract inventory

Revision 1 · 2026-11-22 · Plan 008 Step 1 · source inspection complete;
browser visual verification outstanding.

## Evidence and boundaries

- Starting commit: `469014d`, clean `main`; work branch: `pilot/008-porcelain`.
- Drift command from plan 008 shows only plan 009's four scoped files.
  The same scoped diff from `b767f6e` to starting HEAD is empty.
- Approved `design-mockups/porcelain.html` SHA-256:
  `8d0638106955c8cb16c39a4ddbca5654a3f03890f31adfe63d3e9b1f33d3e413`.
- Inspected all four screen generators (`menuScreen`, `keysScreen`,
  `displayScreen`, `layersScreen`), shared window/device markup and their data.
  Browser connector failed and native browser access timed out. This inventory
  establishes source coverage, not rendered visual acceptance.
- Contract evidence: `configurator/FORMAT.md`, `config_loader.py`, `code.py`,
  `macropad_display.py`, `layer_led.py`, and the current layout. Plan 009's
  `knob: false` and runtime-relative layer cycling are part of the baseline.
- Only KAREN OS startup core was loaded for this run, as requested by owner.

Classification describes the backing capability, not whether the new native UI
has been built: **existing** means the firmware/format supports it already;
**app-only** needs host implementation but no firmware feature; **needs-firmware**
needs an additional runtime capability. Nothing in this document changes code.

## Shared window and device

| ID | Screen/control/state shown | Classification | Mapping or gap |
|---|---|---|---|
| W01 | Porcelain off-white surfaces, red accent, typography, rounded panels, native window buttons | app-only | Visual reference is `.T2`; use native window lifecycle and reproduce the design tokens. External web fonts are mockup dependencies, not a requirement to load fonts from the network at runtime. |
| W02 | Macropad Studio title; Keys, Display, Layers and Settings navigation, active nav state | app-only | Four app destinations; Settings is a rail control, with no separate Settings screen in this mockup. |
| W03 | “Macropad mk2”, green Connected indicator | app-only | Name is a display label only. Mounted-drive connection can be observed by host; label is not a board identity or discovery protocol. |
| W04 | “layer Code” as the pad's live state | needs-firmware | `active_layers[0]` exists only inside KMK; no app status/telemetry protocol. Selecting a layer in the editor does not prove the pad is using it. |
| W05 | Undo, Sync to pad | app-only | Native undo/draft state and file transaction around version-1 `keymap.json`; firmware already loads this file. |
| W06 | Enclosure drawing: flat slab, recessed 3×3 wells, OLED window, LED; no knob | app-only | Geometry comes from approved drawing, not a new hardware specification. Real labels/actions replace sample data. |
| W07 | Nine numbered key positions, selected outline, icons, combo badges; miniature pad previews | app-only | Keys map to `layers[i].keys[0..8]`; badges derive from `combos[].keys`. Key icons and selection are host decoration; no physical key display exists. |
| W08 | OLED still image/layer-name preview and LED colour | existing | `layers[].image`, `.name`, `.color`; SSD1306 image/name rendering and `LayerLed`. Animating the actual OLED is a separate gap. |
| W09 | “Knob · not fitted”, settings available for later fitting | existing | `settings.knob` defaults false; keep `encoder.ccw/cw/press` editable. No automatic knob detection; no hardware change. |

## Menu bar: everyday use (`menuScreen`)

| ID | Screen/control/state shown | Classification | Mapping or gap |
|---|---|---|---|
| M01 | Menu-bar icon, open popover, device label and connection dot | app-only | Native app/menu lifecycle and mounted-drive status. Finder menus and clock are desktop illustration, not Studio features. |
| M02 | OLED preview of what the pad is currently showing, including Blink | needs-firmware | App can render a draft preview now; live layer/animation state needs telemetry and animation support. Do not label an inferred image “live”. |
| M03 | Media, Code, Meet, Photoshop, Stream rows, colour dots, selected Code | existing | Read actual `layers[].name/color`; only MEDIA/CODE/MEET exist in current layout. Additional sample layers must not be installed implicitly. |
| M04 | Clicking a menu row switches the physical pad layer | needs-firmware | No host-to-KMK command channel. Rewriting a configuration file is not a live layer switch. |
| M05 | `⌃1`–`⌃5` beside layers | app-only | App/menu shortcuts can select editor layers; live switching waits for M04. No system-wide shortcut registration or permissions are implied. |
| M06 | Test mode toggle, off in menu illustration | app-only | Shared local simulator toggle is possible now; clearly identify it as preview. |
| M07 | Test mode that captures real pad presses and suppresses host output | needs-firmware | If desired for the connected device, it needs input events and a suppression mode; current firmware always sends HID. This meaning is not implemented by the mockup. |
| M08 | Open Studio `⌘O`, Quit `⌘Q`; app stays in menu bar with window closed | app-only | Native window/quit behaviour; prompt to preserve dirty drafts or resolve an active sync. |

## 1 · Keys (`keysScreen`)

| ID | Screen/control/state shown | Classification | Mapping or gap |
|---|---|---|---|
| K01 | Layer tabs, active Code tab, colour dots, add-layer plus | existing | `layers[]`, maximum eight; creation is a draft edit. Preserve all referenced layer targets on reorder/deletion. |
| K02 | Combos · 2 entry, combo markings on keys 1 and 3, lock-screen hint | existing | `combos[]`, zero-based coordinates. Current layout has 1+3 LOCK and 7+9 NEXT LYR from plan 009. Combo editor is implied by the entry but not separately drawn. |
| K03 | Screen tag “Blink animation” above the pad | needs-firmware | Still `layers[].image` works; layer animation does not. Host preview alone is app-only. |
| K04 | Select key 5; inspector name/icon, “Key 5 · Code layer”, overflow menu | app-only | Selection and host metadata; overflow actions are not specified in the mockup. Sample “PR review” must not replace the real key action. |
| K05 | When pressed: Shortcut, Macro, Text, Media, Layer segments | existing | Types `key`, `macro`, `text`, `layer`; Media is a UI category for consumer `key` names. Retain `none`/clear even though its segment is not shown. |
| K06 | Four macro steps: ⌘C, wait 120 ms, ⌘V, typed text | existing | `steps[].do = tap/delay/text`; `key/mods/ms/text`. Also preserve `press/release` steps supported by the contract. |
| K07 | Step grips, per-step overflow, Add step, Record, Run | app-only | Reorder/edit draft steps. In-app recording only; no global monitoring. Run initially means simulator playback, not executing a macro on the Mac. Details of overflow menus need slice design. |
| K08 | When held → “Meet while held” | existing | Action `.hold`, `settings.hold_ms`, layer `mode: mo`. ASCII labels ≤10 characters; existing tap/hold semantics remain. |
| K09 | Icon on key → Pull request | app-only | Native icon picker and optional metadata; physical keycaps cannot display icons. No firmware change required for host-only icons. Picker screen not drawn. |
| K10 | Shows on screen → PR REVIEW text preview | existing | Action `.label`, `settings.toast_ms`, `KeyToasts` and `LayerDisplay`. Exact icon/bitmap pop-ups require K11. |
| K11 | Shows on screen with a custom bitmap or animation | needs-firmware | Current pop-ups are text only. New display binding/renderer needed; editor/picker beyond the shown preview is not drawn. |
| K12 | Test mode on, “Key 5 sent…” output summary | app-only | Current browser simulator is a behavioural reference. Native preview should say “would send”; live pad observations require M07. |
| K13 | Next-layer key example and knob-free navigation | existing | Runtime-relative `to/next` and `to/prev`; default 7+9 combo remains unless user defines a switch/occupies those combo coordinates. Never rely on a fitted knob. |

## 2 · Display (`displayScreen`)

| ID | Screen/control/state shown | Classification | Mapping or gap |
|---|---|---|---|
| D01 | Display title; editing “My Blink” for Code; Layer screen selected | app-only | Draft asset name and selected target; key pop-ups and sleep are alternate target tabs, not additional fully drawn screens. |
| D02 | Static layer-screen assignment/import | existing | `layers[].image`: 128×32, 1-bit BMP, or null/name fallback. Existing assets remain valid. |
| D03 | Pencil selected; eraser, bucket, line, rectangle, text, selection; magnified pixel grid | app-only | Bitmap editor tools over 4096 one-bit pixels; export static BMP without new firmware. |
| D04 | Eight numbered frames, frame 4 selected, add-frame tile, Play, duration summary | app-only | Host animation authoring, timeline selection and preview; no claim of device playback. |
| D05 | Speed 12 fps, onion skin on, Loop on | app-only | Editor/playback metadata. The sample 0.7 s is approximately 8/12 s; never hard-code its values for other assets. |
| D06 | Layer screen animation actually plays on pad | needs-firmware | Requires bounded frame storage, timed rendering and fallback image. No frame format exists today. |
| D07 | Key pop-ups: text labels | existing | Per-action `.label` and global `toast_ms`. Current firmware does not expose separate per-key toast durations. |
| D08 | Key pop-ups: authored images/animation | needs-firmware | New per-action display bindings and precedence over layer animations. |
| D09 | Sleep screen tab / custom idle art | needs-firmware | Current `dim_s` and `off_s` dim/turn off display; no custom idle scene. Keep screen-off behaviour as default. |
| D10 | Small pad animation preview; “Plays when Code layer is active” selector | needs-firmware | Host preview app-only; device binding to a layer uses future animation support. Do not invent triggers beyond those reviewed. |
| D11 | Layer-name toggle, “Show for 1.2 s on switch” | existing | Current shared `toast_ms` plus layer-name toast; switching this independently of key pop-ups needs D12. |
| D12 | Separate layer-name visibility/duration and key-pop-up visibility/duration | needs-firmware | Today's shared duration couples both. Add explicit optional display settings in a later slice. |
| D13 | Screen dims after 20 s | existing | `settings.dim_s`; `off_s` remains accessible in Settings. |
| D14 | Size on pad: 2.1 KB of 180 KB free | app-only | Compute encoded bytes and volume free space; sample values are not measurements. Volume free space does not establish firmware RAM headroom. |
| D15 | Library: Import, Animations, Icons, Mine · 3, Search 48 animations | app-only | Local library/import/search and counts derived from actual assets. No 48-item library exists in repository. No cloud catalogue or downloads assumed. |
| D16 | New animation; selected Blink; Equalizer, Wave, Bounce, Starfield, Scanner, Rain, Heartbeat, Bars with frame counts | app-only | Nine sample library entries; reusable authoring assets must be created/reviewed. New animation and import panels are implied, not drawn. Playback on pad remains D06. |

## 3 · Layers (`layersScreen`)

| ID | Screen/control/state shown | Classification | Mapping or gap |
|---|---|---|---|
| L01 | “5 of 8 on the pad”; five cards, colour, name, selected Code | existing | `layers[]`, 1–8. Counts use real config, not mock data. Current pad has three configured layers. |
| L02 | Mini-pad previews; “9 keys”, “2 combos”, still image/animation descriptions | app-only | Derived summaries; global combos must not be presented as Code-only. Animation summaries do not imply firmware capability. |
| L03 | Built-in and Custom badges | app-only | Optional template provenance metadata; built-in does not mean immutable firmware layers. |
| L04 | Card enable toggles (first four on, Stream off) | app-only | Keep disabled layers in local project; compile only enabled layers, remapping numeric targets. Reject an export with zero enabled layers or dangling targets. No existing firmware `enabled` field. |
| L05 | Drag to reorder | app-only | Draft reorder plus complete remap of numeric targets, including holds, encoder and combos; next/prev stay relative. |
| L06 | Import layer, Duplicate, New layer: blank/copy/template | app-only | File import and copying supported action fields; native panels not drawn. Validate/remap imported references and enforce eight exported layers. |
| L07 | Video editing, Design, Gaming, Numpad, Shortcuts, Blank template cards and subtitles | app-only | Template catalogue; no such presets currently ship. Numpad must fit nine keys/layers. macOS Shortcuts needs explicit key bindings or a separately reviewed host integration, not a new firmware action type invented silently. |

## Coverage result and unresolved states

All four captions emitted into the mockup's page are represented above. Shared
controls, every displayed tool, template and animation-library item are mapped.
The HTML is a static presentation: most controls are styled spans/divs, not
implemented interactions. Sample names, counts, outputs and connected state
are illustrations, not acceptance evidence.

Disconnected, connecting, invalid file, permission denied, dirty draft,
conflicting external edits, syncing, unplugged/uncertain sync, unsupported
capability, empty library, record-active and firmware-error states are not
separately drawn. Step 2 must specify their behaviour; later slice review must
approve their visuals. It must also decide whether “Test mode” means local
simulation or physical HID suppression, and how live menu switching is staged.
