# Macropad firmware

CircuitPython and KMK firmware for an RP2040 macropad. Numbered plans live in `plans/`.

## KAREN OS

This project uses the KAREN OS shared rules. Before acting, read `karen_os_path`
from `.karen/project.json` and run
`python3 -B <karen_os_path>/scripts/startup.py read --project .`
Follow the shared core it returns. If the command fails or reports the project
as invalid, say the shared rules are unavailable and do read-only work only.
If it reports stale, tell the owner before acting. Rules in this file may add
restrictions to the shared rules but never remove them. This session may read
only this project and the KAREN OS core, and may not read or change other projects.
