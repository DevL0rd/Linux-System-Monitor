#!/bin/bash
set -e
BIN_DIR="$HOME/.local/bin"

echo "Stopping resident collector..."
systemctl --user disable --now linux-system-monitor.service 2>/dev/null || true
rm -f ~/.config/systemd/user/linux-system-monitor.service
systemctl --user daemon-reload 2>/dev/null || true

echo "Removing collector + env flag..."
rm -f "$BIN_DIR/sysmon-collect"
rm -f ~/.config/environment.d/linux-system-monitor.conf
rm -rf "${XDG_RUNTIME_DIR:-/tmp}/Linux-System-Monitor"

echo "Removing widget..."
kpackagetool6 -t Plasma/Applet -r "org.devl0rd.sysmon" >/dev/null 2>&1 \
    && echo "  removed org.devl0rd.sysmon" || true

echo "Done. (Kept ~/.config/Linux-System-Monitor/config.json.)"
