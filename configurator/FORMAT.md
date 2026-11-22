# keymap.json format (version 1)

Written by `configurator/index.html`, read on the pad by `config_loader.py`.
You normally never edit it by hand.

```jsonc
{
  "version": 1,
  "settings": {
    "knob": false,          // true when a rotary encoder is fitted
    "hold_ms": 220,          // tap vs hold threshold
    "combo_timeout": 80,     // keys pressed within this window count as a combo
    "toast_ms": 1200,        // how long a label shows on the OLED (0 = off)
    "led_brightness": 0.05,  // onboard NeoPixel, 0..1
    "dim_s": 20, "off_s": 60 // OLED dim / off after inactivity
  },
  "layers": [                // 1..8 layers
    {
      "name": "MEDIA",       // ASCII, max 10 chars; shown on the OLED
      "image": "lib/x.bmp",  // 128x32 1-bit BMP, or null to show the name
      "color": "#0050ff",    // LED color on this layer
      "keys": [ /* exactly 9 actions, positions 1..9 */ ],
      "encoder": { "ccw": action, "cw": action, "press": action }
    }
  ],
  "combos": [                // global, every layer
    { "keys": [0, 2], "action": action }   // 0-based key positions, 2+ keys
  ]
}
```

`knob` defaults to `false` when missing. When false the encoder is ignored,
and keys 7 + 9 switch to the next layer unless the keymap defines its own
layer switch on a key, a hold action or a combo. An existing combo on those
same positions (`[6, 8]`) is preserved. Encoder controls remain editable in
the configurator while marked "Knob · not fitted"; Try it ignores them.
When the knob is fitted, enable "Knob fitted" in Settings and save. The
explicit 7 + 9 combo stays as a backup until removed.

## Actions

Every action may carry `"label"` (ASCII, at most 10 characters), the text shown on the OLED when it fires.

| type | fields | example |
|---|---|---|
| `none` | | `{"type":"none"}` |
| `key` | `key` (KMK name), `mods` (`LCTL` `LSFT` `LALT` `LCMD`, plus the `R…` variants) | `{"type":"key","key":"P","mods":["LCMD","LSFT"]}` |
| `text` | `text` (ASCII) | `{"type":"text","text":"Be right back"}` |
| `macro` | `steps`: `{"do":"tap"/"press"/"release","key":…,"mods":[…]}`, `{"do":"delay","ms":100}`, `{"do":"text","text":"…"}` | |
| `layer` | `mode`: `to` (switch), `mo` (while held), `tg` (toggle), `df`; `layer`: index, `"next"` or `"prev"` | `{"type":"layer","mode":"to","layer":"next"}` |

A key action (not an encoder or combo action) may also have `"hold": action`.
It does that action when held longer than `hold_ms` (KMK `KC.HT`).

For `mode: "to"`, `"next"` and `"prev"` cycle from the current active layer
at press time in every context, including global combos and hold actions.
They wrap at either end. Other layer modes resolve relative targets from
the action's configured layer (layer 0 for global combos).

Key names are KMK names: `A`–`Z`, `N0`–`N9`, `F1`–`F20`, `UP`, `DOWN`, `LEFT`, `RIGHT`,
`ENT`, `ESC`, `TAB`, `SPC`, `BSPC`, `DEL`, `MINS`, `EQL`, `GRV`, `SLSH`, and so on. Media keys are `MPLY`, `MNXT`,
`MPRV`, `VOLU`, `VOLD`, `MUTE`, `BRIU`, `BRID`, …

If the file is missing or invalid, the pad falls back to a basic media layout and
shows `keymap.json error` on the OLED. The reason is printed on the serial console.
