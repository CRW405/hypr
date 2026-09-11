#!/usr/bin/env bash
# Picks a wallpaper from WALLPAPER_DIR (images or video files) or a saved
# stream, via rofi (see ../rofi/config-wallpaper.rasi), and applies it to the
# focused monitor. Images go through awww; video files and streams play via
# mpvpaper, managed by WallpaperVideoCtl.sh. Pasting a URL that doesn't match
# an existing entry saves it as a new stream and plays it immediately.

set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROFI_THEME="$SCRIPT_DIR/../rofi/config-wallpaper.rasi"
VIDEO_CTL="$SCRIPT_DIR/WallpaperVideoCtl.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/wallpaper"
STREAMS_FILE="$STATE_DIR/streams.json"
MONITORS_FILE="$STATE_DIR/monitors.json"

# Keep hypr/rofi/colors.rasi in sync with style/style.json before launching.
"$SCRIPT_DIR/GenerateRofiColors.sh"

if [ ! -d "$WALLPAPER_DIR" ]; then
  notify-send "Wallpaper" "Directory not found: $WALLPAPER_DIR" -u low 2>/dev/null || true
  exit 1
fi

mkdir -p "$STATE_DIR"
[ -f "$STREAMS_FILE" ] || echo "[]" >"$STREAMS_FILE"
[ -f "$MONITORS_FILE" ] || echo "{}" >"$MONITORS_FILE"

output="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"

# Scale the thumbnail size to the focused display (same formula the old
# config used) so the grid looks right on both hi-DPI and low-res monitors.
icon_size=20
if [ -n "$output" ]; then
  read -r mon_height mon_scale < <(hyprctl monitors -j | jq -r --arg mon "$output" '.[] | select(.name == $mon) | "\(.height) \(.scale)"')
  if [ -n "${mon_height:-}" ] && [ -n "${mon_scale:-}" ]; then
    icon_size="$(echo "scale=1; ($mon_height * 3) / ($mon_scale * 150)" | bc)"
    icon_size="$(awk -v s="$icon_size" 'BEGIN { if (s < 15) s = 20; if (s > 25) s = 25; print s }')"
  fi
fi

build_entries() {
  ENTRIES=""
  MUTE_LABEL=""
  declare -gA STREAM_URL_BY_LABEL=()

  local mon_entry
  mon_entry="$(jq --arg o "$output" '.[$o] // empty' "$MONITORS_FILE")"
  if [ -n "$mon_entry" ]; then
    local muted
    muted="$(jq -r '.muted' <<<"$mon_entry")"
    if [ "$muted" = "true" ]; then
      MUTE_LABEL="Unmute wallpaper audio"
      ENTRIES+="${MUTE_LABEL}\0icon\x1faudio-volume-muted\n"
    else
      MUTE_LABEL="Mute wallpaper audio"
      ENTRIES+="${MUTE_LABEL}\0icon\x1faudio-volume-high\n"
    fi
  fi

  local files f
  mapfile -t files < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) | sort)
  for f in "${files[@]}"; do
    ENTRIES+="$(basename "$f")\0icon\x1fthumbnail://${f}\n"
  done

  local video_files
  mapfile -t video_files < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.m4v' \) | sort)
  for f in "${video_files[@]}"; do
    ENTRIES+="$(basename "$f")\0icon\x1fvideo-x-generic\n"
  done

  local label url count title
  declare -A label_count=()
  while IFS=$'\t' read -r url title; do
    [ -n "$url" ] || continue
    label="$title"
    count="${label_count[$label]:-0}"
    if [ "$count" -gt 0 ]; then
      count=$((count + 1))
      label="$title ($count)"
    else
      count=1
    fi
    label_count["$title"]="$count"
    STREAM_URL_BY_LABEL["$label"]="$url"
    ENTRIES+="${label}\0icon\x1fvideo-x-generic\n"
  done < <(jq -r '.[] | [.url, .title] | @tsv' "$STREAMS_FILE")
}

is_video_file() {
  case "${1,,}" in
  *.mp4 | *.mkv | *.webm | *.mov | *.m4v) return 0 ;;
  *) return 1 ;;
  esac
}

is_image_file() {
  case "${1,,}" in
  *.jpg | *.jpeg | *.png | *.webp | *.gif) return 0 ;;
  *) return 1 ;;
  esac
}

save_stream() {
  local url="$1" title="$2"
  jq --arg u "$url" --arg t "$title" \
    '. + [{url: $u, title: $t, added: now | floor}]' \
    "$STREAMS_FILE" >"$STREAMS_FILE.tmp" && mv "$STREAMS_FILE.tmp" "$STREAMS_FILE"
}

remove_stream() {
  local url="$1"
  jq --arg u "$url" '[.[] | select(.url != $u)]' "$STREAMS_FILE" >"$STREAMS_FILE.tmp" && mv "$STREAMS_FILE.tmp" "$STREAMS_FILE"
}

while true; do
  build_entries

  choice="$(printf "%b" "$ENTRIES" | rofi -dmenu -show-icons -p "Wallpaper" \
    -config "$ROFI_THEME" \
    -theme-str "element-icon { size: ${icon_size}%; }" \
    -mesg "Enter: apply/play ||| paste a URL to save+play a stream ||| Ctrl+Delete: remove saved stream" \
    -kb-custom-1 "Control+Delete")" && code=0 || code=$?

  case "$code" in
  1)
    exit 0
    ;;
  10)
    if [ -n "${STREAM_URL_BY_LABEL[$choice]:-}" ]; then
      remove_stream "${STREAM_URL_BY_LABEL[$choice]}"
    else
      notify-send "Wallpaper" "Ctrl+Delete only removes saved streams" -u low 2>/dev/null || true
    fi
    continue
    ;;
  0)
    [ -z "$choice" ] && exit 0

    if [ -n "$MUTE_LABEL" ] && [ "$choice" = "$MUTE_LABEL" ]; then
      "$VIDEO_CTL" mute-toggle "$output"
      continue
    elif is_image_file "$choice" && [ -f "$WALLPAPER_DIR/$choice" ]; then
      "$VIDEO_CTL" clear "$output"
      awww img "$WALLPAPER_DIR/$choice" \
        -o "$output" \
        --transition-type grow \
        --transition-pos center \
        --transition-duration 1
      exit 0
    elif is_video_file "$choice" && [ -f "$WALLPAPER_DIR/$choice" ]; then
      "$VIDEO_CTL" play "$output" video "$WALLPAPER_DIR/$choice" true
      exit 0
    elif [ -n "${STREAM_URL_BY_LABEL[$choice]:-}" ]; then
      "$VIDEO_CTL" play "$output" stream "${STREAM_URL_BY_LABEL[$choice]}" true
      exit 0
    elif [[ "$choice" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
      existing="$(jq -r --arg u "$choice" '.[] | select(.url == $u) | .title' "$STREAMS_FILE")"
      if [ -z "$existing" ]; then
        title="$choice"
        if command -v yt-dlp >/dev/null 2>&1; then
          fetched="$(timeout 8 yt-dlp --no-playlist -e "$choice" 2>/dev/null || true)"
          [ -n "$fetched" ] && title="$fetched"
        fi
        save_stream "$choice" "$title"
      fi
      "$VIDEO_CTL" play "$output" stream "$choice" true
      exit 0
    else
      notify-send "Wallpaper" "Not a recognized wallpaper, video, saved stream, or URL" -u low 2>/dev/null || true
      continue
    fi
    ;;
  esac
done
