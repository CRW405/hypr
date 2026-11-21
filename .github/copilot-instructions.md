# Repository guidance

## Repository shape

This is a personal, Arch Linux-oriented Hyprland dotfiles repository. The checkout itself is the active Hyprland config directory (`~/.config/hypr`) rather than a packaged application. It combines Lua-based Hyprland configuration, Bash scripts, Quickshell QML, Rofi/Kitty/Firefox/SDDM configuration, and Zsh setup.

The README is the source of truth for installation and update behavior.

## Build, validation, and live reload

There is no package manifest, automated test suite, formatter, or CI build.

- Install on a new machine: `./install.sh install`
- Install without the pacman package prompt: `./install.sh install --skip-packages`
- Update this checkout and supported user/system dotfiles: `./install.sh update`
- Update without touching SDDM: `./install.sh update --skip-sddm`
- Reload the active Hyprland configuration: `hyprctl reload`
- Reload or start the bar: `qs -p qs/basicBar.qml`
- Reload or start the overview: `qs -p qs/overview`

Use focused syntax and smoke checks before reloading:

- Bash syntax for one script: `bash -n hypr/scripts/WallpaperPicker.sh`
- Shell lint for one script: `shellcheck hypr/scripts/WallpaperPicker.sh`
- Shell lint all repository scripts: `find . -type f -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck`
- Lua syntax for a changed Lua file: `luac -p hyprland.lua` (also use `monitors.lua`, `workspaces.lua`, or `style/style.lua` as appropriate)
- Quickshell entry-point smoke test: `timeout 5 qs -p qs/basicBar.qml` or `timeout 5 qs -p qs/overview`
- Notification UI test: `./hypr/scripts/TestNotifications.sh`

A zero exit while using `timeout` means the QML process remained running until the timeout; treat that as a process-start success.

## Architecture

- `hyprland.lua` is the central Hyprland Lua entry point. It loads the generated monitor/workspace modules, central style, keybinds, autostart commands, window rules, and core settings.
- `monitors.lua` and `workspaces.lua` are machine-generated nwg-displays output and are ignored by Git. Do not hand-edit them unless the task is explicitly about generated display/workspace setup.
- `hypr/scripts/` contains shell integrations launched by keybinds or autostart. Scripts use Hyprland IPC (`hyprctl`) and tools such as `jq`, `rofi`, `notify-send`, `wl-paste`, and `playerctl`.
- `qs/basicBar.qml` is the standalone Quickshell bar entry point. `qs/overview/` is a separate standalone Quickshell project with `shell.qml`, services, modules, common components, and its own palette copy.
- `qs/pollers/`, `qs/components/`, and `qs/theme/` implement reusable bar state, widgets, labels, and bar-specific theming.
- `qs/overview/services/HyprlandData.qml` refreshes live window, monitor, workspace, layer, and active-workspace state from `hyprctl -j` and Hyprland raw events.
- `style/style.json` is the shared source for desktop colors and spacing. `style/style.lua` loads it for Hyprland Lua, `qs/theme/Palette.qml` loads it live for QML, and `GenerateRofiColors.sh` derives `hypr/rofi/colors.rasi`.
- `install.sh` protects existing checkouts and destination files: installs/updates only the supported dotfiles, stashes tracked changes during updates, and creates timestamped backups before replacing files. SDDM updates may require `sudo`.

## Conventions

- Preserve the shared style system. Change `style/style.json` for theme-wide values, then run `hypr/scripts/GenerateRofiColors.sh` so Rofi's generated `colors.rasi` stays synchronized. `style/style.json` accepts JSONC comments; the Lua and QML loaders handle them, while `jq`-based scripts require `strip_jsonc.py`.
- Keep generated Rofi colors and per-machine monitor/workspace Lua files aligned with their generators: do not substitute unrelated files or globally replace one with the other.
- Quickshell entry points are started by path with `qs -p`, not by named config lookup. Follow that pattern for scripts and reload instructions.
- When invoking shell commands from Lua, use `shellQuote`/`execWithFailureNotification` patterns from `hyprland.lua` rather than introducing unescaped command strings.
- New reusable QML should follow the existing split: shared bar widgets under `qs/components/`, polling under `qs/pollers/`, theme values under `qs/theme/`, and overview-only state/modules under `qs/overview/`.
- Scripts should be Bash with `set -euo pipefail`, resolve repository paths relative to `BASH_SOURCE[0]`, and use existing notification/error helpers when failures need user feedback.
- Hyprland Lua uses `hl.*` APIs for configuration, bindings, events, window rules, workspace rules, and dispatch; use the Lua table style already used in `hyprland.lua`, not legacy Hyprland `.conf` syntax.
