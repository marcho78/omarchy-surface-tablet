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

## 9. Window controls (tablet mode)

- **Full screen.** The title bar's square button gives real full screen; a pill
  at the top centre (pull down or tap) leaves it.
- **Title bars or a handle.** The Control Center's Windows tile chooses: Omarchy's
  title bars, or an iPad-style "•••" handle above the app in front with Full
  screen, Hide and Close. Title bars are built for a mouse; on the Type Cover's
  touchpad, taps that move a little are dropped by libinput, which is why the
  buttons felt hit-or-miss.
- **Hidden apps.** Hiding (minimizing) an app used to leave no way back by touch.
  Now Stage Control shows hidden apps in touch mode (tap to bring one back), the
  app drawer brings back a hidden copy instead of opening a second one, the
  handle says where hidden apps live, and a **double tap on the empty desktop**
  brings back the app hidden last.
- **Bugs found and fixed on the way:**
  - The handle showed for a hidden app: Hyprland keeps a hidden app as the
    active window when nothing else is on screen. The handle now ignores apps
    on hidden workspaces.
  - No handle on an app back from hiding or from full screen: the handle
    depended on a marker tablet mode adds when it fits an app to the screen,
    and those apps were never fitted. Apps are now fitted on those events too,
    and the handle no longer needs the marker.
  - The double tap didn't work: Qt's built-in double click only counts a
    second tap a few pixels from the first. It is now counted by hand (second
    tap within 0.4 s and 80 px), the moment the second finger lands.
- **Tested** by sending finger touches into the touchscreen device (the same
  path a real finger takes), after a long press opening the radial menu proved
  the touches arrive: double taps at 0, 20, 40 and 70 px apart and with a
  0.3 s gap bring the app back (focused, handle showing); taps 0.7 s or 150 px
  apart, and single taps, do nothing; long press still opens the menu.

## 10. The black screen (a mistake of mine)

During that testing the screen went black and stayed black until the cover
was detached. The cause was not tablet mode: an earlier command of mine, which
was interrupted, had already stopped the Omarchy shell (wallpaper, bar, dock,
gestures) and never started it again, and my checks said it was running
because `pgrep -f omarchy-shell` matched my own command line. On an empty
desktop with no shell, the screen is pure black. The shell was restarted; the
reliable checks are `quickshell list` and `omarchy-shell shell ping`, and shell
restarts now run detached so an interrupt can't cut them in half.

## 11. Voice typing stopped working: the microphones

Three separate problems, found in this order. Everything was measured; the
tests are described with each.

1. **The sound chip lost its setup.** The built-in mic recorded loud noise that
   didn't change with the volume (-9 dBFS of "silence" even at +10 dB; a real
   mic reads about -60). Its pin configuration read "not connected" where the
   firmware sets "internal digital mic": after boot the chip (Realtek ALC298)
   had been reset to its power-on state, losing the setup the firmware gives
   it at boot. A reboot fixed it. Saving the chip's full state (pins, vendor
   coefficients, GPIOs) before and after the reboot showed 7 pin settings and
   17 vendor settings differ. Before that reboot the Surface had suspended four
   times (7 h, 80 s, 3 h, 10 s); since then a 4.5-minute suspend and a
   hibernate both left the chip intact (hibernate runs the firmware again). So
   a long suspend most likely causes it; not proven yet.
2. **The level clipped.** After the reboot the mic worked but words came out
   wrong. PipeWire gives a mic with no saved setting 100%, which on this chip
   maxes both gain stages (+60 dB): room sound alone sat at -6 dBFS and
   clipped. A sweep of seven levels showed the noise now followed the volume,
   as a working mic's should. 35% (+30 dB, no boost) is now the saved level and,
   through a WirePlumber rule, the starting level if the saving is ever lost
   (tested by removing the saved setting and restarting WirePlumber).
3. **One mic of the pair is inverted.** Recorded in stereo, the two mics move
   in opposite directions (correlation -0.96 at low frequencies); mixed to
   mono, as dictation records, the voice cancels (about 12 dB lost). The sound
   driver has a standard fix: the hint `inv_dmic_split` gives the inverted mic
   a switch of its own, off. Tested live first (driver reconfigured with
   PipeWire stopped): the inverted channel went silent. Then dictation was
   accurate in long sentences with a loud TV on. Made permanent with a driver
   patch file matched to this chip only, and confirmed after a reboot.

Then **the wake-up fix** for problem 1: `surface-audio-wake.service` runs after
every wake. If the internal mic pin reads "not connected" (the reset's
fingerprint) it saves a copy of the reset state and writes the firmware's
settings back (only those that differ), logging what it did. Tested on a normal
wake (does nothing) and on a simulated reset (the marker set by hand: detected,
restored). A real long sleep is still to come.

Downloaded and installed for this: `alsa-tools` (for `hda-verb`, to read and
write the chip's settings). Files: the driver patch file and modprobe option,
the WirePlumber rule, `surface-audio-wake` and its service, all in this repo
and installed by `./install.sh --audio` (the rule comes with `--home`).

Along the way:
- My first plan (just lower the volume) rested on a wrong assumption: the mic
  then was broken, not too loud. The level sweep showed it.
- A test that wrote the "after-reset" vendor settings back into the working
  chip didn't reproduce the fault (the mic went silent instead), and cleared
  two bits the chip sets itself, which writes can't restore. A reboot did.
- Two recorded speech tests gave nothing useful: they depended on reading a
  sentence at the right moment, with a TV on. Dictating for real was the test
  that counted.
- `sudo` asked for a password right after both reboots, though passwordless sudo
  is set up (until Oct 26, 17:52); it worked again a little later.
- PipeWire logs "RTKit error" at every start: RTKit isn't installed. It has been
  there since boot, unrelated.

## 12. Open items

- The microphone after a long sleep: the wake-up fix is in, but untested on a
  real reset. Fallback if it isn't enough: turn long suspends into hibernate
  (suspend-then-hibernate), which keeps the mic working.
- Stage Control's hidden-apps change is in marcho78's own plugin repo,
  uncommitted.
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
