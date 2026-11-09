#!/usr/bin/env bash
set -euo pipefail

unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/voxtype-aura.service"

systemctl --user disable --now voxtype-aura.service 2>/dev/null || true
rm -f "$unit"
systemctl --user daemon-reload

if command -v voxtype >/dev/null 2>&1; then
  voxtype config set osd.enabled true >/dev/null || true
  if systemctl --user is-active --quiet voxtype.service; then
    systemctl --user restart voxtype.service
  fi
fi

echo "removed voxtype-aura; voxtype's built-in OSD is enabled again"
