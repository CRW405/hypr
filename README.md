
# Hypr

Custom Hyprland Dotfiles using the new lua config system. Some bits are borrowed from Jakoolit.

## Install / update

The repository is the Hyprland config directory (`~/.config/hypr`). To install
it on a new machine, run
`curl -fsSL https://raw.githubusercontent.com/CRW405/hyprqs/master/install.sh | bash`.
It clones the repository into that directory. To update an existing checkout,
run `~/.config/hypr/install.sh update` from anywhere. The script fast-forwards
only, temporarily stashes tracked local changes, then syncs the supported
dotfiles:

- `zsh/zshrc` (or `.zshrc`) to `~/.zshrc`
- `kitty/` to `~/.config/kitty/`
- `firefox/userChrome.css` to each detected Firefox profile's `chrome/`
- `sddm/{faces,flags,scripts,themes,translations-qt6}/` to
  `/usr/share/sddm/` (may prompt for `sudo`; use `--skip-sddm` to omit)

Before replacing a destination file, it saves a timestamped copy under
`~/.local/state/hyprqs/backups/`. It does not delete destination files that
aren't present in the repository. If an update conflicts with local tracked
changes, Git reports the conflict and keeps the stash for recovery. Existing
non-Git directories and checkouts with a different origin are left untouched.

Firefox profiles are discovered in the standard native, Flatpak, and Snap
locations. Set `FIREFOX_PROFILE_DIR` to install into a profile in a custom
location. Local source files must be committed to the repository to be fetched
by other machines; untracked files only sync on the machine where they exist.

## TODO

- cava wallpaper overlay
- make bar folders opening snap to the right to better communicate an opening
- QS dashboard
- Profile Picture system
- Monochrome mode
- Quick customization: bar, color scheme, etc
- Work through hyprland from scratch setup and choose and configure my own things like notifications, depends, utils, etc
