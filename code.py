print("Starting")

import board
import busio
from i2cdisplaybus import I2CDisplayBus
from kmk.kmk_keyboard import KMKKeyboard
from kmk.keys import KC
from kmk.scanners import DiodeOrientation
from kmk.modules.encoder import EncoderHandler
from kmk.modules.layers import Layers
from kmk.extensions.media_keys import MediaKeys
from kmk.extensions.display.ssd1306 import SSD1306
from kmk.extensions.display import Display, TextEntry, ImageEntry

encoder_handler = EncoderHandler()
kbd = KMKKeyboard()
layers = Layers()

# Initialize I2C
i2c = busio.I2C(scl=board.D5, sda=board.D4)

display_driver = SSD1306(
    i2c=i2c,
)

# Create KMK Display extension with entries
display_ext = Display(
    display=display_driver,
    entries=[
        # TextEntry(text="KMK Ready", x = 0, y = 0, layer = 0),
        # TextEntry(text="Layer: 0", x = 0, y = 16, layer = 0),
        ImageEntry(image="lib/manandmountain.bmp", x=0, y=0, layer=0),
    ],
    height=32,
)

kbd.extensions.append(display_ext)

# Matrix: 3x3 example
kbd.col_pins = (board.D0, board.D2, board.D9)
kbd.row_pins = (board.D1, board.D3, board.D8)
kbd.diode_orientation = DiodeOrientation.COL2ROW

kbd.extensions.append(MediaKeys())
kbd.modules = [layers, encoder_handler]

# Encoder pins
encoder_handler.pins = (
    (board.D10, board.D7, board.D6),
)

# Keymap
kbd.keymap = [
    [KC.N1, KC.N2, KC.N3, KC.N4, KC.N5, KC.N6, KC.N7, KC.N8, KC.N9],
]

# Encoder map
encoder_handler.map = [
    ((KC.VOLD, KC.VOLU, KC.MUTE),),
]

print("Rows:", len(kbd.row_pins), "Cols:", len(kbd.col_pins))
print("Starting keyboard...")

if __name__ == "__main__":
    kbd.go()