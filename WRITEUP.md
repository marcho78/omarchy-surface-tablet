# Surface Pro 4 tablet setup: write-up

What has been built for the Surface Pro 4 running Omarchy (Arch, Hyprland 0.56
with Lua config, the Quickshell-based omarchy-shell, Limine), why, and what is
still open. The README lists every file; `git log` has the detail of each
change. This is the story in one place.

## 1. Touch

- **Kernel and touch daemon.** The stock kernel has no touch on this model:
  the linux-surface kernel and `iptsd` provide it. Limine's `BOOT_ORDER` puts
  the surface kernel first, or touch is dead after a reboot.
- **Lag.** iptsd's defaults ignored small and fast movements, so the cursor
  trailed the finger: `10-low-latency.conf` loosens both position thresholds.
- **Broken swipes (fixed late, and the cause of several odd bugs).** A fast
  swipe arrived as several 8-60 ms touches that jumped thousands of units
  between them. Recorded on iptsd's virtual touchscreen, the cause was iptsd
  dropping contacts whose shape was too long: a moving finger smears on the
  sensor. `20-tracking.conf` raises `AspectMax` from 2.5 to 4; swipes now come
  through as single contacts. This was behind pull-downs that rarely opened,
  and behind taps at the top corner that typed "i press c i press c": the
  pieces of a broken swipe landed on the keyboard's suggestion strip and
  accepted suggestions over and over.

## 2. Tablet mode

`tablet-mode on|off` switches between the normal desktop and a tablet layout.
It follows the Type Cover (detached: tablet; attached: desktop) and can be
switched by hand from the bar.

- **Layout.** Apps fill the screen between the bar and the dock, keeping
  their title bars (bigger buttons); workspaces float so the dock shows;
  windows go back where they were on the desktop afterwards.
- **Look and motion.** Larger text, a taller bar, sliding workspaces, springy
  app opening, the keyboard sliding up.
- **Tablet bar.** Clock, workspaces, a search icon beside them, and a status
  pill. Built fresh on each switch; the desktop bar comes back afterwards.
- **Plugins across the switch.** Stage Control, O-Spotlight and Uber TV only
  run while their entries are in the bar and keep their settings there, so
  tablet mode carries the entries over (icons hidden or moved) and brings
  settings changed in tablet mode back to the desktop. Omarchy only hands
  plugins their bar settings when its plugin list changes, so the plugins are
  reloaded after each switch.
- **Bar lock (Omarchy patch).** Omarchy's bar turns any press that moves a few
  pixels into a drag that rearranges it; a finger always moves a little, so
  taps were lost and icons ended up out of reach. In tablet mode the bar is
  locked (`bar-touch-lock.patch`).

## 3. Gestures (tablet mode)

- **Top edge.** Pull down on the left for the Notification Center, on the
  right for the Control Center (the bar is for reading, not tapping).
- **Bottom edge:** swipe up for the app drawer; the bottom-right corner is the
  on-screen keyboard.
- **Radial menu**, from a short inward swipe at the middle of the right edge
  (works over any app) or a long press on empty desktop: AI (your default
  agent), Search, Apps, Stage Control and Dock around the finger, chosen by
  direction. It replaced a bottom-swipe menu chosen by how far you swiped,
  which kept being hard to aim (even with a step-down rule on the way back).
- **Workspaces:** swipe from the left or right edge (desktop too), or three
  fingers on the touchpad.
- **Screensaver.** Omarchy's screensaver closes only on a key press; in tablet
  mode a tap anywhere now closes it.

## 4. Panels and apps (tablet mode)

- **Control Center:** Wi-Fi, Bluetooth, keyboard (and its settings page),
  dock always-show / auto-hide, screenshot, screen recording, night light,
  stay awake, reminders (a touch page), back to desktop, a Sound page
  (Android style: system, microphone, each app, output and input devices),
  Media Center for Uber TV, volume and brightness.
