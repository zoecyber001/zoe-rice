#!/usr/bin/env bash
set -euo pipefail

# ┌─────────────────────────────────────────────────────────────────────┐
# │  zoe-rice installer                                               │
# │  Fedora 44 · GNOME 50 · Pop Shell · Material You                  │
# │                                                                     │
# │  Idempotent: safe to re-run. Backs up existing configs before      │
# │  overwriting. Pass --uninstall to reverse.                          │
# └─────────────────────────────────────────────────────────────────────┘

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/tmp/zoe-rice-install.log"
DRY_RUN=false
SKIP_DNF=false
SKIP_EXTENSIONS=false

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
err()   { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE" >&2; }
info()  { echo -e "${CYAN}[*]${NC} $*" | tee -a "$LOG_FILE"; }
header(){ echo -e "\n${BOLD}${BLUE}── $* ──${NC}" | tee -a "$LOG_FILE"; }

# ── Argument parsing ───────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --dry-run)      DRY_RUN=true ;;
        --skip-dnf)     SKIP_DNF=true ;;
        --skip-extensions) SKIP_EXTENSIONS=true ;;
        --uninstall)    exec bash "$DOTFILES_DIR/uninstall.sh"; exit ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo "  --dry-run          Show what would be done without modifying anything"
            echo "  --skip-dnf         Skip system package installation (useful on non-Fedora)"
            echo "  --skip-extensions  Skip GNOME extension installation"
            echo "  --uninstall        Remove dotfiles and restore backups"
            exit 0
            ;;
    esac
done

# ── Pre-flight checks ─────────────────────────────────────────────
header "Pre-flight Checks"

if [[ ! -f /etc/os-release ]]; then
    warn "Cannot determine OS. This installer targets Fedora."
else
    source /etc/os-release
    if [[ "$ID" != "fedora" ]]; then
        warn "Detected $PRETTY_NAME (not Fedora). Package names may differ."
    fi
fi

if ! command -v dnf &>/dev/null; then
    warn "'dnf' package manager not found. Automatically skipping package installation."
    SKIP_DNF=true
fi

if [[ "$XDG_CURRENT_DESKTOP" != *"GNOME"* ]]; then
    err "GNOME desktop not detected (\$XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP)."
    err "This rice requires GNOME Shell 46+."
    exit 1
fi

GNOME_VERSION=$(gnome-shell --version 2>/dev/null | grep -oP '\d+\.\d+' || echo "unknown")
info "Detected: $PRETTY_NAME | GNOME Shell $GNOME_VERSION"
info "Dotfiles: $DOTFILES_DIR"
info "Backup:   $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"

# ── Helper: safe symlink with backup ──────────────────────────────
safe_link() {
    local src="$1" dst="$2"
    local dst_dir
    dst_dir="$(dirname "$dst")"

    mkdir -p "$dst_dir"

    if [[ -L "$dst" ]]; then
        local current_target
        current_target="$(readlink -f "$dst")"
        if [[ "$current_target" == "$(readlink -f "$src")" ]]; then
            return 0  # already correct
        fi
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        local rel_path="${dst#$HOME/}"
        local backup_path="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        cp -a "$dst" "$backup_path"
        rm -rf "$dst"
        info "Backed up: ~/$rel_path"
    fi

    if $DRY_RUN; then
        info "[dry-run] Would link: $src → $dst"
    else
        ln -sf "$src" "$dst"
    fi
}

# ── Helper: safe copy with backup ─────────────────────────────────
safe_copy() {
    local src="$1" dst="$2"
    local dst_dir
    dst_dir="$(dirname "$dst")"

    mkdir -p "$dst_dir"

    if [[ -e "$dst" ]]; then
        local rel_path="${dst#$HOME/}"
        local backup_path="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        cp -a "$dst" "$backup_path"
        info "Backed up: ~/$rel_path"
    fi

    if $DRY_RUN; then
        info "[dry-run] Would copy: $src → $dst"
    else
        cp -a "$src" "$dst"
    fi
}

