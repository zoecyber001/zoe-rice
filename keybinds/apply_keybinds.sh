#!/usr/bin/env bash

# Reset custom list first to clear dead entries
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[]"

# Window control
gsettings set org.gnome.desktop.wm.keybindings close "['<Super>q']"
gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "['<Super>m', '<Super>z']"
gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Super>f']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>l']"
gsettings set org.gnome.settings-daemon.plugins.media-keys email "[]"
gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>e']"
gsettings set org.gnome.shell.keybindings show-screenshot-ui "['<Super><Shift>s', 'Print']"
# Unbind space-bar extension menu from <Super>w to avoid collision with Wallpaper Studio
dconf write /org/gnome/shell/extensions/space-bar/shortcuts/open-menu "@as []"

# Unbind default window menu from <Alt>space to allow Ulauncher toggle
gsettings set org.gnome.desktop.wm.keybindings activate-window-menu "[]"
gsettings set org.gnome.shell.extensions.pop-shell activate-launcher "['<Super>slash']"
gsettings set org.gnome.shell.extensions.pop-shell tile-by-default true
gsettings set org.gnome.shell.extensions.pop-shell smart-gaps true
gsettings set org.gnome.shell.extensions.pop-shell show-title false

# Fixed workspaces 1 to 9
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 9
for i in {1..9}; do
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-$i "['<Super>$i']"
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-$i "['<Super><Shift>$i']"
done

# Active custom shortcuts (delimiter: |)
BIND_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

declare -a BINDINGS=(
  "Brave Browser|brave-browser|<Super>b"
  "Gemini PWA|brave-browser --app=https://gemini.google.com|<Super>g"
  "Nautilus Files|nautilus|<Super>e"
  "VS Code|code|<Super>c"
  "Ulauncher|ulauncher toggle|<Alt>space"
  "Launchpad Script|$HOME/.local/bin/launchpad.py|<Super>a"
  "Kitty Terminal|kitty|<Super>Return"
  "Random Wallpaper (Material You)|$HOME/.local/bin/matugen-gnome --random|<Ctrl><Super>t"
  "Fetch Online Wallpaper|$HOME/.local/bin/fetch-wallpaper|<Ctrl><Super>w"
  "Wallpaper Studio|$HOME/.local/bin/wallpaper-picker|<Super>w"
)

CUSTOM_LIST=""
INDEX=0

for item in "${BINDINGS[@]}"; do
  IFS="|" read -r name cmd binding <<< "$item"
  PATH_ENTRY="${BIND_PATH}/custom${INDEX}/"
  
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${PATH_ENTRY}" name "$name"
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${PATH_ENTRY}" command "$cmd"
  gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${PATH_ENTRY}" binding "$binding"
  
  if [ -z "$CUSTOM_LIST" ]; then
    CUSTOM_LIST="'${PATH_ENTRY}'"
  else
    CUSTOM_LIST="${CUSTOM_LIST}, '${PATH_ENTRY}'"
  fi
  
  ((INDEX++))
done

gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[$CUSTOM_LIST]"

echo "Cleaned keybindings applied."
