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
skip_packages=0

die() {
    printf 'install.sh: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s [install|update] [--skip-sddm] [--skip-packages]\n' "${0##*/}" >&2
    exit 2
}

install_packages() {
    local answer
    local -a packages=(
        # Hyprland session and this config's workflow
        hyprland hypridle hyprlock hyprpicker hyprpolkitagent hyprsunset
        quickshell rofi kitty thunar firefox neovim zsh fzf nvm lsd nnn
        awww mpvpaper wlogout grim slurp wl-clipboard cliphist imagemagick cava
        jq libnotify xdg-utils xdg-user-dirs xorg-xwayland
        xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        # Network, Bluetooth, audio, and power controls
        networkmanager network-manager-applet bluez bluez-utils blueman
        pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol playerctl
        brightnessctl power-profiles-daemon opentabletdriver
        # Everyday system utilities and applications
        base-devel git curl wget rsync bash-completion less man-db man-pages
        unzip 7zip ripgrep tree btop fastfetch pokemon-colorscripts-git
        gvfs tumbler thunar-archive-plugin xarchiver
        mpv ffmpeg yt-dlp loupe libreoffice-fresh qalculate-gtk
        spotify-launcher discord obs-studio qbittorrent gimp prismlauncher
        # Fonts and appearance tools
        noto-fonts noto-fonts-emoji otf-font-awesome ttf-jetbrains-mono-nerd
        nwg-look qt6ct sddm
    )

    if ! command -v pacman >/dev/null 2>&1; then
        printf 'Skipping package installation: pacman is not available.\n'
        return
    fi
    if [[ ! -r /dev/tty ]]; then
        printf 'Skipping package installation: no interactive terminal is available.\n'
        return
    fi
    if pacman -Si steam >/dev/null 2>&1; then
        packages+=(steam)
    else
        printf 'Skipping Steam: it is unavailable in enabled pacman repositories (Steam requires multilib).\n'
    fi
    if ((EUID != 0)) && ! command -v sudo >/dev/null 2>&1; then
        die "sudo is required to install packages."
    fi

    printf 'The following packages will be installed if not already present:\n'
    printf '  %s\n' "${packages[@]}"
    if ! read -r -p 'Install these packages? [Y/n] ' answer </dev/tty; then
        printf 'Skipping package installation: could not read confirmation.\n'
        return
    fi
    case "$answer" in
        ""|[Yy]|[Yy][Ee][Ss]) ;;
        *) printf 'Skipping package installation.\n'; return ;;
    esac

    if ((EUID == 0)); then
        pacman -S --needed "${packages[@]}" </dev/tty
    else
        # Pacman prompts must use the terminal when this script is piped to bash.
        # shellcheck disable=SC2024
        sudo pacman -S --needed "${packages[@]}" </dev/tty
    fi
}

setup_oh_my_zsh() {
    local oh_my_zsh_dir="$HOME/.oh-my-zsh"
    local custom_plugins plugin_dir plugin_entry zsh_path account current_shell answer plugin
    local -a plugins=(zsh-autosuggestions zsh-syntax-highlighting)

    if ! command -v zsh >/dev/null 2>&1; then
        printf 'Skipping Oh My Zsh setup: zsh is not installed.\n'
        return
    fi

    if [[ -e "$oh_my_zsh_dir" || -L "$oh_my_zsh_dir" ]]; then
        [[ -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]] \
            || die "existing Oh My Zsh path is not a valid installation: $oh_my_zsh_dir"
    else
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$oh_my_zsh_dir"
    fi

    custom_plugins="$oh_my_zsh_dir/custom/plugins"
    mkdir -p "$custom_plugins"
    for plugin in "${plugins[@]}"; do
        plugin_dir="$custom_plugins/$plugin"
        plugin_entry="$plugin.zsh"
        if [[ -e "$plugin_dir" || -L "$plugin_dir" ]]; then
            [[ -f "$plugin_dir/$plugin_entry" ]] || die "plugin installation is incomplete: $plugin_dir"
            continue
        fi
        git clone --depth=1 "https://github.com/zsh-users/$plugin.git" "$plugin_dir"
    done

    zsh_path="$(command -v zsh)"
    if [[ ! -r /etc/shells ]] || ! grep -Fxq "$zsh_path" /etc/shells; then
        printf 'Oh My Zsh is ready, but %s is not listed in /etc/shells; not changing the default shell.\n' "$zsh_path"
        return
    fi
    account="$(id -un)"
    current_shell="$(getent passwd "$account" | cut -d: -f7)" \
        || die "could not determine the current login shell."
    [[ -n "$current_shell" ]] || die "could not determine the current login shell."
    if [[ "$current_shell" == "$zsh_path" ]]; then
        printf 'The default shell is already %s.\n' "$zsh_path"
        return
    fi
    if ! command -v chsh >/dev/null 2>&1; then
        printf 'Oh My Zsh is ready, but chsh is unavailable; not changing the default shell.\n'
        return
    fi
    if ! read -r -p "Set the default shell to $zsh_path? [Y/n] " answer </dev/tty; then
        printf 'Could not read confirmation; not changing the default shell.\n'
        return
    fi
    case "$answer" in
        ""|[Yy]|[Yy][Ee][Ss]) chsh -s "$zsh_path" "$account" </dev/tty ;;
        *) printf 'Keeping the current default shell.\n' ;;
    esac
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
        --skip-packages) skip_packages=1 ;;
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

if [[ "$action" == install ]] && (( ! skip_packages )); then
    install_packages
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
    if [[ "$action" == install ]]; then
        setup_oh_my_zsh
    fi
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