# ══════════════════════════════════════════════════════════════════
# Phase 1: System Dependencies
# ══════════════════════════════════════════════════════════════════
header "Phase 1: System Dependencies"

DNF_PACKAGES=(
    # Core desktop
    kitty fish
    # Shell prompt & modern CLI
    starship eza bat zoxide fzf
    # Theming engine
    matugen
    # GNOME extensions (system)
    gnome-shell-extension-pop-shell
    # Build deps for GTK apps
    gtk3-devel gtk4-devel libadwaita-devel
    gtk-layer-shell-devel
    gobject-introspection-devel
    python3-gobject python3-pillow
    # Fonts
    mozilla-fira-sans-fonts
    # Cursor & icon themes
    bibata-cursor-themes
    # Misc
    wmctrl
)

if $SKIP_DNF; then
    warn "Skipping dnf package installation (--skip-dnf)"
elif $DRY_RUN; then
    info "[dry-run] Would install: ${DNF_PACKAGES[*]}"
else
    info "Installing system packages..."
    sudo dnf install -y "${DNF_PACKAGES[@]}" 2>&1 | tail -5 | tee -a "$LOG_FILE"
    log "System packages installed"
fi

# Oh My Posh (standalone binary)
if ! command -v oh-my-posh &>/dev/null; then
    if $DRY_RUN; then
        info "[dry-run] Would install oh-my-posh"
    else
        info "Installing oh-my-posh..."
        curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin 2>&1 | tail -3
        log "oh-my-posh installed"
    fi
else
    log "oh-my-posh already installed"
fi

# Ulauncher (pip)
if ! command -v ulauncher &>/dev/null; then
    if $DRY_RUN; then
        info "[dry-run] Would install ulauncher via pip"
    else
        info "Installing Ulauncher via pip..."
        pip install --user ulauncher 2>&1 | tail -3
        log "Ulauncher installed"
    fi
else
    log "Ulauncher already installed ($(ulauncher --version 2>/dev/null || echo 'unknown'))"
fi

# Kora icon theme (not in Fedora repos)
if [[ ! -d /usr/share/icons/kora ]] && [[ ! -d "$HOME/.local/share/icons/kora" ]]; then
    if $DRY_RUN; then
        info "[dry-run] Would install Kora icon theme"
    else
        info "Installing Kora icon theme..."
        KORA_TMP=$(mktemp -d)
        git clone --depth=1 https://github.com/bikass/kora.git "$KORA_TMP" 2>/dev/null
        mkdir -p "$HOME/.local/share/icons"
        cp -r "$KORA_TMP"/kora* "$HOME/.local/share/icons/" 2>/dev/null || true
        rm -rf "$KORA_TMP"
        gtk-update-icon-cache "$HOME/.local/share/icons/kora" 2>/dev/null || true
        log "Kora icon theme installed"
    fi
else
    log "Kora icon theme already installed"
fi

# Monaspace font
if ! fc-list | grep -qi "monaspace neon"; then
    if $DRY_RUN; then
        info "[dry-run] Would install Monaspace Neon font"
    else
        info "Installing Monaspace Neon font..."
        FONT_TMP=$(mktemp -d)
        MONO_URL="https://github.com/githubnext/monaspace/releases/latest/download/monaspace-v1.101.zip"
        curl -sL "$MONO_URL" -o "$FONT_TMP/monaspace.zip" 2>/dev/null
        unzip -qo "$FONT_TMP/monaspace.zip" -d "$FONT_TMP" 2>/dev/null || true
        mkdir -p "$HOME/.local/share/fonts"
        find "$FONT_TMP" -name "*.otf" -exec cp {} "$HOME/.local/share/fonts/" \;
        fc-cache -f 2>/dev/null
        rm -rf "$FONT_TMP"
        log "Monaspace Neon font installed"
    fi
else
    log "Monaspace Neon font already installed"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 2: GNOME Shell Extensions
# ══════════════════════════════════════════════════════════════════
header "Phase 2: GNOME Shell Extensions"

