# Raspberry_Pi_Grove_Pi_setup
A fix for the original setup script of the GrovePi+ for the Raspberry Pi 4B

## Why this exists

The original GrovePi installer, and the `RFR_Tools` bash installer it depends on, assume Python 2 and an unversioned `python` executable. Neither exists on Debian Trixie anymore, so the original script fails outright. This fork keeps the same overall structure and command-line interface, but:

- Uses **Python3 / pip3 exclusively** — no `python`, `python2`, or `pip` (unversioned) anywhere.
- Replaces the legacy `RFR_Tools` bash installer with **[mr-rfr-tools](https://pypi.org/project/mr-rfr-tools/)**, Dexter Industries' own pure-Python3 successor package (provides `di_i2c`, `di_mutex`, `auto_detect_robot`).
- Works around several packaging/dependency issues that only show up on Trixie (see [What's different from the original script](#whats-different-from-the-original-script) below).

**This was adapted with AI assistance**, based on the original script and iterative testing on real hardware. It is **not officially supported by Dexter Industries**.

## Project context

This fork was put together to simplify GrovePi+ setup for a university project. It fixes just enough to get the original installer working on current hardware/OS — it is **not actively maintained**: no further updates or bug fixes are planned beyond what's already here. If you hit an issue not covered in [Known limitations](#known-limitations), you're welcome to fork and fix it yourself.

## Disclaimer

This script is provided **as is, with no warranty of any kind**. It installs system packages, modifies configuration files (`/etc/modules`, `/boot/config.txt`), and clones/builds third-party repositories as `root` (via `sudo`). **Read the script before running it.** The author(s) assume no responsibility for any damage, data loss, or broken system state resulting from its use. **Use at your own risk.**

| | |
|---|---|
| **Last tested** | October 2, 2026 |
| **OS tested** | Debian Trixie (13), arm64 |
| **Hardware tested** | Raspberry Pi 4B (8GB RAM) |
| **Upstream source** | [DexterInd/GrovePi](https://github.com/DexterInd/GrovePi) |

If you run this on different hardware or a different OS version, please open an issue with your results (success or failure) — it helps keep this list accurate.

## Requirements

- A Raspberry Pi running Debian Trixie (or a compatible derivative) on the `pi` user.
- `git` and internet access (the script clones GrovePi and fetches `script_tools` / `mr-rfr-tools` at runtime).
- Must be run as the `pi` user (the script checks this and exits otherwise).

## Usage

```bash
chmod +x install_grovepi.sh
./install_grovepi.sh
```

Don't run it with `sh install_grovepi.sh` — `sh` is `dash` on Debian/Raspberry Pi OS and doesn't support the bash syntax used here (`[[ ]]`, `pushd`/`popd`, etc.). Use `./install_grovepi.sh` or `bash install_grovepi.sh`.

The script asks for a `y/N` confirmation before making any system change.

## What's different from the original script

| Issue on Trixie | Fix in this version |
|---|---|
| `RFR_Tools` bash installer requires `python2` | Replaced with `mr-rfr-tools` via `pip3` |
| `setup.py install` broken with modern setuptools (`AttributeError: install_layout`) | Uses `pip3 install .` instead |
| `smbus-cffi`'s own legacy `setup.py` fails the same way as a transitive dependency | Pre-installed with `pip3` beforehand so it's already satisfied |
| `python3-rpi.gpio` (apt) conflicts with `python3-rpi-lgpio` (needed on Pi 5) | Removed from the apt dependency list; `RPi.GPIO` is pulled in via `pip` instead if needed |
| `libncurses5` no longer packaged on Trixie | Replaced with `libncurses6` |
| GrovePi's `Script/install.sh` force-installs a bundled, ancient `avrdude` (armhf) that breaks `dpkg` on arm64 | A working `avrdude` is installed via apt afterwards, and `dpkg`/apt state is repaired if the old `.deb` partially unpacked |
| `pkgutil.find_loader` deprecated | Not applicable anymore — the function using it was removed along with the obsolete "clear out the old egg" step |
| A few `setup.cfg`/`setup.py` metadata warnings in GrovePi itself (`description-file`, license classifier, `test_suite`) | Patched in the freshly cloned checkout before building |

## Known limitations

- **`grove_co2_sensor/grove_co2_lib.py`** (in the upstream GrovePi repo) has a pre-existing indentation bug that raises an `IndentationError` under Python 3.13's stricter tokenizer, and a separate bug where the serial connection isn't stored on `self`. This script does **not** patch it — if you use the Grove CO2 sensor, you'll need to fix that file yourself (or ask for a patched version).
- On a **Raspberry Pi 5**, the classic `RPi.GPIO` library (installed via pip here) does not work with the Pi 5's GPIO chip the same way `rpi-lgpio` does. This hasn't been tested on a Pi 5.
- Some pip-install deprecation warnings (`legacy setup.py bdist_wheel`) are expected and harmless — GrovePi and `smbus-cffi` don't ship a `pyproject.toml`, but the build still succeeds.

## License

This script is a derivative of Dexter Industries' `install_grovepi.sh`, part of the [GrovePi](https://github.com/DexterInd/GrovePi) project. Refer to the upstream repository for its license terms. Changes in this fork are shared as-is per the disclaimer above.
