#!/usr/bin/env bash
set -euo pipefail

if ! command -v notify-send >/dev/null 2>&1; then
    printf 'notify-send is required (usually provided by libnotify).\n' >&2
    exit 1
fi

app_name="HyprQS Notification Test"

printf 'Sending urgency, scrolling, expansion, metadata, image, and replacement tests.\n'
printf 'Hover the notification indicator to inspect the menu; click rows to expand/collapse.\n'
printf 'Use Clear all to verify that the notification list can be emptied.\n'

notify-send --app-name="$app_name" --urgency=low \
    'Low urgency' 'Check that this row has no colored urgency stripe.'
notify-send --app-name="$app_name" --urgency=normal \
    'Normal urgency' 'Check the normal-urgency stripe.'
notify-send --app-name="$app_name" --urgency=critical \
    'Critical urgency' 'Check the red critical-urgency stripe.'

for i in {1..12}; do
    notify-send --app-name="$app_name" --urgency=normal --expire-time=120000 \
        "Scroll test $i" 'Use the notification menu scrollbar to find the other rows.'
done

image_path=""
for icon_dir in /usr/share/icons /usr/share/pixmaps; do
    [[ -d "$icon_dir" ]] || continue
    image_path=$(find "$icon_dir" -type f \
        \( -iname '*.png' -o -iname '*.svg' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
        -print -quit 2>/dev/null || true)
    [[ -n "$image_path" ]] && break
done

image_hint=()
if [[ -n "$image_path" ]]; then
    image_hint=(--hint "string:image-path:$image_path")
else
    printf 'No system image found; skipping the notification image hint.\n'
fi

notify-send --app-name="$app_name" --app-icon=utilities-terminal \
    --icon=dialog-information --urgency=normal --expire-time=120000 \
    --category=im.received "${image_hint[@]}" \
    'Expand, wrap, link, and image test' \
    'This deliberately long body checks word wrapping after expansion. Click <a href="https://example.com">Example.com</a> to test links.'

notify-send --app-name="$app_name" --transient --expire-time=120000 \
    'Transient metadata' 'Expand this notification to see its metadata.'

notify-send --app-name="$app_name" --hint=boolean:resident:true \
    --action=dialog-information=Open --action=window-close=Dismiss \
    --expire-time=30000 --wait \
    'Actions and resident test' 'Choose an action; this resident notification should remain.'

replace_id=$(notify-send --app-name="$app_name" --print-id --expire-time=120000 \
    'Replacement test' 'This notification will be replaced in one second.')
if [[ ! "$replace_id" =~ ^[0-9]+$ ]]; then
    printf 'notify-send did not return a valid notification ID: %s\n' "$replace_id" >&2
    exit 1
fi
sleep 1
notify-send --app-name="$app_name" --replace-id="$replace_id" \
    'Replacement test' 'This should replace the previous notification.'

printf 'Done. notify-send has no inline-reply option; use an app that sends inline-reply notifications to test replies.\n'
