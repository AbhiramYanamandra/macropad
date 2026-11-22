"""Regenerate or --check the app's names against this repository's KMK."""
import ast
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'checks'))
import host_config_loader
from kmk.keys import KC

names = set('ABCDEFGHIJKLMNOPQRSTUVWXYZ') | {f'N{i}' for i in range(10)} | {f'F{i}' for i in range(1, 25)}
for file in ('kmk/keys.py', 'kmk/extensions/media_keys.py'):
    for node in ast.walk(ast.parse((root / file).read_text())):
        if isinstance(node, ast.Constant) and isinstance(node.value, str) and node.value.replace('_', '').isalnum():
            names.add(node.value)
valid = []
for name in sorted(names):
    key = KC.get(name)
    if key is not None and (key is not KC.NO or name in ('NO', 'XXXXXXX')):
        valid.append(name)
path = root / 'studio/Sources/StudioCore/Resources/key-names.json'
if '--check' in sys.argv:
    assert json.loads(path.read_text()) == valid, 'KMK names changed: regenerate the Studio resource'
else:
    path.write_text(json.dumps(valid, indent=2) + '\n')
print(f'{len(valid)} firmware key names verified')
