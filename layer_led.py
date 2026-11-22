'''Onboard XIAO RP2040 NeoPixel that shows the active layer's color.

Needs lib/neopixel.mpy (Adafruit CircuitPython Library Bundle 10.x).
If it fails to start, KMK drops this module and the keys keep working.
'''

import board
import digitalio
import neopixel

from kmk.modules import Module


class LayerLed(Module):
    def __init__(self, colors, brightness=0.05):
        self.colors = colors  # (r, g, b) per layer
        self.brightness = brightness
        self._last_layer = None
        self._pixel = None
        self._power = None

    def during_bootup(self, keyboard):
        self._power = digitalio.DigitalInOut(board.NEOPIXEL_POWER)
        self._power.switch_to_output(value=True)
        self._pixel = neopixel.NeoPixel(
            board.NEOPIXEL, 1, brightness=self.brightness, auto_write=True
        )

    def before_matrix_scan(self, keyboard):
        layer = keyboard.active_layers[0]
        if layer != self._last_layer:
            self._last_layer = layer
            self._pixel[0] = self.colors[layer % len(self.colors)]

    def after_matrix_scan(self, keyboard):
        return

    def before_hid_send(self, keyboard):
        return

    def after_hid_send(self, keyboard):
        return

    def on_powersave_enable(self, keyboard):
        self._pixel[0] = (0, 0, 0)

    def on_powersave_disable(self, keyboard):
        self._last_layer = None

    def deinit(self, keyboard):
        if self._pixel:
            self._pixel.deinit()
        if self._power:
            self._power.deinit()
