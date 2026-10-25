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
- `/etc/iptsd.d/20-tracking.conf`: `AspectMax = 4`. A fast-moving finger smears into a longer
  blob; at the default 2.5 iptsd dropped it mid-drag, so swipes arrived as several short
  touches (pull-downs failed; pieces landed as taps, e.g. accepting word suggestions).
- Cameras: `libcamera`, `libcamera-ipa`, `libcamera-tools` (`cam -l`) and `pipewire-libcamera`
  (apps) drive the front (OV5693) and back (OV8865) cameras; the IR camera isn't supported.
  The back camera came out black: the sensor's black level target defaults to 16 while
  libcamera's IPU3 processing takes 64 off every pixel. `/usr/local/bin/surface-camera-fix`
  rebuilds the OV8865 driver from linux-surface's source with the target at 64
  (`system/usr/local/share/surface-tablet/ov8865/ov8865-black-level.patch`) into
  `/usr/lib/modules/<kernel>/updates/` (no package files touched), and a pacman hook
  rebuilds it for each new linux-surface kernel. `surface-camera-fix --remove` undoes it.
  Apps reach the cameras through PipeWire: Snapshot ("Camera", installed with them) takes
  photos and videos with both. Browsers are untested (Chromium needs
  `--enable-features=WebRtcPipeWireCamera`, not set). Monologue can't: Qt's camera
  backends only open V4L2 webcams (its GStreamer backend skips PipeWire's libcamera
  cameras too), and these cameras only work through libcamera. A v4l2loopback virtual
  webcam fed from PipeWire would be the way; not set up.

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
  - `bar-touch-lock.patch`: the top bar is locked in tablet mode. Omarchy turns a press
    that moves a few pixels into a drag that rearranges the bar's icons (or moves the bar
    to another edge); a finger always moves a little, so taps were lost and icons could
    end up under the pull-down strips, out of reach.

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
  The strip also has Esc at its left end (`wtype -k Escape`; wvkbd keeps Esc two pages
  away, on =\<).
  Voice typing: the mic in the suggestion strip runs `~/.local/bin/surface-dictate
  toggle`, red and pulsing while it listens (state in
  `$XDG_RUNTIME_DIR/surface-dictate/state`). Vosk, through `nerd-dictation` (AUR, with
  `python-vosk` and the small English model, `vosk-model-small-en-us-0.15`, in
  `~/.local/share/vosk/`), types at the cursor while you speak, with `wtype`, and
  corrects the last words as it hears more. Offline. The first word is capitalised;
  the small model types no punctuation. It stops after 30 seconds without speech, or
  when the keyboard is put away. Not in `--continuous` mode: that types each phrase
  without a space before it, so phrases ran together. Omarchy's own dictation keys
  (Super+Ctrl+X, hold F9 / Right Alt) use Voxtype as Omarchy sets it up: offline
  Whisper, more accurate, with punctuation, but it types once you stop. Live Whisper
  (`whisper.streaming`) was tried: on this i5-6300U each pass took 3.5-4 s against
  Voxtype's 0.8 s tick, so it fell behind and stuck. `./install.sh --voice` sets both up.
- `~/.local/bin/tablet-mode on|off|toggle|status|home|refit`. Swaps in the tablet bar
  (clock, workspaces with O-Spotlight's search icon beside them, status pill), carries
  Stage Control's, O-Spotlight's and Uber TV's bar entries over and their settings back,
  and reloads the shell's plugins after each switch (they only see bar settings change
  then).
- `~/.config/hypr/tablet.lua`: tablet look (big titlebars, apps fill the screen), tablet
  motion (sliding workspaces, springy app open, keyboard slides up), and
  workspace swipes in both modes (touchscreen edge swipe, 3-finger touchpad swipe).
- Shell plugins in `~/.config/omarchy/plugins/`:
  - `devsecai.control-center`: Control Center panel (Wi-Fi, Bluetooth, keyboard, Dock always-show/auto-hide,
    volume, brightness, ...), with a Media Center tile that opens Uber TV when it is installed
  - `devsecai.gestures`: edge swipes (bottom: by distance, shown live while swiping:
    a little = dock (only while the dock is set to auto-hide), partway (to 45% of the
    screen) = Stage Control, further (to 62%) = Search (O-Spotlight), far = app drawer;
    bottom-right: keyboard,
    top-right pull-down: Control Center, top-left pull-down: Notification Center) and the keyboard dismiss tab.
    Coming back down to the bottom after a swipe has started keeps Dock lit instead of
    cancelling. While Omarchy's screensaver shows in tablet mode, a full-screen tap layer
    closes it on any tap (SIGHUP to `omarchy-screensaver`, which exits cleanly): it only
    closes on a key press, and there is no keyboard.
  - `devsecai.notification-center`: Notification Center (pull down on the left of the
    tablet bar): Omarchy's notification history grouped by app, tap to open the app
    (`~/.local/bin/tablet-open-app`, which also restores minimized windows), slide to
    dismiss, two-tap Clear All, Do Not Disturb; frosted-glass background
  - `devsecai.app-drawer`: app drawer (long swipe up from the bottom edge), laid out like
    Android's drawer / iPadOS App Library: search pill (tap for the keyboard), suggestions
    row of recently opened apps, every app A to Z as large icons; opens over what you are
    doing, swipe down to close. Uses Omarchy's app library for apps, icons and launching.
    Searches apps only (O-Spotlight searches everything). In tablet mode it takes the
    keyboard on demand, not exclusively: an exclusive grab made Hyprland send every touch
    to the drawer, so a tap on a key opened the app under it
  - `devsecai.app-switcher`: app switcher, as on iOS/Android: every open window
    (minimized ones too) as a live card, most recent first; tap a card to switch to it
    (`tablet-open-app --address`), slide it up to close the window. No longer on the
    bottom swipe (Stage Control replaced it); kept for now
  - `devsecai.tablet-clock`, `devsecai.tablet-status`: tablet bar widgets
  - `devsecai.osk`, `devsecai.tablet`: desktop bar buttons (keyboard, tablet mode)

