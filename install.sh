#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
unit="$unit_dir/voxtype-aura.service"

for cmd in qs voxtype voxtype-audio-bridge setpriv niri; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing dependency: $cmd" >&2
    exit 1
  fi
done

mkdir -p "$unit_dir"
cat >"$unit" <<EOF
[Unit]
Description=Voxtype Aura dictation overlay
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart="$(command -v qs)" -p "$repo_dir"
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF

# Aura draws its own overlay; two surfaces would show at once.
voxtype config set osd.enabled false >/dev/null

systemctl --user daemon-reload
systemctl --user enable --now voxtype-aura.service
systemctl --user restart voxtype-aura.service

if systemctl --user is-active --quiet voxtype.service; then
  systemctl --user restart voxtype.service
fi

echo "installed $unit"
echo "tune colors and size in $repo_dir/Service.qml, then: systemctl --user restart voxtype-aura"