- **Notification Center:** Omarchy's notification history grouped by app,
  slide to dismiss, Clear All, Do Not Disturb, frosted glass behind it.
- **App drawer:** every app as large icons with a row of recent ones; searches
  apps only. It used to take the keyboard exclusively, which made Hyprland send
  every touch to it: tapping "c" on the on-screen keyboard opened the app under
  the key. It now takes the keyboard on demand.
- **Stage Control** (marcho78's plugin): overview of every window and desktop,
  with a touch mode (bar open, titles and close buttons always shown, long
  press to rename).
- **O-Spotlight** (marcho78's plugin): search for apps, Omarchy actions,
  files and maths, in 12 styles; touch mode opens the keyboard with it and fits
  it above the keyboard in every style.
- **Uber TV** (marcho78's media center): enabled, with a play icon on the
  desktop bar (a TV looked like the display and laptop icons) and the Control
  Center tile in tablet mode.

## 5. On-screen keyboard

wvkbd, packaged in `packages/wvkbd` with patches:

- standard US QWERTY like Gboard, with ?123 and =\< pages, a number-row
  variant, a centred space bar, arrows in an inverted T, and Ctrl, Alt and the
  Omarchy (Super) key for Omarchy's shortcuts;
- held keys repeat, tapped keys stay lit long enough to see, a magnified
  preview above the key;
- a soft click per key (there is no vibration motor).

Around it: a Gboard-style strip above the keys with Esc, three word
suggestions (from fcitx5's English dictionary, learning your words), a mic,
and the hide button; settings (layout, height, click, suggestions) on the
Control Center's Keyboard page; English plus your system language.

## 6. Voice typing

The keyboard's mic types as you speak with Vosk through `nerd-dictation`
(offline, lowercase, no punctuation). Omarchy's own dictation keys use Voxtype
(Whisper: accurate, with punctuation, types once you stop). Live Whisper was
tried and dropped: on this i5-6300U each pass took about 4 s against the
0.8 s it needs. `--continuous` was dropped too: it ran phrases together.

## 7. Cameras

Front (OV5693) and back (OV8865) work through libcamera and PipeWire; the
infrared camera isn't supported. The back camera came out black: its black
level target was the sensor's default 16 while libcamera's IPU3 processing
takes 64 off every pixel. `surface-camera-fix` rebuilds the OV8865 driver
with the target at 64, and a pacman hook rebuilds it for each new kernel.
Snapshot is the camera app; Monologue can't see the cameras (Qt only opens
plain V4L2 webcams).

## 8. Kept across updates

- Omarchy updates: `surface-omarchy-patches` re-applies the shell patches
  (bar lock, dock, theme picker sliding) through a pacman hook; a patch that
  no longer fits is skipped and reported.
- Kernel updates: `surface-camera-fix` rebuilds the camera driver.
- Everything else lives in this repo, symlinked into `$HOME`;
  `./install.sh` (or `--home`, `--patches`, `--camera`, `--voice`) sets it up.

## 9. Open items

- Window controls in tablet mode (next): a setting for title bars or an
  iPad-style handle; the title bar's maximize button fights tablet mode's
  fitting (first press snaps back, second leaves a maximized window with no
  title bar and no way out without a keyboard).

- Touch in desktop mode: bar taps still turn into drags there (the lock is
  tablet-only), and the edge swipes are tablet-only.
- The front camera's picture is dim with a pink tint (no tuning file).
- Combos on the on-screen keyboard (reported, not yet looked into).
- Keyboard theming, including a coloured Omarchy key: planned.
- `devsecai.app-switcher` is unused since Stage Control replaced it.
- The learned suggestion pairs inflated by the junk text (i -> press -> c).
- Uber TV: the icon and `barIcon` change in its own repo are uncommitted; its
  log shows `Model size of -2 is less than 0` when it opens.
- Running on other x86 tablets: see `TODO.md`.
