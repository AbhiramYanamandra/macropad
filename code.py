'''Macropad firmware: XIAO RP2040, 3x3 matrix, rotary encoder, 128x32 OLED.

Key actions live in keymap.json, edited with the configurator app
(open configurator/index.html in Chrome). This file is only wiring.
'''

import board
import busio

from kmk.extensions.display import ImageEntry, TextEntry
from kmk.extensions.display.ssd1306 import SSD1306
from kmk.extensions.media_keys import MediaKeys
from kmk.kmk_keyboard import KMKKeyboard
from kmk.modules.combos import Chord, Combos
from kmk.modules.holdtap import HoldTap
from kmk.modules.layers import Layers
from kmk.modules.macros import Macros
from kmk.scanners import DiodeOrientation

import config_loader
from macropad_display import KeyToasts, LayerDisplay, ToastEncoderHandler

# ---- Keyboard + matrix -------------------------------------------------
kbd = KMKKeyboard()
kbd.col_pins = (board.D0, board.D2, board.D9)
kbd.row_pins = (board.D1, board.D3, board.D8)
kbd.diode_orientation = DiodeOrientation.COL2ROW

# ---- Modules that define keys: must exist before the config is built ---
kbd.extensions.append(MediaKeys())
combos = Combos()
layers = Layers()
holdtap = HoldTap()
macros = Macros()
encoder_handler = ToastEncoderHandler()
encoder_handler.pins = ((board.D10, board.D7, board.D6),)  # (A, B, button)

# ---- Load keymap.json --------------------------------------------------
cfg, config_error = config_loader.load()
settings = cfg['settings']

kbd.keymap = cfg['keymap']
encoder_handler.map = cfg['encoder_map']
encoder_handler.labels = cfg['encoder_labels']
combos.combos = [
    Chord(
        c['coords'],
        c['key'],
        match_coord=True,
        timeout=int(settings.get('combo_timeout', 80)),
    )
    for c in cfg['combos']
]

# ---- Display (SSD1306 128x32 on I2C D4/D5) ----------------------------
entries = []
for i, name in enumerate(cfg['names']):
    entry = None
    if cfg['images'][i]:
        try:
            entry = ImageEntry(image=cfg['images'][i], x=0, y=0, layer=i)
        except OSError:
            print('missing image', cfg['images'][i])
    if entry is None:
        entry = TextEntry(text=name, x=64, y=16, x_anchor='M', y_anchor='M', layer=i)
    entries.append(entry)
if config_error:
    entries.append(TextEntry(text='keymap.json error', x=0, y=0, layer=None))

i2c = busio.I2C(scl=board.D5, sda=board.D4, frequency=400_000)
display_ext = LayerDisplay(
    display=SSD1306(i2c=i2c),
    entries=entries,
    height=32,
    layer_names=cfg['names'],
    toast_ms=int(settings.get('toast_ms', 1200)),
    dim_time=int(settings.get('dim_s', 20)),
    off_time=int(settings.get('off_s', 60)),
)
kbd.extensions.append(display_ext)
encoder_handler.toast_display = display_ext

# ---- Module order matters: toasts see raw presses, combos run early ----
kbd.modules = [
    KeyToasts(display_ext, cfg['key_labels']),
    combos,
    layers,
    holdtap,
    macros,
    encoder_handler,
]

try:
    from layer_led import LayerLed

    kbd.modules.append(
        LayerLed(cfg['colors'], brightness=float(settings.get('led_brightness', 0.05)))
    )
except ImportError as e:  # lib/neopixel.mpy not installed yet
    print('layer LED disabled:', e)

if __name__ == '__main__':
    print('Starting keyboard...')
    kbd.go()
