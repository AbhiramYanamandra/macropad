'''Run with python3 checks/check_layer_switch.py from the repository root.'''

import copy
import json
from types import SimpleNamespace

import host_config_loader as c

cfg = json.load(open('keymap.json'))
cfg['settings']['knob'] = False
cfg['combos'] = [x for x in cfg['combos'] if sorted(x['keys']) != [6, 8]]
for layer in cfg['layers']:
    layer['encoder']['press'] = {'type': 'none'}
built = c.Builder(cfg).build()
assert built['knob'] is False
assert any(tuple(sorted(x['coords'])) == (6, 8) for x in built['combos'])
print('ok')

combo = next(x['key'] for x in built['combos'] if sorted(x['coords']) == [6, 8])
keyboard = SimpleNamespace(active_layers=[0])
for expected in (1, 2, 0, 1, 2, 0):
    combo.on_press(keyboard)
    combo.on_release(keyboard)
    assert keyboard.active_layers == [expected]

previous = c.Builder(cfg).action({'type': 'layer', 'layer': 'prev'}, None)
for expected in (2, 1, 0):
    previous.on_press(keyboard)
    assert keyboard.active_layers == [expected]
keyboard.active_layers[:] = [2, 0]
combo.on_press(keyboard)
assert keyboard.active_layers == [0], 'TO must deactivate other layers'

legacy = copy.deepcopy(cfg)
del legacy['settings']['knob']
assert c.Builder(legacy).build()['knob'] is False
fitted = copy.deepcopy(cfg)
fitted['settings']['knob'] = True
assert not any(sorted(x['coords']) == [6, 8] for x in c.Builder(fitted).build()['combos'])

for action in (
    {'type': 'layer', 'layer': 1},
    {'type': 'key', 'key': 'A', 'hold': {'type': 'layer', 'layer': 1}},
):
    custom = copy.deepcopy(cfg)
    custom['layers'][0]['keys'][0] = action
    assert not any(sorted(x['coords']) == [6, 8] for x in c.Builder(custom).build()['combos'])

custom = copy.deepcopy(cfg)
custom['combos'].append({'keys': [8, 6], 'action': {'type': 'key', 'key': 'A'}})
assert sum(sorted(x['coords']) == [6, 8] for x in c.Builder(custom).build()['combos']) == 1
custom['combos'] = [{'keys': [0, 1], 'action': {'type': 'layer', 'layer': 'next'}}]
assert len(c.Builder(custom).build()['combos']) == 1

fallback = c.Builder(c.FALLBACK).build()
fallback['combos'][0]['key'].on_press(keyboard)
assert keyboard.active_layers == [0]
assert len(fallback['encoder_map']) == 1

actual, error = c.load()
assert error is None
assert actual['knob'] is False
print('loader cycling, legacy defaults, fallback and custom switches: ok')
