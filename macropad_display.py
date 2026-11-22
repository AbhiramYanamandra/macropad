'''Project-local display behaviour on top of KMK's Display extension.

Kept outside kmk/ so upgrading the vendored KMK can't drop it.
- LayerDisplay: wakes on layer change, shows a short inverted "toast".
- ToastEncoderHandler: toasts the label of each encoder turn.
- KeyToasts: toasts the label of each key press.
'''

from supervisor import ticks_ms

import terminalio
from adafruit_display_text import label

from kmk.extensions.display import Display
from kmk.kmktime import ticks_diff
from kmk.modules import Module
from kmk.modules.encoder import EncoderHandler


class LayerDisplay(Display):
    def __init__(self, *args, layer_names=None, toast_ms=1200, **kwargs):
        super().__init__(*args, **kwargs)
        self.layer_names = layer_names
        self.toast_ms = toast_ms
        self._toast = None
        self._toast_at = 0
        self._pending = None

    def render(self, layer):
        # KMK only counts matrix events as activity; a layer change made by
        # the encoder would otherwise leave a sleeping screen dark.
        self.timer_start = ticks_ms()
        super().render(layer)
        self._toast = label.Label(
            terminalio.FONT,
            text=' ',
            color=0x000000,
            background_color=0xFFFFFF,
            anchor_point=(1.0, 1.0),
            anchored_position=(self.width - 1, self.height - 1),
            padding_left=1,
            padding_right=1,
        )
        self._toast.hidden = True
        self.display.root_group.append(self._toast)
        if self._pending:
            self.show_toast(self._pending)
            self._pending = None
        elif self.layer_names and 0 <= layer < len(self.layer_names):
            self.show_toast(self.layer_names[layer])

    def show_toast(self, text):
        if not text or not self.toast_ms:
            return
        if self._toast is None:
            self._pending = text  # shown once the first render happens
            return
        self._toast.text = text
        self._toast.hidden = False
        self._toast_at = ticks_ms()
        self.timer_start = self._toast_at  # counts as activity: wakes screen

    def before_matrix_scan(self, sandbox):
        super().before_matrix_scan(sandbox)
        if (
            self._toast is not None
            and not self._toast.hidden
            and ticks_diff(ticks_ms(), self._toast_at) > self.toast_ms
        ):
            self._toast.hidden = True


class ToastEncoderHandler(EncoderHandler):
    def __init__(self):
        super().__init__()
        self.toast_display = None
        self.labels = None  # per layer: (ccw_text, cw_text)

    def on_move_do(self, keyboard, encoder_id, state):
        super().on_move_do(keyboard, encoder_id, state)
        if self.toast_display is None or not self.labels:
            return
        layer = keyboard.active_layers[0]
        if layer < len(self.labels):
            text = self.labels[layer][0 if state['direction'] == -1 else 1]
            self.toast_display.show_toast(text)


class KeyToasts(Module):
    '''Put FIRST in kbd.modules so it sees raw key positions.'''

    def __init__(self, display, labels):
        self.display = display
        self.labels = labels  # per layer: 9 label strings

    def process_key(self, keyboard, key, is_pressed, int_coord):
        if is_pressed and isinstance(int_coord, int):
            layer = keyboard.active_layers[0]
            if layer < len(self.labels) and int_coord < len(self.labels[layer]):
                self.display.show_toast(self.labels[layer][int_coord])
        return key

    def during_bootup(self, keyboard):
        return

    def before_matrix_scan(self, keyboard):
        return

    def after_matrix_scan(self, keyboard):
        return

    def before_hid_send(self, keyboard):
        return

    def after_hid_send(self, keyboard):
        return

    def on_powersave_enable(self, keyboard):
        return

    def on_powersave_disable(self, keyboard):
        return