# Extensions to install from extensions.gnome.org (UUID format)
EXTENSIONS=(
    "space-bar@luchrioh"
    "blur-my-shell@aunetx"
    "burn-my-windows@schneegans.github.com"
    "dash-to-dock@micxgx.gmail.com"
    "floating-panel@aylur"
    "just-perfection-desktop@just-perfection"
    "clipboard-indicator@tudmotu.com"
    "hibernate-status@dromi"
    "widgets@aylur"
)

if $SKIP_EXTENSIONS; then
    warn "Skipping GNOME extension installation (--skip-extensions)"
else
    for ext_uuid in "${EXTENSIONS[@]}"; do
        ext_dir="$HOME/.local/share/gnome-shell/extensions/$ext_uuid"
        if [[ -d "$ext_dir" ]]; then
            log "Extension: $ext_uuid (already installed)"
        else
            if $DRY_RUN; then
                info "[dry-run] Would install extension: $ext_uuid"
            else
                info "Installing extension: $ext_uuid ..."
                # Use gext or busctl to install from e.g.o
                busctl --user call org.gnome.Shell.Extensions \
                    /org/gnome/Shell/Extensions \
                    org.gnome.Shell.Extensions InstallRemoteExtension s "$ext_uuid" 2>/dev/null || \
                    warn "Could not auto-install $ext_uuid — install manually from extensions.gnome.org"
            fi
        fi
    done
fi

# ══════════════════════════════════════════════════════════════════
# Phase 3: Configuration Symlinks
# ══════════════════════════════════════════════════════════════════
header "Phase 3: Configuration Files"

# Kitty
safe_link "$DOTFILES_DIR/config/kitty/kitty.conf"        "$HOME/.config/kitty/kitty.conf"
safe_link "$DOTFILES_DIR/config/kitty/current-theme.conf" "$HOME/.config/kitty/current-theme.conf"

# Ulauncher
safe_copy "$DOTFILES_DIR/config/ulauncher/settings.json"  "$HOME/.config/ulauncher/settings.json"
mkdir -p "$HOME/.config/ulauncher/user-themes/material-you"
for f in "$DOTFILES_DIR/config/ulauncher/user-themes/material-you/"*; do
    [[ -f "$f" ]] && safe_link "$f" "$HOME/.config/ulauncher/user-themes/material-you/$(basename "$f")"
done

# Pop Shell
safe_link "$DOTFILES_DIR/config/pop-shell/config.json" "$HOME/.config/pop-shell/config.json"

# Matugen
safe_link "$DOTFILES_DIR/config/matugen/config.toml" "$HOME/.config/matugen/config.toml"
for subdir in gtk-3.0 gtk-4.0 kitty ulauncher; do
    mkdir -p "$HOME/.config/matugen/templates/$subdir"
    for f in "$DOTFILES_DIR/config/matugen/templates/$subdir/"*; do
        [[ -f "$f" ]] && safe_link "$f" "$HOME/.config/matugen/templates/$subdir/$(basename "$f")"
    done
done

# Fish shell
safe_link "$DOTFILES_DIR/config/fish/config.fish" "$HOME/.config/fish/config.fish"

# Oh My Posh prompt
safe_link "$DOTFILES_DIR/config/ohmyposh/zen.toml" "$HOME/.config/ohmyposh/zen.toml"

# GTK settings
safe_link "$DOTFILES_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
safe_link "$DOTFILES_DIR/config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

# ── Scripts ────────────────────────────────────────────────────────
header "Phase 4: Desktop Scripts"

mkdir -p "$HOME/.local/bin"
for script in "$DOTFILES_DIR/scripts/"*; do
    [[ -f "$script" ]] || continue
    safe_link "$script" "$HOME/.local/bin/$(basename "$script")"
    chmod +x "$script"
done
log "Scripts linked to ~/.local/bin/"

# ── Systemd Services ──────────────────────────────────────────────
header "Phase 5: Systemd User Services"

mkdir -p "$HOME/.config/systemd/user"

