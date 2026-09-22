#!/usr/bin/env bash
set -euo pipefail

# ┌─────────────────────────────────────────────────────────────────────┐
# │  zoecyber-dotfiles uninstaller                                     │
# │  Removes symlinks, restores backups, disables services.            │
# └─────────────────────────────────────────────────────────────────────┘

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
info()  { echo -e "${CYAN}[*]${NC} $*"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE="$HOME/.dotfiles-backup"

echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${RED}  zoecyber-dotfiles Uninstaller${NC}"
echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Find the most recent backup
if [[ -d "$BACKUP_BASE" ]]; then
    LATEST_BACKUP=$(ls -1d "$BACKUP_BASE"/*/ 2>/dev/null | sort -r | head -1)
    if [[ -n "$LATEST_BACKUP" ]]; then
        info "Found backup: $LATEST_BACKUP"
    fi
else
    warn "No backup directory found at $BACKUP_BASE"
    LATEST_BACKUP=""
fi

echo ""
read -rp "This will remove dotfiles symlinks and restore backups. Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
echo ""

# ── Remove symlinks ───────────────────────────────────────────────
SYMLINKS=(
    "$HOME/.config/kitty/kitty.conf"
    "$HOME/.config/kitty/current-theme.conf"
    "$HOME/.config/pop-shell/config.json"
    "$HOME/.config/matugen/config.toml"
    "$HOME/.config/fish/config.fish"
    "$HOME/.config/ohmyposh/zen.toml"
    "$HOME/.config/gtk-3.0/settings.ini"
    "$HOME/.config/gtk-4.0/settings.ini"
)

# Matugen template symlinks
for subdir in gtk-3.0 gtk-4.0 kitty ulauncher; do
    for f in "$HOME/.config/matugen/templates/$subdir/"*; do
        [[ -L "$f" ]] && SYMLINKS+=("$f")
    done
done

# Ulauncher theme symlinks
for f in "$HOME/.config/ulauncher/user-themes/material-you/"*; do
    [[ -L "$f" ]] && SYMLINKS+=("$f")
done

# Script symlinks
for f in "$DOTFILES_DIR/scripts/"*; do
    local_name="$HOME/.local/bin/$(basename "$f")"
    [[ -L "$local_name" ]] && SYMLINKS+=("$local_name")
done

for link in "${SYMLINKS[@]}"; do
    if [[ -L "$link" ]]; then
        rm "$link"
        log "Removed symlink: $link"
    fi
done

# ── Disable systemd services ─────────────────────────────────────
info "Disabling systemd user services..."
systemctl --user disable --now ulauncher.service 2>/dev/null || true
systemctl --user disable --now matugen-gnome.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/ulauncher.service"
rm -f "$HOME/.config/systemd/user/matugen-gnome.service"
systemctl --user daemon-reload
log "Systemd services disabled"

# ── Restore backups ───────────────────────────────────────────────
if [[ -n "$LATEST_BACKUP" ]] && [[ -d "$LATEST_BACKUP" ]]; then
    info "Restoring files from backup..."
    cd "$LATEST_BACKUP"
    find . -type f | while read -r rel_file; do
        dst="$HOME/${rel_file#./}"
        mkdir -p "$(dirname "$dst")"
        cp -a "$rel_file" "$dst"
        log "Restored: $dst"
    done
    cd -
fi

# ── Restore default dconf ────────────────────────────────────────
DCONF_BACKUP="$LATEST_BACKUP/dconf-full-backup.dconf"
if [[ -f "$DCONF_BACKUP" ]]; then
    read -rp "Restore full dconf state from backup? This resets ALL GNOME settings. [y/N] " dconf_confirm
    if [[ "$dconf_confirm" =~ ^[Yy]$ ]]; then
        dconf load / < "$DCONF_BACKUP"
        log "Full dconf state restored"
    else
        warn "Skipped dconf restore. Extension settings may remain."
    fi
fi

echo ""
echo -e "${BOLD}${GREEN}  ✓ Uninstall Complete${NC}"
echo -e "  Log out and back in to fully revert GNOME Shell changes."
echo ""