**Third-party plugins** (marcho78's, installed with `omarchy plugin add`; not copied here)
- `marcho78.stage-control`: Mission Control-style overview of every window and desktop.
  Bottom swipe partway in tablet mode, `Super+D` docked (`stageKey` in shell.json; Omarchy
  already uses Super+A and Super+Tab). Touch mode in tablet mode: the desktops bar stays
  open, window titles and close buttons always show (bigger), long-press a desktop to
  rename it.
- `marcho78.o-spotlight`: Spotlight-style search for apps, Omarchy actions and settings,
  files and maths, with 12 styles. `Alt+Space` and the bar icon docked; in tablet mode the
  search icon in the middle of the bar, or the bottom swipe to Search. Touch mode: the
  on-screen keyboard opens and closes with it, the search fits above the keyboard (and
  follows it when you put it away), no hover-only controls, long-press the magnifying glass
  in its search field for settings, keyboard-shortcut hints hidden, keyboard focus on demand.
- `marcho78.om-pg` (Uber TV): media center for YouTube, IPTV, its guide and apps.
  `Super+Alt+T` or its bar button (a play icon, so it doesn't look like the bar's display
  and laptop icons) docked; in tablet mode the Control Center's Media Center tile, with
  its bar icon hidden: its bar button now also hides when its bar entry has
  `"barIcon": false`, which the tablet bar sets.
- The touch-mode changes are local edits in those plugins' own git repos; they follow
  tablet mode through `~/.local/state/tablet-mode/state` (Uber TV's through its bar entry).

**Patched** (a few lines added to files that hold your own settings)
- `~/.config/hypr/hyprland.lua`: `tablet.before()` / `tablet.after()` around Omarchy's defaults
- `~/.config/hypr/autostart.lua`: starts `surface-osk`
- `~/.config/hypr/bindings.lua`: `Super+Shift+K` toggles the keyboard
- `~/.config/chromium-flags.conf`: `--enable-wayland-ime --wayland-text-input-version=3`
- `~/.config/omarchy/shell.json`: enables the plugins, adds the bar buttons

## Camera hardware

| Part | Hardware | Driver (kernel module) |
|---|---|---|
| Camera interface | Intel IPU3 CSI-2 receiver | `ipu3-cio2`, plus `ipu_bridge`, which wires the sensors up from ACPI |
| Image processor | Intel IPU3 ImgU | `ipu3-imgu` + firmware `intel/irci_irci_ecr-master_20161208_0213_20170112_1500.bin` (from `linux-firmware`) |
| Front camera | OV5693 (ACPI `INT33BE`) | `ov5693` |
| Back camera | OV8865 (ACPI `INT347A`) | `ov8865` (our rebuilt copy in `updates/`) |
| Back autofocus | DW9719 lens motor | `dw9719` |
| Infrared camera | OV7251 (ACPI `INT347E`) | `ov7251` (libcamera doesn't support it) |
| Camera power | three INT3472 devices | `int3472-discrete` (GPIO-switched) |
| Apps | libcamera with the IPU3 pipeline and generic tuning | `libcamera`, `libcamera-ipa`, `pipewire-libcamera` |

All the kernel drivers come with the linux-surface kernel and the firmware with
`linux-firmware`; there are no separate driver packages.

## Notes
- Service plugins (gestures) only reload with `omarchy restart shell`.
- `tools/taplog.py` (run with sudo) logs touch events, for debugging lag.

## Pending on this machine
Built but needing sudo to install:
- `./install.sh --patches`: installs `bar-touch-lock.patch` (top bar locked in tablet mode),
  then `omarchy restart shell`.
- `sudo pacman -S squeekboard`: keyboard pops up on text fields (conflicts with fcitx5,
  which currently owns the input method).

`WRITEUP.md` tells the whole story in one place; `git log` has the reasoning behind each change. `TODO.md` lists what is planned,
starting with making this work on any x86 tablet, not only the Surface Pro 4.

