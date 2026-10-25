#!/bin/bash
# Surface Pro 4 touch + tablet mode for Omarchy (Arch, Hyprland Lua config,
# Limine). Safe to run again: every step checks before it changes anything.
#
#   ./install.sh          everything (asks for sudo for the system part)
#   ./install.sh --home   only your home directory, no sudo
#   ./install.sh --patches  only the Omarchy shell touch patches (sudo)
#
# Files under home/ are symlinked into $HOME, so editing them in place edits
# this repo. Files that also hold your own settings (hyprland.lua, bindings,
# shell.json, ...) are patched with a few lines instead of replaced.

set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%s)

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- system

install_system() {
  say "linux-surface package repository"
  if ! grep -q '^\[linux-surface\]' /etc/pacman.conf; then
    curl -fsSL https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc |
      sudo pacman-key --add -
    sudo pacman-key --lsign-key 56C464BAAC421453
    printf '\n[linux-surface]\nServer = https://pkg.surfacelinux.com/arch/\n' | sudo tee -a /etc/pacman.conf >/dev/null
  fi

  say "Packages: surface kernel, touch daemon, on-screen keyboards"
  sudo pacman -Syu --needed linux-surface linux-surface-headers iptsd squeekboard
  # Fallback keyboard: the AUR package, patched so held keys repeat on touch.
  if [[ $(pacman -Q wvkbd 2>/dev/null) != "wvkbd 0.20-1.6" ]]; then
    (cd "$REPO/packages/wvkbd" && makepkg -si --noconfirm --needed)
  fi

  say "Boot the surface kernel first (Limine)"
  if ! grep -q '^BOOT_ORDER=' /etc/default/limine; then
    echo 'BOOT_ORDER="linux-surface, *, *fallback, Snapshots"' | sudo tee -a /etc/default/limine >/dev/null
  fi
  sudo limine-update

  say "Lower touch latency (iptsd)"
  sudo install -Dm644 "$REPO/system/etc/iptsd.d/10-low-latency.conf" /etc/iptsd.d/10-low-latency.conf
  sudo systemctl restart 'iptsd@*' 2>/dev/null || true

  say "Touch patches for the Omarchy shell (kept across Omarchy updates)"
  install_omarchy_patches
}

# Patches to Omarchy's own shell files (e.g. sliding through the theme picker
# by touch), plus a pacman hook that puts them back after each Omarchy update.
install_omarchy_patches() {
  sudo install -Dm755 "$REPO/system/usr/local/bin/surface-omarchy-patches" /usr/local/bin/surface-omarchy-patches
  sudo install -Dm644 "$REPO/system/etc/pacman.d/hooks/surface-omarchy-patches.hook" /etc/pacman.d/hooks/surface-omarchy-patches.hook
  sudo rm -rf /usr/local/share/surface-tablet/omarchy-patches
  sudo install -Dm644 -t /usr/local/share/surface-tablet/omarchy-patches "$REPO"/system/usr/local/share/surface-tablet/omarchy-patches/*.patch
  sudo /usr/local/bin/surface-omarchy-patches
}

# ---------------------------------------------------------------- home

link() {
  local src=$REPO/home/$1 dst=$HOME/$1
  mkdir -p "$(dirname "$dst")"
  [[ -L $dst && $(readlink "$dst") == "$src" ]] && return
  [[ -e $dst ]] && mv "$dst" "$dst.bak.$STAMP"
  ln -s "$src" "$dst"
}

# Add a block of lines to a file once, marked so it isn't added twice.
append_once() {
  local file=$1 marker=$2 text=$3
  grep -qF "$marker" "$file" 2>/dev/null && return
  printf '\n%s\n' "$text" >>"$file"
}

install_home() {
  say "Scripts, tablet.lua and shell plugins"
  (cd "$REPO/home" && find . -type f) | sed 's|^\./||' | while read -r file; do
    link "$file"
  done

  say "Hyprland config"
  local hypr=$HOME/.config/hypr
  if ! grep -q 'require("hypr.tablet")' "$hypr/hyprland.lua"; then
    cp "$hypr/hyprland.lua" "$hypr/hyprland.lua.bak.$STAMP"
    awk '
      /^require\("default.hypr.omarchy"\)/ {
        print "-- Tablet mode (see hypr/tablet.lua) has to wrap a few things before Omarchy loads."
        print "local tablet = require(\"hypr.tablet\")"
        print "tablet.before()"
        print ""
      }
      { print }
      /^require\("default.hypr.toggles"\)/ {
        print ""
        print "-- Tablet mode overrides go last so they win while it is on."
        print "tablet.after()"
      }
    ' "$hypr/hyprland.lua.bak.$STAMP" >"$hypr/hyprland.lua"
  fi
  append_once "$hypr/autostart.lua" "surface-osk" \
'-- On-screen keyboard: shows when the Type Cover is detached
o.launch_on_start(os.getenv("HOME") .. "/.local/bin/surface-osk")'
  append_once "$hypr/bindings.lua" "surface-osk toggle" \
'-- Toggle the on-screen keyboard
o.bind("SUPER + SHIFT + K", "On-screen keyboard", os.getenv("HOME") .. "/.local/bin/surface-osk toggle")'

  say "Chromium: tell the on-screen keyboard about text fields"
  local flags=$HOME/.config/chromium-flags.conf
  for flag in --enable-wayland-ime --wayland-text-input-version=3; do
    grep -qxF -- "$flag" "$flags" 2>/dev/null || echo "$flag" >>"$flags"
  done

  say "Omarchy shell: enable plugins, add the bar buttons"
  local json=$HOME/.config/omarchy/shell.json tmp
  if [[ -f $json ]] && ! grep -q '"devsecai.' "$json"; then
    cp "$json" "$json.bak.$STAMP"
    tmp=$(mktemp)
    jq '
      .bar.layout.right = ([{ id: "devsecai.osk" }] + (.bar.layout.right // []))
      | .bar.layout.right |= (.[:2] + [{ id: "devsecai.tablet" }] + .[2:])
    ' "$json" >"$tmp" && mv "$tmp" "$json"
  fi
  # Panels and services, each added once (so later additions reach old installs).
  if [[ -f $json ]]; then
    tmp=$(mktemp)
    jq '
      reduce ("devsecai.control-center", "devsecai.gestures", "devsecai.notification-center", "devsecai.app-drawer", "devsecai.app-switcher") as $id
        (.; if any((.plugins // [])[]; .id == $id) then . else .plugins = ((.plugins // []) + [{ id: $id }]) end)
    ' "$json" >"$tmp" && mv "$tmp" "$json"
  fi
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  # Service plugins are only loaded at shell start.
  omarchy restart shell >/dev/null 2>&1 || true
}

case ${1:-} in
  --home) install_home ;;
  --patches) install_omarchy_patches; omarchy restart shell >/dev/null 2>&1 || true ;;
  "") install_system; install_home; say "Done. Reboot into the linux-surface kernel." ;;
  *) echo "Usage: $0 [--home|--patches]" >&2; exit 1 ;;
esac
