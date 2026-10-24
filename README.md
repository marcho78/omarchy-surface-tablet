# Surface Pro 4 tablet setup for Omarchy

Touchscreen support and a tablet mode for a Surface Pro 4 running Omarchy
(Arch Linux, Hyprland with Lua config, Quickshell-based omarchy-shell, Limine).

```
git clone <this repo> ~/surface-tablet
~/surface-tablet/install.sh     # then reboot
```

`./install.sh --home` redoes only the home-directory part (no sudo).

## What it sets up

**System** (needs sudo)
- linux-surface pacman repo and signing key; packages `linux-surface`,
  `linux-surface-headers`, `iptsd`, `squeekboard`, and `wvkbd` (AUR, fallback keyboard).
- `BOOT_ORDER="linux-surface, *, *fallback, Snapshots"` in `/etc/default/limine`,
  then `limine-update`. Without it Limine boots the stock kernel and touch is dead.
- `/etc/iptsd.d/10-low-latency.conf`: smaller contact movement threshold.

**Home** (symlinked from `home/`)
- `~/.local/bin/surface-osk`: Type Cover watcher. Cover off → tablet mode on and
  the keyboard pops up on text fields; cover on → desktop mode. `surface-osk toggle`
  shows/hides the keyboard.
- `~/.local/bin/tablet-mode on|off|toggle|status|home|refit`.
- `~/.config/hypr/tablet.lua`: tablet look (big titlebars, apps fill the screen).
- Shell plugins in `~/.config/omarchy/plugins/`:
  - `devsecai.control-center`: Control Center panel (Wi-Fi, Bluetooth, keyboard,
    volume, brightness, ...)
  - `devsecai.gestures`: edge swipes (bottom: dock / Home, bottom-right: keyboard,
    top-right pull-down: Control Center, top-left pull-down: notifications) and the keyboard dismiss tab
  - `devsecai.tablet-clock`, `devsecai.tablet-status`: tablet bar widgets
  - `devsecai.osk`, `devsecai.tablet`: desktop bar buttons (keyboard, tablet mode)

**Patched** (a few lines added to files that hold your own settings)
- `~/.config/hypr/hyprland.lua`: `tablet.before()` / `tablet.after()` around Omarchy's defaults
- `~/.config/hypr/autostart.lua`: starts `surface-osk`
- `~/.config/hypr/bindings.lua`: `Super+Shift+K` toggles the keyboard
- `~/.config/chromium-flags.conf`: `--enable-wayland-ime --wayland-text-input-version=3`
- `~/.config/omarchy/shell.json`: enables the plugins, adds the bar buttons

## Notes
- Service plugins (gestures) only reload with `omarchy restart shell`.
- `tools/taplog.py` (run with sudo) logs touch events, for debugging lag.
