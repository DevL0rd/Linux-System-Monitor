# Linux-System-Monitor

A native KDE Plasma 6 widget: a clean local-system dashboard — total + per-core
**CPU** (split into **P-cores / E-cores** on Intel hybrid, each with a group
total), frequency, package **power** (Intel RAPL) and **temperature**, **RAM** +
swap, and the **NVIDIA GPU** (usage, VRAM, temp, power, clocks, fan). Styled to
match the rest of the suite (Router-Monitor, Log-Monitor, App Portal,
Process-Mon).

The cards stack in a single vertical column.

## How it works

A resident helper (`bin/sysmon-collect`) does all the work, like the other
collectors: a systemd `--user` service samples `/proc`, `/sys` and `nvidia-smi`
once per interval and writes a JSON snapshot to
`$XDG_RUNTIME_DIR/Linux-System-Monitor/data.json`. It's **pinned to the E-cores**
(`bin/sysmon-ecores`) with `Nice=19`, and the widget reads the snapshot
in-process via `file://` XHR (needs `QML_XHR_ALLOW_FILE_READ=1`, set by
`install.sh` via `environment.d`).

## Install

Clone **with submodules** — the shared QML/JS components live in the
[Linux-Plasma-Shared](https://github.com/DevL0rd/Linux-Plasma-Shared) submodule:

```sh
git clone --recurse-submodules https://github.com/DevL0rd/Linux-System-Monitor.git
cd Linux-System-Monitor
# already cloned without it?  git submodule update --init --recursive
./install.sh
```

Add **System Monitor** from *Add Widgets*. Uninstall with `./uninstall.sh`.

Settings (right-click → Configure): panel icon, refresh interval, accent colour,
history graphs, per-core bars, GPU section. Collector sampling rate is
`poll_interval` in `~/.config/Linux-System-Monitor/config.json`.
