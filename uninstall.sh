#!/usr/bin/env bash
set -euo pipefail

unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/voxtype-aura.service"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}"

systemctl --user disable --now voxtype-aura.service 2>/dev/null || true
rm -f "$unit"
rm -f "$config_dir/noctalia/voxtype-aura.toml"
rm -f "$config_dir/noctalia/templates/voxtype-aura.json"
rm -f "$state_dir/voxtype-aura/theme.json"
systemctl --user daemon-reload

if command -v voxtype >/dev/null 2>&1; then
  voxtype config set osd.enabled true >/dev/null || true
  if systemctl --user is-active --quiet voxtype.service; then
    systemctl --user restart voxtype.service
  fi
fi

echo "removed voxtype-aura; voxtype's built-in OSD is enabled again"