# Ulauncher service (needs $HOME substitution)
ULAUNCHER_SVC="$DOTFILES_DIR/config/systemd/user/ulauncher.service"
if [[ -f "$ULAUNCHER_SVC" ]]; then
    sed "s|/home/zoecyber|$HOME|g" "$ULAUNCHER_SVC" > "$HOME/.config/systemd/user/ulauncher.service"
    log "ulauncher.service installed (paths adjusted)"
fi

# Matugen watcher service
MATUGEN_SVC="$DOTFILES_DIR/config/systemd/user/matugen-gnome.service"
if [[ -f "$MATUGEN_SVC" ]]; then
    sed "s|/home/zoecyber|$HOME|g" "$MATUGEN_SVC" > "$HOME/.config/systemd/user/matugen-gnome.service"
    log "matugen-gnome.service installed (paths adjusted)"
fi

if ! $DRY_RUN; then
    systemctl --user daemon-reload
    systemctl --user enable --now ulauncher.service 2>/dev/null || warn "ulauncher.service: enable failed"
    systemctl --user enable --now matugen-gnome.service 2>/dev/null || warn "matugen-gnome.service: enable failed"
    log "Systemd user services enabled"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 6: Ulauncher Pop Shell Patch
# ══════════════════════════════════════════════════════════════════
header "Phase 6: Ulauncher Pop Shell Float Patch"

PATCH_SCRIPT="$DOTFILES_DIR/patches/ulauncher-popshell-float.py"
if [[ -f "$PATCH_SCRIPT" ]]; then
    if $DRY_RUN; then
        info "[dry-run] Would patch ulauncher_window.py"
    else
        python3 "$PATCH_SCRIPT"
    fi
fi

# ══════════════════════════════════════════════════════════════════
# Phase 7: dconf / gsettings
# ══════════════════════════════════════════════════════════════════
header "Phase 7: GNOME Settings (dconf)"

if $DRY_RUN; then
    info "[dry-run] Would load dconf settings from $DOTFILES_DIR/dconf/"
else
    # Backup current dconf state (full)
    dconf dump / > "$BACKUP_DIR/dconf-full-backup.dconf"
    info "Full dconf state backed up to $BACKUP_DIR/dconf-full-backup.dconf"
    
    # Directory for specific path backups
    mkdir -p "$BACKUP_DIR/dconf-partial"

    # Load extension settings
    declare -A DCONF_MAP=(
        ["pop-shell.dconf"]="/org/gnome/shell/extensions/pop-shell/"
        ["space-bar.dconf"]="/org/gnome/shell/extensions/space-bar/"
        ["blur-my-shell.dconf"]="/org/gnome/shell/extensions/blur-my-shell/"
        ["just-perfection.dconf"]="/org/gnome/shell/extensions/just-perfection-desktop/"
        ["dash-to-dock.dconf"]="/org/gnome/shell/extensions/dash-to-dock/"
        ["floating-panel.dconf"]="/org/gnome/shell/extensions/floating-panel/"
        ["burn-my-windows.dconf"]="/org/gnome/shell/extensions/burn-my-windows/"
        ["clipboard-indicator.dconf"]="/org/gnome/shell/extensions/clipboard-indicator/"
        ["widgets.dconf"]="/org/gnome/shell/extensions/widgets/"
        ["desktop-interface.dconf"]="/org/gnome/desktop/interface/"
        ["desktop-wm.dconf"]="/org/gnome/desktop/wm/"
        ["mutter.dconf"]="/org/gnome/mutter/"
    )

    for file in "${!DCONF_MAP[@]}"; do
        dconf_file="$DOTFILES_DIR/dconf/$file"
        dconf_path="${DCONF_MAP[$file]}"
        if [[ -f "$dconf_file" ]] && [[ -s "$dconf_file" ]]; then
            # Safely backup the exact path before overwriting
            dconf dump "$dconf_path" > "$BACKUP_DIR/dconf-partial/$file.bak"
            echo "$dconf_path" > "$BACKUP_DIR/dconf-partial/$file.path"

            dconf load "$dconf_path" < "$dconf_file"
            log "Loaded: $file → $dconf_path"
        else
            warn "Skipped (empty/missing): $file"
        fi
    done

    # Enable extensions
    ENABLED_EXTENSIONS=$(cat <<'EOF'
['pop-shell@system76.com', 'space-bar@luchrioh', 'blur-my-shell@aunetx', 'burn-my-windows@schneegans.github.com', 'dash-to-dock@micxgx.gmail.com', 'floating-panel@aylur', 'just-perfection-desktop@just-perfection', 'clipboard-indicator@tudmotu.com', 'hibernate-status@dromi', 'widgets@aylur', 'apps-menu@gnome-shell-extensions.gcampax.github.com', 'background-logo@fedorahosted.org']
EOF
)
    gsettings set org.gnome.shell enabled-extensions "$ENABLED_EXTENSIONS"
    log "Enabled GNOME extensions"
