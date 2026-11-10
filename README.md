# Voxtype Aura — niri + noctalia fork

A compact recording overlay for [voxtype](https://voxtype.io): one pill, a
waveform, and a symmetric countdown bar. No icons, no labels.

This is a fork of [adamcbrewer/voxtype-aura](https://github.com/adamcbrewer/voxtype-aura)
adapted for **niri + noctalia**. It drops the Omarchy plugin system, the
`qs.Commons` helpers, and the Hyprland focus API, so it runs as a plain
Quickshell config.

- recording: palette `error`
- transcribing: palette `tertiary`
- done: palette `secondary`
- waveform: gradient `primary` → `tertiary`

## Requirements

- niri (uses `niri msg --json focused-output`)
- `quickshell` (provides `qs`) — tested with 0.2.1
- `voxtype` with `voxtype-audio-bridge` — tested with 1.1.1
- `setpriv` (util-linux)
- systemd user session

## Install

```sh
git clone https://github.com/Luke1453/voxtype-aura.git
cd voxtype-aura
./install.sh
```

The script writes `~/.config/systemd/user/voxtype-aura.service`, disables
voxtype's built-in OSD (`[osd] enabled = false`), and starts both services.
The unit is generated with the current path, so keep the clone where it is or
re-run `./install.sh` after moving it.

## How it works

```text
voxtype daemon ──status --follow──> Aura (qs) ──layer-shell──> niri
               ──audio.sock──> voxtype-audio-bridge ──NDJSON──> Aura
```

State colors follow `stateColor` in `Service.qml`. The overlay queries
`niri msg --json focused-output` at startup and whenever voxtype reports a
state change, then shows on that output. The layer uses an empty input region,
so clicks pass through.

## Theming

All colors follow the active noctalia palette. `install.sh` writes two files:

- `~/.config/noctalia/voxtype-aura.toml` — user template registration
- `~/.config/noctalia/templates/voxtype-aura.json` — renders the palette to
  `~/.local/state/voxtype-aura/theme.json`

Role mapping:

| Aura value | Noctalia token |
|---|---|
| `background` | `colors.surface` |
| `recordingColor` | `colors.primary` |
| `transcribingColor` | `colors.primary` |
| `successColor` | `colors.secondary` |
| `waveStart` | `colors.primary` |
| `waveEnd` | `colors.tertiary` |

Noctalia re-renders that file on palette changes; Aura watches it with
`FileView.watchChanges` and updates live, including the waveform gradient.
If the file is missing, the fallback values in `Service.qml` are used. Force a
render with:

```sh
noctalia msg templates-apply
```

The green "done" state is shown for 300 ms, then the overlay hides.

## Tuning

All visual settings are at the top of `Service.qml`. The color properties are
fallbacks, replaced at runtime by the noctalia palette:

| Property | Fallback |
|---|---|
| `recordingColor` | `#BB3535` |
| `transcribingColor` | `#9A7398` |
| `successColor` | `#8BAA82` |
| `waveStart` | `#BB3535` |
| `waveEnd` | `#9A7398` |
| `background` | `#0A0A12` |
| `cornerRadius` | `9` |
| `gapsOut` | `8` |

Geometry is in the `PanelWindow` block: `implicitWidth: 150`,
`implicitHeight: 50`, and the card is `137x33`. Waveform bar count, width and
spacing are in the `Repeater`; max bar height is in `barHeight()`.

Apply changes with:

```sh
systemctl --user restart voxtype-aura
```

## Uninstall

```sh
./uninstall.sh
```

This removes the unit and re-enables voxtype's built-in OSD.

## Credits

Original project by Adam Brewer, MIT licensed. See `LICENSE` and
`THIRD_PARTY_NOTICES.md`.
