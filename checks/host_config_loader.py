'''Host adapter for loader checks; real KMK keys, no USB or scheduler execution.

Run the plan's Step 5 with PYTHONPATH=checks and replace only its loader
import with `import host_config_loader as c`.
'''

import sys
import time
from pathlib import Path
from types import ModuleType

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def module(name, **attrs):
    result = ModuleType(name)
    result.__dict__.update(attrs)
    sys.modules[name] = result


def no_scheduler(*args, **kwargs):
    raise AssertionError('host check cannot schedule hardware work')


module('micropython', const=lambda value: value)
module('supervisor', ticks_ms=lambda: int(time.monotonic() * 1000))
module('usb_cdc', console=None)
module('kmk.scheduler', create_task=no_scheduler)

from kmk.extensions.media_keys import MediaKeys
from kmk.modules.holdtap import HoldTap
from kmk.modules.layers import Layers
from kmk.modules.macros import Macros

MediaKeys()
Layers()
HoldTap()
Macros()

from config_loader import Builder, FALLBACK, load
