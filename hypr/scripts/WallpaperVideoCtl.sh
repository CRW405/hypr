#!/usr/bin/env bash
# Manages mpvpaper processes for video/stream wallpapers, one per output, and
# persists per-output state so WallpaperInit.sh can restore them on login.
# Usage:
#   WallpaperVideoCtl.sh play <output> <mode: video|stream> <source> <muted: true|false>
#   WallpaperVideoCtl.sh mute-toggle <output>
#   WallpaperVideoCtl.sh clear <output>
#   WallpaperVideoCtl.sh kill <output>
#   WallpaperVideoCtl.sh restore-all

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/wallpaper"
MONITORS_FILE="$STATE_DIR/monitors.json"

ensure_state() {
  mkdir -p "$STATE_DIR"
  [ -f "$MONITORS_FILE" ] || echo "{}" >"$MONITORS_FILE"
}

# Prints the PIDs of any mpvpaper process whose argv contains $1 as an exact
# element (not a substring match - monitor names like DP-1/DP-11 collide
# under pkill -f).
find_mpvpaper_pids() {
  local target="$1" cmdline_file pid argv a
  for cmdline_file in /proc/[0-9]*/cmdline; do
    [ -r "$cmdline_file" ] || continue
    pid="$(basename "$(dirname "$cmdline_file")")"
    argv=()
    mapfile -d '' -t argv <"$cmdline_file" 2>/dev/null || continue
    [ "${#argv[@]}" -gt 0 ] || continue
    [ "$(basename "${argv[0]}")" = "mpvpaper" ] || continue
    for a in "${argv[@]:1}"; do
      if [ "$a" = "$target" ]; then
        echo "$pid"
        break
      fi
    done
  done
}

kill_output() {
  local output="$1" pids pid
  pids="$(find_mpvpaper_pids "$output")"
  [ -n "$pids" ] || return 0

  while IFS= read -r pid; do
    kill "$pid" 2>/dev/null || true
  done <<<"$pids"

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -n "$(find_mpvpaper_pids "$output")" ] || return 0
    sleep 0.1
  done

  while IFS= read -r pid; do
    kill -9 "$pid" 2>/dev/null || true
  done <<<"$(find_mpvpaper_pids "$output")"
}

set_monitor_entry() {
  local output="$1" mode="$2" source="$3" muted="$4"
  jq --arg o "$output" --arg mode "$mode" --arg source "$source" --argjson muted "$muted" \
    '.[$o] = {mode: $mode, source: $source, muted: $muted}' \
    "$MONITORS_FILE" >"$MONITORS_FILE.tmp" && mv "$MONITORS_FILE.tmp" "$MONITORS_FILE"
}

clear_monitor_entry() {
  local output="$1"
  jq --arg o "$output" 'del(.[$o])' "$MONITORS_FILE" >"$MONITORS_FILE.tmp" && mv "$MONITORS_FILE.tmp" "$MONITORS_FILE"
}

connected_outputs() {
  hyprctl monitors -j | jq -r '.[].name'
}

cmd_play() {
  local output="$1" mode="$2" source="$3" muted="$4"

  if ! command -v mpvpaper >/dev/null 2>&1; then
    notify-send "Wallpaper" "mpvpaper is not installed" -u low 2>/dev/null || true
    exit 1
  fi

  kill_output "$output"

  # blank the output to black first, so any area the video doesn't cover
  # (aspect-ratio mismatch, or mpv taking a moment to come up) shows black
  # instead of the previous static wallpaper bleeding through
  awww img 0x000000 -o "$output" >/dev/null 2>&1 || true

  local mute_opt="no"
  [ "$muted" = "true" ] && mute_opt="yes"

  setsid mpvpaper -o "mute=$mute_opt loop background-color=#FF000000" -l background "$output" "$source" >/dev/null 2>&1 &
  disown

  sleep 1.5

  if [ -n "$(find_mpvpaper_pids "$output")" ]; then
    set_monitor_entry "$output" "$mode" "$source" "$muted"
  else
    notify-send "Wallpaper" "Could not play: $source" -u low 2>/dev/null || true
  fi
}

cmd_mute_toggle() {
  local output="$1" entry mode source muted new_muted

  entry="$(jq --arg o "$output" '.[$o] // empty' "$MONITORS_FILE")"
  if [ -z "$entry" ]; then
    notify-send "Wallpaper" "No video/stream playing on $output" -u low 2>/dev/null || true
    return 0
  fi

  mode="$(jq -r '.mode' <<<"$entry")"
  source="$(jq -r '.source' <<<"$entry")"
  muted="$(jq -r '.muted' <<<"$entry")"
  new_muted="true"
  [ "$muted" = "true" ] && new_muted="false"

  cmd_play "$output" "$mode" "$source" "$new_muted"
}

cmd_clear() {
  local output="$1"
  kill_output "$output"
  clear_monitor_entry "$output"
}

cmd_restore_all() {
  local connected outputs_json output mode source muted
  connected="$(connected_outputs)"

  outputs_json="$(jq -n --argjson current "$(cat "$MONITORS_FILE")" \
    --arg connected "$connected" \
    '$connected | split("\n") | map(select(length > 0)) as $live
     | $current | to_entries | map(select(.key as $k | $live | index($k))) | from_entries')"
  echo "$outputs_json" >"$MONITORS_FILE.tmp" && mv "$MONITORS_FILE.tmp" "$MONITORS_FILE"

  while IFS=$'\t' read -r output mode source muted; do
    [ -n "$output" ] || continue
    cmd_play "$output" "$mode" "$source" "$muted"
  done < <(jq -r 'to_entries[] | [.key, .value.mode, .value.source, .value.muted] | @tsv' "$MONITORS_FILE")
}

ensure_state

case "${1:-}" in
play)
  cmd_play "$2" "$3" "$4" "$5"
  ;;
mute-toggle)
  cmd_mute_toggle "$2"
  ;;
clear)
  cmd_clear "$2"
  ;;
kill)
  kill_output "$2"
  ;;
restore-all)
  cmd_restore_all
  ;;
*)
  echo "usage: $0 [play <output> <video|stream> <source> <muted>|mute-toggle <output>|clear <output>|kill <output>|restore-all]" >&2
  exit 2
  ;;
esac
