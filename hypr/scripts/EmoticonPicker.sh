#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="$SCRIPT_DIR/../emoticons.tsv"
ROFI_THEME="$SCRIPT_DIR/../rofi/config-clipboard.rasi"

"$SCRIPT_DIR/GenerateRofiColors.sh"

list_entries() {
  local value label emotion style kind tags

  while IFS=$'\t' read -r value label emotion style kind _ tags; do
    [[ "$kind" == "face" ]] || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$value" "$label" "$emotion" "$style" "$kind" "paste" "$tags"
  done <"$CATALOG"
}

if selected="$(list_entries | rofi -dmenu -i -p "Emoticons" \
  -config "$ROFI_THEME" \
  -matching normal \
  -display-columns "1,2,3,4,6,7" \
  -mesg "Search by emotion, style, or tags. Selected emoticons are pasted into the focused app.")"; then
  IFS=$'\t' read -r result _ _ _ _ _ _ <<<"$selected"
else
  exit 0
fi

[[ -n "${result:-}" ]] || exit 0
printf '%s' "$result" | wl-copy
window_class="$(hyprctl activewindow -j | jq -r '.class // ""')"
paste_modifiers="CTRL"
case "${window_class,,}" in
  alacritty|foot|footclient|gnome-terminal|gnome-terminal-server|kitty|konsole|org.gnome.terminal|org.kde.konsole|org.wezfurlong.wezterm|st|tilix|urxvt|wezterm|xterm)
    paste_modifiers="CTRL_SHIFT"
    ;;
esac
hyprctl dispatch sendshortcut "$paste_modifiers, V, activewindow"
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Emoticon pasted" "$result" -u low 2>/dev/null || true
fi