fi

# ══════════════════════════════════════════════════════════════════
# Phase 8: Keybindings
# ══════════════════════════════════════════════════════════════════
header "Phase 8: Keyboard Shortcuts"

KEYBINDS_SCRIPT="$DOTFILES_DIR/keybinds/apply_keybinds.sh"
if [[ -f "$KEYBINDS_SCRIPT" ]]; then
    # Adjust paths for current user
    sed "s|/home/zoecyber|$HOME|g" "$KEYBINDS_SCRIPT" > /tmp/apply_keybinds_adjusted.sh
    if $DRY_RUN; then
        info "[dry-run] Would apply keybindings from apply_keybinds.sh"
    else
        bash /tmp/apply_keybinds_adjusted.sh 2>&1 | tee -a "$LOG_FILE"
        rm -f /tmp/apply_keybinds_adjusted.sh
        log "Keybindings applied"
    fi
fi

# ══════════════════════════════════════════════════════════════════
# Phase 9: Initial Theme Generation
# ══════════════════════════════════════════════════════════════════
header "Phase 9: Initial Material You Theme"

mkdir -p "$HOME/Pictures/Wallpapers"

if $DRY_RUN; then
    info "[dry-run] Would generate initial Material You theme"
else
    # If there's a wallpaper already set, run matugen on it
    CURRENT_WP=$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | tr -d "'" | sed 's|file://||')
    if [[ -n "$CURRENT_WP" ]] && [[ -f "$CURRENT_WP" ]]; then
        info "Generating Material You theme from current wallpaper..."
        "$HOME/.local/bin/matugen-gnome" "$CURRENT_WP" 2>&1 | tail -3 || true
    elif command -v matugen &>/dev/null; then
        # Fetch a starter wallpaper
        info "Fetching a starter wallpaper..."
        "$HOME/.local/bin/fetch-wallpaper" 2>&1 | tail -5 || true
    fi
fi

# ══════════════════════════════════════════════════════════════════
# Done
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  ✓ Installation Complete${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Backup location:${NC}  $BACKUP_DIR"
echo -e "  ${CYAN}Install log:${NC}      $LOG_FILE"
echo ""
echo -e "  ${BOLD}Keyboard Shortcuts:${NC}"
echo -e "    Alt+Space         Ulauncher (spotlight launcher)"
echo -e "    Super+Return      Kitty terminal"
echo -e "    Super+b           Brave Browser"
echo -e "    Super+e           Nautilus Files"
echo -e "    Super+w           Wallpaper Studio"
echo -e "    Super+a           App Drawer (Launchpad)"
echo -e "    Super+q           Close window"
echo -e "    Super+1..9        Switch workspace"
echo -e "    Super+h/j/k/l     Navigate tiled windows"
echo -e "    Ctrl+Super+t      Random Material You wallpaper"
echo -e "    Ctrl+Super+w      Fetch online wallpaper"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "    1. Log out and back in (or press Alt+F2, type 'r', Enter)"
echo -e "    2. Press Ctrl+Super+t to apply a random Material You theme"
echo -e "    3. Press Super+w to open Wallpaper Studio"
echo ""
