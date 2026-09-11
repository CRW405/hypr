#!/usr/bin/env bash
# Starts the awww wallpaper daemon, relaunches any video/stream wallpapers
# recorded per output, then restores images on the remaining outputs -
# falling back to the first image in WALLPAPER_DIR on a completely fresh
# setup with nothing to restore.

set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIDEO_CTL="$SCRIPT_DIR/WallpaperVideoCtl.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/wallpaper"
MONITORS_FILE="$STATE_DIR/monitors.json"

# probe this session's awww socket directly - pgrep would also match a daemon
# started by a different Hyprland session on another tty
if ! awww query >/dev/null 2>&1; then
  awww-daemon >/dev/null 2>&1 &
  disown
  sleep 0.5
fi

"$VIDEO_CTL" restore-all

video_outputs="$(jq -r 'keys[]' "$MONITORS_FILE")"
image_outputs="$(hyprctl monitors -j | jq -r '.[].name' | grep -vxF -f <(echo "$video_outputs") || true)"
image_outputs_csv="$(echo "$image_outputs" | paste -sd, -)"

[ -n "$image_outputs_csv" ] || exit 0

if awww restore -o "$image_outputs_csv" 2>/dev/null; then
  exit 0
fi

first="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) | sort | head -n1)"

if [ -n "$first" ]; then
  awww img "$first" -o "$image_outputs_csv"
fi
