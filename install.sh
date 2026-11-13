#!/usr/bin/env bash
set -Eeuo pipefail

readonly default_repo="https://github.com/CRW405/hyprqs.git"
action="install"
action_set=0
repo_url="${HYPRQS_REPO:-$default_repo}"
config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}"
target="${HYPRQS_DIR:-"$config_home/hypr"}"
backup_base="${HYPRQS_BACKUP_DIR:-"${XDG_STATE_HOME:-"$HOME/.local/state"}/hyprqs/backups"}"
sddm_data_dir="${SDDM_DATA_DIR:-/usr/share/sddm}"
skip_sddm=0

die() {
    printf 'install.sh: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s [install|update] [--skip-sddm]\n' "${0##*/}" >&2
    exit 2
}

normalize_url() {
    local url="$1"
    case "$url" in
        git@github.com:*) url="https://github.com/${url#git@github.com:}" ;;
        ssh://git@github.com/*) url="https://github.com/${url#ssh://git@github.com/}" ;;
    esac
    url="${url%.git}"
    printf '%s' "${url%/}"
}

backup_stamp="$(date +%Y%m%d-%H%M%S)-$$"
backup_dir="$backup_base/$backup_stamp"
updated_count=0
backup_count=0

needs_update() {
    local source="$1"
    local destination="$2"
    local source_mode destination_mode

    [[ -f "$source" ]] || die "source file is missing: $source"
    if [[ -f "$destination" && ! -L "$destination" ]] &&
        cmp -s -- "$source" "$destination"; then
        source_mode="$(stat -c '%a' -- "$source")"
        destination_mode="$(stat -c '%a' -- "$destination")"
        [[ "$source_mode" != "$destination_mode" ]] && return 0
        return 1
    fi
    return 0
}

backup_existing() {
    local destination="$1"
    local backup_path="$2"

    if [[ -e "$destination" || -L "$destination" ]]; then
        [[ ! -d "$destination" ]] || die "expected a file but found a directory: $destination"
        mkdir -p "$backup_dir/$(dirname "$backup_path")"
        cp -a -- "$destination" "$backup_dir/$backup_path"
        backup_count=$((backup_count + 1))
    fi
}

install_user_file() {
    local source="$1"
    local destination="$2"
    local backup_path="$3"
    local mode temporary

    needs_update "$source" "$destination" || return 0
    backup_existing "$destination" "$backup_path"
    mode="$(stat -c '%a' -- "$source")"
    temporary="${destination}.hyprqs-tmp-$$"
    [[ ! -e "$temporary" && ! -L "$temporary" ]] || die "temporary file already exists: $temporary"
    install -D -m "$mode" -- "$source" "$temporary"
    mv -fT -- "$temporary" "$destination"
    updated_count=$((updated_count + 1))
}

install_sddm_file() {
    local source="$1"
    local destination="$2"
    local backup_path="$3"
    local mode temporary

    needs_update "$source" "$destination" || return 0
    backup_existing "$destination" "$backup_path"
    mode="$(stat -c '%a' -- "$source")"
    temporary="${destination}.hyprqs-tmp-$$"
    [[ ! -e "$temporary" && ! -L "$temporary" ]] || die "temporary file already exists: $temporary"

    if ((sddm_use_sudo)); then
        sudo install -D -o root -g root -m "$mode" -- "$source" "$temporary"
        if ! sudo mv -fT -- "$temporary" "$destination"; then
            sudo rm -f -- "$temporary"
            die "could not replace $destination"
        fi
    else
        install -D -m "$mode" -- "$source" "$temporary"
        mv -fT -- "$temporary" "$destination"
    fi
    updated_count=$((updated_count + 1))
}

find_firefox_profiles() {
    local root prefs profile
    local -A seen=()
    firefox_profiles=()

    if [[ -n "${FIREFOX_PROFILE_DIR:-}" ]]; then
        [[ -d "$FIREFOX_PROFILE_DIR" ]] || die "Firefox profile directory does not exist: $FIREFOX_PROFILE_DIR"
        firefox_profiles+=("$FIREFOX_PROFILE_DIR")
        return
    fi

    for root in \
        "$HOME/.mozilla/firefox" \
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" \
        "$HOME/snap/firefox/common/.mozilla/firefox"; do
        [[ -d "$root" ]] || continue
        while IFS= read -r -d '' prefs; do
            profile="${prefs%/prefs.js}"
            if [[ -z "${seen[$profile]+yes}" ]]; then
                firefox_profiles+=("$profile")
                seen["$profile"]=1
            fi
        done < <(find "$root" -mindepth 2 -maxdepth 3 -type f -name prefs.js -print0)
    done
}

