# Hyprland Setup on CachyOS

## Initial System Setup

### Base System
- **OS**: CachyOS (uses zsh by default)
- **Boot**: Limine bootloader
- **Install**: Minimal installation

### System Updates & Rate Mirrors
```bash
sudo cachyos-rate-mirrors
sudo pacman -Syyu
```

## Core Hyprland Installation

### Essential Packages
```bash
sudo pacman -S hyprland cmake cpio meson uwsm libnewt
sudo pacman -S hyprland-protocols  # Note: check spelling
```

### Session Management (uwsm)
Add to `.zshrc`:
```bash
if uwsm check may-start; then
    exec uwsm start hyprland-uwsm.desktop
fi
```

### Audio & Network
```bash
sudo pacman -S pipewire networkmanager
```

### Wayland Support
```bash
sudo pacman -S xdg-desktop-portal-hyprland
sudo pacman -S qt5-wayland qt6-wayland
```

## Applications & Tools

### Terminal & Shell
```bash
sudo pacman -S kitty
# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Browsers & Productivity
```bash
# Core applications
sudo pacman -S librewolf-bin git github-cli lazygit neovim
paru -S obsidian  # Note: might need AUR helper
```

### Development
- Install LazyVim configuration for Neovim

## Hyprland Components

### Status Bar
```bash
sudo pacman -S waybar
# Enable waybar service
systemctl --user enable --now waybar.service
# OR add to hyprland.conf: exec-once = waybar
```

### Notifications
```bash
sudo pacman -S swaync
```

### Wallpapers & Backgrounds
```bash
sudo pacman -S hyprpaper mpvpaper
```

### Application Launchers
```bash
sudo pacman -S wofi rofi bemenu hyprpicker
# Choose one: wofi, rofi, or bemenu
```

### Clipboard Management
```bash
sudo pacman -S cliphist
```

Add to `hyprland.conf`:
```bash
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
```

Keybinding options:
```bash
# With rofi
bind = SUPER, V, exec, cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy

# With wofi  
bind = SUPER, V, exec, cliphist list | wofi --dmenu --pre-display-cmd "echo '%s' | cut -f 2" | cliphist decode | wl-copy
```

## Security & Authentication

### Polkit Agent
```bash
sudo pacman -S hyprpolkitagent
```

Add to `hyprland.conf`:
```bash
exec-once = systemctl --user start hyprpolkitagent
```

### VPN
```bash
sudo pacman -S tailscale
```

## Theming & Appearance

### Theme Components
```bash
sudo pacman -S nwg-look adwaita-qt papirus-icon-theme capitaine-cursors
paru -S catppuccin-gtk-theme rose-pine-gtk-theme tela-icon-theme bibata-cursor-theme
```

**Recommended themes:**
- GTK: Rose Pine Moon, Catppuccin Mocha
- Icons: Papirus, Tela
- Cursors: Bibata, Capitaine

## Shell Customization

### .zshrc Additions
```bash
# Session management
if uwsm check may-start; then
    exec uwsm start hyprland-uwsm.desktop
fi

# Aliases
alias la="ls -a"
```

## Important Notes

- **File System**: Ensure btrfs-assistant is properly configured
- **Configuration**: Copy and customize `hyprland.conf`
- **File Managers**: See [Hyprland Wiki](https://wiki.hypr.land/Useful-Utilities/File-Managers/) for options

## TODO/Decisions Needed

- [ ] Choose between wofi, rofi, or bemenu for application launcher
- [ ] Set up wallpaper management solution
- [ ] Configure file manager
- [ ] Fine-tune waybar configuration

---

## Unorganized VVVVVV

sudo pacman -S kvantum 

sudo pacman -S bluez bluez-utils bluez-deprecated-tools bluetui blueman 