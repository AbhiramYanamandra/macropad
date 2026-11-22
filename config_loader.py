'''Turns keymap.json (written by the configurator app) into KMK objects.

The JSON format is documented in configurator/FORMAT.md. Every module that
creates keys (MediaKeys, Macros, Layers, HoldTap) must be constructed BEFORE
build() runs, because KC.MACRO / KC.TO / KC.HT / KC.VOLU only exist after that.
'''

import json

from kmk.keys import KC
from kmk.modules.macros import Delay, Press, Release, Tap

KEY_COUNT = 9
MAX_LAYERS = 8
MOD_NAMES = ('LCTL', 'LSFT', 'LALT', 'LCMD', 'RCTL', 'RSFT', 'RALT', 'RCMD')

# Used when keymap.json is missing or broken, so the pad is never dead.
FALLBACK = {
    'version': 1,
    'layers': [
        {
            'name': 'FALLBACK',
            'image': None,
            'color': '#ff8000',
            'keys': [
                {'type': 'key', 'key': 'MPRV', 'label': 'PREV'},
                {'type': 'key', 'key': 'MPLY', 'label': 'PLAY'},
                {'type': 'key', 'key': 'MNXT', 'label': 'NEXT'},
            ]
            + [{'type': 'none'}] * 6,
            'encoder': {
                'ccw': {'type': 'key', 'key': 'VOLD', 'label': 'VOL-'},
                'cw': {'type': 'key', 'key': 'VOLU', 'label': 'VOL+'},
                'press': {'type': 'key', 'key': 'MUTE', 'label': 'MUTE'},
            },
        }
    ],
    'combos': [],
}


class ConfigError(Exception):
    pass


def parse_color(value):
    if not value:
        return (0, 0, 0)
    value = value.lstrip('#')
    if len(value) != 6:
        raise ConfigError('bad color ' + value)
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


class Builder:
    def __init__(self, cfg):
        self.cfg = cfg
        self.settings = cfg.get('settings', {})
        self.layers = cfg.get('layers', [])
        if not 1 <= len(self.layers) <= MAX_LAYERS:
            raise ConfigError('need 1-%d layers' % MAX_LAYERS)

    def key(self, name):
        found = KC.get(name)
        # KMK returns KC.NO for unknown names instead of raising
        if found is None or (found is KC.NO and name not in ('NO', 'XXXXXXX')):
            raise ConfigError('unknown key ' + str(name))
        return found

    def chord(self, spec):
        k = self.key(spec['key'])
        for mod in spec.get('mods', []):
            if mod not in MOD_NAMES:
                raise ConfigError('bad modifier ' + str(mod))
            k = self.key(mod)(k)
        return k

    def layer_target(self, target, here):
        n = len(self.layers)
        if target == 'next':
            return (here + 1) % n
        if target == 'prev':
            return (here - 1) % n
        target = int(target)
        if not 0 <= target < n:
            raise ConfigError('layer %d does not exist' % target)
        return target

    def macro_step(self, step):
        kind = step.get('do')
        if kind == 'tap':
            return Tap(self.chord(step))
        if kind == 'press':
            return Press(self.chord(step))
        if kind == 'release':
            return Release(self.chord(step))
        if kind == 'delay':
            return Delay(int(step.get('ms', 100)))
        if kind == 'text':
            return str(step.get('text', ''))
        raise ConfigError('bad macro step ' + str(kind))

    def action(self, spec, here):
        if not spec:
            return KC.NO
        kind = spec.get('type', 'none')
        if kind == 'none':
            result = KC.NO
        elif kind == 'key':
            result = self.chord(spec)
        elif kind == 'text':
            result = KC.MACRO(str(spec.get('text', '')))
        elif kind == 'macro':
            steps = [self.macro_step(s) for s in spec.get('steps', [])]
            result = KC.MACRO(*steps) if steps else KC.NO
        elif kind == 'layer':
            target = self.layer_target(spec.get('layer', 'next'), here)
            mode = spec.get('mode', 'to')
            makers = {'to': KC.TO, 'mo': KC.MO, 'tg': KC.TG, 'df': KC.DF}
            if mode not in makers:
                raise ConfigError('bad layer mode ' + str(mode))
            result = makers[mode](target)
        else:
            raise ConfigError('bad action type ' + str(kind))

        hold = spec.get('hold')
        if hold and hold.get('type', 'none') != 'none':
            result = KC.HT(
                result,
                self.action(hold, here),
                tap_time=int(self.settings.get('hold_ms', 220)),
            )
        return result

    def build(self):
        keymap, encoder_map = [], []
        key_labels, encoder_labels = [], []
        names, images, colors = [], [], []
        for i, layer in enumerate(self.layers):
            keys = layer.get('keys', [])
            if len(keys) != KEY_COUNT:
                raise ConfigError('layer %d needs %d keys' % (i, KEY_COUNT))
            keymap.append([self.action(k, i) for k in keys])
            key_labels.append([(k or {}).get('label', '') for k in keys])
            enc = layer.get('encoder', {})
            encoder_map.append(
                (
                    (
                        self.action(enc.get('ccw'), i),
                        self.action(enc.get('cw'), i),
                        self.action(enc.get('press'), i),
                    ),
                )
            )
            encoder_labels.append(
                (
                    (enc.get('ccw') or {}).get('label', ''),
                    (enc.get('cw') or {}).get('label', ''),
                )
            )
            names.append(str(layer.get('name', 'LAYER %d' % (i + 1)))[:10])
            images.append(layer.get('image') or None)
            colors.append(parse_color(layer.get('color')))

        combos = []
        for c in self.cfg.get('combos', []):
            coords = tuple(int(x) for x in c.get('keys', []))
            if len(coords) < 2 or len(set(coords)) != len(coords):
                raise ConfigError('combo needs 2+ different keys')
            if not all(0 <= x < KEY_COUNT for x in coords):
                raise ConfigError('combo key out of range')
            combos.append(
                {
                    'coords': coords,
                    'key': self.action(c.get('action'), 0),
                    'label': (c.get('action') or {}).get('label', ''),
                }
            )

        return {
            'keymap': keymap,
            'encoder_map': encoder_map,
            'key_labels': key_labels,
            'encoder_labels': encoder_labels,
            'names': names,
            'images': images,
            'colors': colors,
            'combos': combos,
            'settings': self.settings,
        }


def load(path='keymap.json'):
    '''Returns (built_config, error_message_or_None). Never raises.'''
    try:
        with open(path) as f:
            cfg = json.load(f)
        return Builder(cfg).build(), None
    except Exception as e:  # missing file, bad JSON, bad key name...
        message = '%s: %s' % (e.__class__.__name__, e)
        print('keymap.json error ->', message)
        return Builder(FALLBACK).build(), message
