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
  `packages/wvkbd` (the AUR package plus touch patches: a held key such as Backspace
  repeats; a tapped key stays lit for 150 ms; the key popup is a magnified preview
  above the key, as on phone keyboards; and standard US QWERTY layouts like Gboard's,
  with ?123 / =\< symbol pages and an Omarchy (Super) key).
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
  - `dock-reveal.patch`: an `omarchy-shell omarchy.dock reveal` command that brings an
    auto-hidden dock up for a few seconds; tablet mode's short bottom swipe uses it.

**Home** (symlinked from `home/`)
- `~/.local/bin/surface-osk`: Type Cover watcher (layout styles: `standard` = Gboard-like
  US QWERTY, `numbers` = the same with a number row). Cover off → tablet mode on and
  the keyboard pops up on text fields; cover on → desktop mode. `surface-osk toggle`
  shows/hides the keyboard; `surface-osk set style|size|click ...` changes its
  layout (saved in `~/.config/surface-osk/settings`, also set from the Control
  Center's Keyboard page). Besides English it shows your system language
  (Hyprland `kb_layout`, then `$LANG`) when wvkbd has a layout for it. Key click:
  the Surface Pro 4 has no vibration motor, so each key press plays a soft click
  (`~/.local/share/surface-osk/click.wav`, from the sound server's sample cache);
  on by default, switchable on the Keyboard page. Word suggestions (Gboard-style
  strip above the keys): `~/.local/bin/surface-osk-keys` reads the keys wvkbd reports,
  completes the word being typed from fcitx5's English dictionary, offers typo fixes
  and next words, learns your words (plain-letter new words only after 3 uses;
  `~/.local/share/surface-osk/learned.json`, mode 600), and types a tapped suggestion
  with wtype. Suggestions on/off and Forget learned words on the Keyboard page.
- `~/.local/bin/tablet-mode on|off|toggle|status|home|refit`.
- `~/.config/hypr/tablet.lua`: tablet look (big titlebars, apps fill the screen), tablet
  motion (sliding workspaces, springy app open, keyboard slides up), and
  workspace swipes in both modes (touchscreen edge swipe, 3-finger touchpad swipe).
- Shell plugins in `~/.config/omarchy/plugins/`:
  - `devsecai.control-center`: Control Center panel (Wi-Fi, Bluetooth, keyboard, Dock always-show/auto-hide,
    volume, brightness, ...)
  - `devsecai.gestures`: edge swipes (bottom: by distance, shown live while swiping:
    a little = dock (only while the dock is set to auto-hide), partway = app switcher,
    far = app drawer; bottom-right: keyboard,
    top-right pull-down: Control Center, top-left pull-down: Notification Center) and the keyboard dismiss tab
  - `devsecai.notification-center`: Notification Center (pull down on the left of the
    tablet bar): Omarchy's notification history grouped by app, tap to open the app
    (`~/.local/bin/tablet-open-app`, which also restores minimized windows), slide to
    dismiss, two-tap Clear All, Do Not Disturb; frosted-glass background
  - `devsecai.app-drawer`: app drawer (long swipe up from the bottom edge), laid out like
    Android's drawer / iPadOS App Library: search pill (tap for the keyboard), suggestions
    row of recently opened apps, every app A to Z as large icons; opens over what you are
    doing, swipe down to close. Uses Omarchy's app library for apps, icons and launching
  - `devsecai.app-switcher`: app switcher (swipe up partway from the bottom edge), as on
    iOS/Android: every open window (minimized ones too) as a live card, most recent
    first; tap a card to switch to it (`tablet-open-app --address`), slide it up to
    close the window
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

`git log` has the reasoning behind each change. `TODO.md` lists what is planned,
starting with making this work on any x86 tablet, not only the Surface Pro 4.

