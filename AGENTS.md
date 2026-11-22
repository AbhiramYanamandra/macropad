# Macropad firmware

CircuitPython and KMK firmware for an RP2040 macropad. Numbered plans live in `plans/`.

## KAREN OS

This project uses the KAREN OS shared rules. Before acting, read `karen_os_path`
from `.karen/project.json` and run
`python3 -B <karen_os_path>/scripts/startup.py read --project .`
If that path does not exist, as in a cloud session, clone `karen_os_repository`
from GitHub and run the reader from the clone.
Follow the shared core it returns, including the engineering standard. If the
command fails or reports the project as invalid, say the shared rules are
unavailable and do read-only work only. If it reports stale, tell the owner
before acting. Rules in this file may add restrictions to the shared rules but
never remove them. This session may read only this project and the KAREN OS
core, and may not read or change other projects.

## How work happens here

- **Work comes from GitHub issues** in `AbhiramYanamandra/macropad`. Do the issue
  the owner names, otherwise the highest-priority `status:ready` issue.
  Detailed steps may live in a `plans/` file that the issue links.
- **Branch** `<type>/<issue>-<short-description>` from `main`, then open a pull
  request with `Closes #<issue>` using the template. Never push to `main` and
  never merge. The owner merges.
- **CI must pass**: firmware compile and checks, the configurator check, and the
  Mac app's Swift tests (`.github/workflows/checks.yml`).
- **Never write to the pad** (`CIRCUITPY`) or change `kmk/`. Physical checks go
  in the PR's How to test and Not verified sections and get the
  `hardware-check` label.
- **This repository is public.** No personal records, credentials, Wi-Fi
  details or home-directory paths in code, issues or pull requests.