prepare_sddm() {
    local component source_dir source relative sddm_changes writable_dir
    sddm_sources=()
    ((skip_sddm)) && return

    for component in faces flags scripts themes translations-qt6; do
        source_dir="$repo_dir/sddm/$component"
        [[ -d "$source_dir" ]] || continue
        while IFS= read -r -d '' source; do
            sddm_sources+=("$source")
        done < <(find "$source_dir" -type f -not -path '*/.git/*' -print0)
    done

    sddm_changes=0
    for source in "${sddm_sources[@]}"; do
        relative="${source#"$repo_dir/sddm/"}"
        if needs_update "$source" "$sddm_data_dir/$relative"; then
            sddm_changes=1
            break
        fi
    done

    if ((sddm_changes)); then
        writable_dir="$sddm_data_dir"
        while [[ ! -d "$writable_dir" ]]; do
            writable_dir="${writable_dir%/*}"
            [[ -n "$writable_dir" ]] || writable_dir="/"
        done
        if [[ ! -w "$writable_dir" ]]; then
            command -v sudo >/dev/null 2>&1 || die "sudo is required to update SDDM files."
            sudo -v || die "could not authenticate for the SDDM update."
            sddm_use_sudo=1
        fi
    fi
}

for argument in "$@"; do
    case "$argument" in
        install|update)
            ((action_set == 0)) || usage
            action="$argument"
            action_set=1
            ;;
        --skip-sddm) skip_sddm=1 ;;
        *) usage ;;
    esac
done

[[ "$sddm_data_dir" == /* ]] || die "SDDM_DATA_DIR must be an absolute path."
command -v git >/dev/null 2>&1 || die "git is required."

if [[ -e "$target" || -L "$target" ]]; then
    [[ -d "$target" ]] || die "target exists but is not a directory: $target"
    repo_root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" \
        || die "target is not a Git checkout; leaving it untouched: $target"
    target_real="$(cd "$target" && pwd -P)"
    repo_root_real="$(cd "$repo_root" && pwd -P)"
    [[ "$target_real" == "$repo_root_real" ]] \
        || die "target is inside another Git checkout; leaving it untouched: $target"

    origin="$(git -C "$target" remote get-url origin 2>/dev/null)" \
        || die "checkout has no origin remote; leaving it untouched."
    [[ "$(normalize_url "$origin")" == "$(normalize_url "$repo_url")" ]] \
        || die "origin does not match $repo_url; leaving the checkout untouched."

    printf 'Updating %s from %s...\n' "$target" "$origin"
    git -C "$target" pull --ff-only --autostash
    printf 'Update complete. Local tracked changes were preserved where possible.\n'
else
    [[ "$action" != update ]] || die "no checkout found at $target."
    parent="${target%/*}"
    [[ "$parent" != "$target" ]] || parent="."
    mkdir -p "$parent"
    printf 'Installing %s into %s...\n' "$repo_url" "$target"
    git clone -- "$repo_url" "$target"
    printf 'Install complete.\n'
fi

repo_dir="$target"
declare -a sddm_sources=()
declare -i sddm_use_sudo=0
prepare_sddm

zsh_source=""
if [[ -f "$repo_dir/zsh/zshrc" ]]; then
    zsh_source="$repo_dir/zsh/zshrc"
elif [[ -f "$repo_dir/.zshrc" ]]; then
    zsh_source="$repo_dir/.zshrc"
fi
if [[ -n "$zsh_source" ]]; then
    install_user_file "$zsh_source" "$HOME/.zshrc" "home/.zshrc"
else
    printf 'Skipping zsh: no zsh/zshrc or .zshrc source found.\n' >&2
fi

if [[ -d "$repo_dir/kitty" ]]; then
    while IFS= read -r -d '' source; do
        relative="${source#"$repo_dir/kitty/"}"
        install_user_file "$source" "$config_home/kitty/$relative" "home/.config/kitty/$relative"
    done < <(find "$repo_dir/kitty" -type f -not -path '*/.git/*' -print0)
fi

if [[ -f "$repo_dir/firefox/userChrome.css" ]]; then
    find_firefox_profiles
    if ((${#firefox_profiles[@]} == 0)); then
        printf 'Skipping Firefox userChrome.css: no Firefox profiles found. Set FIREFOX_PROFILE_DIR to select one.\n' >&2
    else
        for index in "${!firefox_profiles[@]}"; do
            profile="${firefox_profiles[$index]}"
            install_user_file \
                "$repo_dir/firefox/userChrome.css" \
                "$profile/chrome/userChrome.css" \
                "firefox/profile-$index/chrome/userChrome.css"
        done
    fi
fi

if (( ! skip_sddm )); then
    for source in "${sddm_sources[@]}"; do
        relative="${source#"$repo_dir/sddm/"}"
        install_sddm_file \
            "$source" \
            "$sddm_data_dir/$relative" \
            "sddm/$relative"
    done
elif [[ -d "$repo_dir/sddm" ]]; then
    printf 'Skipping SDDM files (--skip-sddm).\n'
fi

if ((updated_count > 0)); then
    printf 'Updated %d file(s).' "$updated_count"
    if ((backup_count > 0)); then
        printf ' Backed up %d replaced file(s) to %s.' "$backup_count" "$backup_dir"
    fi
    printf '\n'
else
    printf 'No supported files needed updating.\n'
fi
