# Surface Pro 4 tablet setup for Omarchy

Touchscreen support and a tablet mode for a Surface Pro 4 running Omarchy
(Arch Linux, Hyprland with Lua config, Quickshell-based omarchy-shell, Limine).

```
git clone <this repo> ~/surface-tablet
~/surface-tablet/install.sh     # then reboot
```

`./install.sh --home` redoes only the home-directory part (no sudo);
`./install.sh --patches` only the Omarchy shell patches.

## What it sets up

**System** (needs sudo)
- linux-surface pacman repo and signing key; packages `linux-surface`,
  `linux-surface-headers`, `iptsd`, `squeekboard`, and `wvkbd` built from
  `packages/wvkbd` (the AUR package plus a patch so a held key, like Backspace, repeats).
- `BOOT_ORDER="linux-surface, *, *fallback, Snapshots"` in `/etc/default/limine`,
  then `limine-update`. Without it Limine boots the stock kernel and touch is dead.
- `/etc/iptsd.d/10-low-latency.conf`: smaller contact movement threshold.

- Omarchy shell touch patches (`system/usr/local/share/surface-tablet/omarchy-patches/`),
  applied by `/usr/local/bin/surface-omarchy-patches` and re-applied by a pacman hook
  after every Omarchy update. A patch that no longer fits a new version is skipped,
  not forced. Currently:
  - `image-picker-slide.patch`: slide a finger (or scroll) through the theme/background picker.
  - `dock-autohide-touch.patch`: the dock shows on every workspace (Omarchy limits it to
    floating ones) and follows its Always show / Auto-hide setting in
    every case. Shown, it reserves its edge (tiled and maximized apps stop above it); auto-hidden,
    the bottom edge brings it back by pointer or finger, also over fullscreen apps.

**Home** (symlinked from `home/`)
- `~/.local/bin/surface-osk`: Type Cover watcher. Cover off → tablet mode on and
  the keyboard pops up on text fields; cover on → desktop mode. `surface-osk toggle`
  shows/hides the keyboard; `surface-osk set style|size|click ...` changes its
  layout (saved in `~/.config/surface-osk/settings`, also set from the Control
  Center's Keyboard page). Besides English it shows your system language
  (Hyprland `kb_layout`, then `$LANG`) when wvkbd has a layout for it. Key click:
  the Surface Pro 4 has no vibration motor, so each key press plays a soft click
  (`~/.local/share/surface-osk/click.wav`, from the sound server's sample cache);
  on by default, switchable on the Keyboard page.
- `~/.local/bin/tablet-mode on|off|toggle|status|home|refit`.
- `~/.config/hypr/tablet.lua`: tablet look (big titlebars, apps fill the screen), tablet
  motion (sliding workspaces, springy app open, keyboard slides up), and
  workspace swipes in both modes (touchscreen edge swipe, 3-finger touchpad swipe).
- Shell plugins in `~/.config/omarchy/plugins/`:
  - `devsecai.control-center`: Control Center panel (Wi-Fi, Bluetooth, keyboard, Dock always-show/auto-hide,
    volume, brightness, ...)
  - `devsecai.gestures`: edge swipes (bottom: short swipe dock / long swipe app drawer, bottom-right: keyboard,
    top-right pull-down: Control Center, top-left pull-down: Notification Center) and the keyboard dismiss tab
  - `devsecai.notification-center`: Notification Center (pull down on the left of the
    tablet bar): Omarchy's notification history grouped by app, tap to open the app
    (`~/.local/bin/tablet-open-app`, which also restores minimized windows), slide to
    dismiss, two-tap Clear All, Do Not Disturb; frosted-glass background
  - `devsecai.app-drawer`: app drawer (long swipe up from the bottom edge), laid out like
    Android's drawer / iPadOS App Library: search pill (tap for the keyboard), suggestions
    row of recently opened apps, every app A to Z as large icons; opens over what you are
    doing, swipe down to close. Uses Omarchy's app library for apps, icons and launching
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

## Pending on this machine
Built but needing sudo to install:
- `./install.sh --patches`: theme picker slides by touch; dock follows its auto-hide setting
  and comes back by touch and over fullscreen apps.
- `sudo pacman -S squeekboard`: keyboard pops up on text fields (conflicts with fcitx5,
  which currently owns the input method).

`git log` has the reasoning behind each change.

