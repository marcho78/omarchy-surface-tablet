# How we did it

Every problem below follows the same four steps: **Problem → Cause → Fix →
Test.** The cause is what the evidence showed, not a guess; where something is
still unproven, it says so. File names point into this repo; `git log` has the
detail of each change.

Machine: Surface Pro 4 (i5-6300U, 4 GB RAM) on Omarchy: Arch Linux, Hyprland
0.56 with Lua config, the Quickshell-based omarchy-shell, Limine.

---

## 1. Touch

### No touch at all
- **Cause.** The stock Arch kernel has no driver for the Surface's touchscreen (IPTS).
- **Fix.**
  - The [linux-surface](https://github.com/linux-surface/linux-surface) kernel, plus `iptsd`, the daemon that turns the raw sensor data into touches.
  - Limine's `BOOT_ORDER` puts the surface kernel first; otherwise a reboot lands on the stock kernel and touch is dead again.
- **Test.** Touch works after every reboot.

### The cursor trailed the finger
- **Cause.** iptsd ignores movements under 0.4 mm and over 2 cm by default
  (`PositionThresholdMin` / `Max` in `/etc/iptsd.conf`).
- **Fix.** `system/etc/iptsd.d/10-low-latency.conf` sets them to 0.2 mm and 10 cm.

### Swipes broke into pieces, and taps typed junk
- **Problem.** Pull-downs rarely opened. Tapping a top corner typed "i press c i press c" into the open app.
- **Cause.**
  - We recorded the raw events from iptsd's virtual touchscreen: one fast swipe arrived as several touches of 8–60 ms that jumped across the screen.
  - A moving finger smears into a longer blob on the sensor, and iptsd dropped blobs longer than its `AspectMax` of 2.5.
  - The pieces then landed as taps, for example on the keyboard's word suggestions, accepting them over and over.
- **Fix.** `system/etc/iptsd.d/20-tracking.conf` raises `AspectMax` to 4.
- **Test.** Recorded again: the same swipes came through as single touches
  (340–3000 ms), and 5 of 6 pull-downs fired.

---

## 2. Tablet mode

- **Goal.** Detach the Type Cover and get a tablet; attach it and get the unchanged desktop back.
- **How.**
  - `surface-osk` watches for the cover and runs `tablet-mode on|off`.
  - The tablet bar, finger-sized title bars, apps fitted between the bar and the dock, and sliding animations.
  - Each window's desktop position is saved and restored afterwards.

### Problems found on the way

| Problem | Cause | Fix |
|---|---|---|
| Plugins lost their settings after a mode switch | Omarchy hands plugins their bar settings only when its plugin list changes | Reload the plugins after each switch (`omarchy-shell shell rescanPlugins`) |
| Bar icons moved when tapped, and ended up out of reach | Omarchy turns any press that moves a few pixels into a drag, and a finger always moves a little | `bar-touch-lock.patch` locks the bar in tablet mode; a pacman hook re-applies it after Omarchy updates |
| Tapping "c" on the keyboard opened an app | The app drawer took the keyboard *exclusively*, so Hyprland sent every touch to it, including taps on the on-screen keyboard | The drawer takes the keyboard on demand |
| The screensaver couldn't be closed by touch | It only closes on a key press | A tap anywhere closes it |

---

## 3. Gestures and panels

- **What.** Shell plugins draw thin invisible strips on the screen edges:
  - pull-downs for the Control Center and the Notification Center
  - swipe up for the app drawer
  - a radial menu from the right edge or a long press: AI, Search, Apps, Stage Control, Dock
- **Design change.** An earlier menu, chosen by how far you swiped up, was hard to aim; choosing by direction replaced it.
- **AI** opens the user's own default agent (`omarchy-agent --pick`), whatever it is.

---

## 4. On-screen keyboard

- **wvkbd** (AUR) with four patches in `packages/wvkbd/`:
  - held keys repeat
  - a tapped key stays lit long enough to see
  - a magnified key preview
  - standard US QWERTY layouts like Gboard's, with Ctrl, Alt and the Omarchy key
- **Word suggestions.** `surface-osk-keys` completes words from fcitx5's English dictionary and learns yours.
- **Key click** instead of vibration, since the Surface has no vibration motor.

---

## 5. Voice typing

- **Goal.** A mic on the keyboard that types *while* you speak.
- **Tried first: live Whisper.** Too slow: on this CPU each pass took 3.5–4 s against the 0.8 s it needs, so it fell behind and stuck.
- **Fix.** Vosk, through `nerd-dictation`: offline, types as you speak (`home/.local/bin/surface-dictate`). Omarchy's own dictation keys keep Voxtype (Whisper), which is more accurate and has punctuation but types once you stop.
- **Problem: phrases ran together with no spaces.** Cause: `--continuous` mode types each phrase without a leading space. Fix: dropped `--continuous`.

---

## 6. Cameras

### The back camera was black
- **Cause.**
  - The OV8865 sensor's black level target defaults to 16.
  - libcamera's IPU3 processing subtracts 64 from every pixel.
  - So everything darker than 64 came out black.
- **Fix.** `surface-camera-fix` rebuilds the OV8865 driver from linux-surface's source with the target at 64, into `/usr/lib/modules/<kernel>/updates/`, so no package files are touched. A pacman hook rebuilds it for every new kernel.
- **Test.** Both cameras take photos and video in Snapshot.

### Monologue can't use the cameras
- **Cause.** Qt only opens plain webcams (V4L2), and these cameras work only through libcamera.
- **Fix.** None: Snapshot is the camera app.

---

## 7. Window controls and hidden apps

- **Problem.** Title bars are built for a mouse:
  - On the Type Cover's touchpad, libinput drops taps that move a little, so title-bar buttons felt hit-or-miss.
  - In tablet mode, a hidden (minimized) app had no way back by touch.
- **Fix.**
  - A Control Center setting picks title bars or an iPad-style "•••" handle (Full screen, Hide, Close).
  - Hidden apps show in Stage Control, and the app drawer brings back the hidden copy instead of opening a second one.
  - A double tap on the empty desktop brings back the app hidden last.

### Bugs found on the way

| Problem | Cause | Fix |
|---|---|---|
| The handle showed with nothing on screen | Hyprland keeps a hidden app as the "active window" | The handle ignores apps on hidden workspaces |
| No handle on an app back from hiding or from full screen | The handle relied on a marker set when tablet mode fits an app, and those apps were never fitted | Fit apps on those events too, and drop the marker |
| Double tap did nothing | Not proven. The first version used Qt's built-in double click, which is strict about how close the two taps land | Counted by hand: second tap within 0.4 s and 80 px |

### Test
We sent finger touches into the touchscreen device, the same path a real
finger takes.
- **Proof the touches arrive:** a long press opens the radial menu.
- **Should bring the app back,** and did, focused with the handle showing: double taps 0, 20, 40 and 70 px apart, and with a 0.3 s gap.
- **Should do nothing,** and didn't: taps 0.7 s apart, taps 150 px apart, a single tap.

---

## 8. Microphones (voice typing stopped working)

Three separate problems, found in this order.

### 8.1 The sound chip lost its setup
- **Problem.** The mic recorded loud noise that didn't change with the volume:
  −9 dBFS of "silence" at +10 dB gain. After the fix, the same gain read −50 dBFS.
- **Cause.**
  - The internal-mic pin read "not connected", where the firmware sets "internal digital mic".
  - The sound chip (Realtek ALC298) had been reset to its power-on state, losing the setup the firmware gives it at boot.
  - Before that, the Surface had suspended four times: 7 h, 80 s, 3 h and 10 s.
  - Since then, a 4½-minute suspend and a hibernate left the chip intact. Hibernate runs the firmware again.
  - **Most likely a long suspend; not proven yet.**
- **Evidence.** We saved the chip's full state before and after a reboot (`hda-verb` from `alsa-tools`). 7 pin settings and 17 vendor settings differ.
- **Fix.** `surface-audio-wake.service` runs after every wake:
  - If the mic pin reads "not connected" (the reset's fingerprint), it keeps a copy of the reset state and writes back the firmware's settings that differ, then logs it (`journalctl -t surface-audio-wake`).
  - Otherwise it does nothing.
- **Test.**
  - Normal wake: it does nothing.
  - Simulated reset, with only the marker set by hand: detected, marker
    restored. The vendor settings already matched, so this didn't exercise
    writing them; writing them with `hda-verb` was tested separately.
  - **Still to come:** a real long sleep.

### 8.2 The level clipped
- **Problem.** After a reboot the mic worked, but dictation got almost every word wrong.
- **Cause.**
  - A mic with no saved setting gets 100%.
  - On this chip that maxes both gain stages (+60 dB), so room sound alone reached −6 dBFS and clipped.
  - A sweep of seven levels showed the noise now followed the volume, as a working mic's should.
- **Fix.** 35% (+30 dB, no boost), saved by PipeWire. A WirePlumber rule (`home/.config/wireplumber/`) also makes 35% the starting level if the saved setting is ever lost.
- **Test.**
  - A full dictated sentence came out correct at 35%.
  - We removed the saved setting and restarted WirePlumber: the mic came back at 35%.

### 8.3 One mic of the pair is inverted
- **Problem.** Found by measuring, while dictation already worked at 35%.
- **Cause.**
  - Recorded in stereo, the two mics move in opposite directions: correlation −0.96 at low frequencies.
  - Mixed to mono, as dictation records, the voice cancels: about 12 dB is lost.
- **Fix.** The sound driver's standard fix for this wiring: the hint `inv_dmic_split` gives the inverted mic its own switch, which is off. It's applied by a patch file matched to this chip only (`system/usr/lib/firmware/surface-tablet/surface-pro-4-hda.fw`), loaded through `system/etc/modprobe.d/surface-audio.conf`.
- **Test.**
  - Tried live first: the driver was reconfigured with PipeWire stopped, and the inverted channel went silent.
  - Then dictation was accurate in long sentences with a loud TV on.
  - Confirmed after a reboot.

---

## 9. Mistakes worth knowing about

- **A black screen.**
  - An interrupted command had already stopped the Omarchy shell (wallpaper, bar, gestures) and never restarted it. On an empty desktop with no shell, the screen is black.
  - The checks said the shell was running because `pgrep -f omarchy-shell` matched the checking command itself.
  - Now: check with `quickshell list` and `omarchy-shell shell ping`, and run shell restarts detached so an interrupt can't cut them in half.
- **A wrong first plan for the mic.** "Just lower the volume" assumed the mic was too loud, when it was broken. The level sweep showed it.
- **A test that changed the chip.** Writing the "after-reset" settings into the working chip didn't reproduce the fault. It also cleared two bits the chip sets itself, which a reboot restored.
- **A claim made before checking.** These docs said two plugins' commits weren't
  on GitHub before GitHub was checked. Checked afterwards with
  `git ls-remote`: it was true, but it was stated before it was known.
- **Recorded speech tests.** They depended on reading a sentence at the right moment, with a TV on. Dictating for real was the test that counted.

---

## 10. Plugins used

Three of my own Omarchy shell plugins, each in its own repo. Tablet mode needed
touch versions of them: no hover, bigger targets, and the on-screen keyboard.
Stage Control and O-Spotlight read `~/.local/state/tablet-mode/state`, so
they switch along with tablet mode; Uber TV follows its bar entry instead. Tablet mode also carries their bar entries and settings across, and
reloads them after each switch (section 2).

### Stage Control: [marcho78/omarchy-stage-control](https://github.com/marcho78/omarchy-stage-control)
- **What it is.** An overview of every window and desktop, with live previews.
- **How it opens.** Super+D docked; from the radial menu in tablet mode.
- **What we changed.**
  - A touch mode: the desktops bar stays open, window titles and close buttons always show and are bigger, and you long-press a desktop to rename it.
  - Hidden (minimized) apps show in touch mode; tap one to bring it back (section 7).

### O-Spotlight: [marcho78/o-spotlight](https://github.com/marcho78/o-spotlight)
- **What it is.** Spotlight-style search for apps, Omarchy actions and settings, files and maths, in 12 themes.
- **How it opens.** Alt+Space docked; the search icon in the middle of the tablet bar, or Search in the radial menu.
- **What we changed.** A touch mode:
  - the on-screen keyboard opens and closes with it
  - the search fits above the keyboard in every theme
  - no hover-only controls or shortcut hints
  - long-press the magnifying glass for settings

### Uber TV: [marcho78/uber-tv](https://github.com/marcho78/uber-tv)
- **What it is.** A media center: YouTube, IPTV with a guide, on-demand videos and apps.
- **How it opens.** Super+Alt+T or its bar button docked; Media Center in the Control Center in tablet mode.
- **What we changed.**
  - The bar button is a play icon, so it doesn't look like the display and laptop icons.
  - It hides when its bar entry has `"barIcon": false`, which the tablet bar sets.

### State of those changes
| Repo | Committed but not pushed | Not committed |
|---|---|---|
| Stage Control | touch mode (1 commit) | hidden apps in touch mode (`Overview.qml`) |
| O-Spotlight | touch mode (1 commit) | — |
| Uber TV | — | play icon and `barIcon` (`BarWidget.qml`) |

---

## 11. Everything installed

| What | From | Why |
|---|---|---|
| `linux-surface`, `linux-surface-headers` | linux-surface repo (added with its signing key) | Touch, Type Cover, cameras |
| `iptsd` | linux-surface repo | Touch daemon |
| `wvkbd` | AUR, built from `packages/wvkbd` with our patches | On-screen keyboard |
| `squeekboard` | Arch | Pop-up keyboard (in the installer; not installed on this machine, see README) |
| `libcamera`, `libcamera-ipa`, `libcamera-tools`, `pipewire-libcamera` | Arch | Cameras |
| `snapshot` | Arch | Camera app |
| `gst-libav`, `gst-plugins-bad`, `gst-plugins-ugly`, `qt6-multimedia-gstreamer` | Arch | Tried so Monologue could see the cameras; it didn't help. Not in `install.sh` |
| `voxtype-bin` | Omarchy's package repo | Omarchy's dictation keys |
| `wtype`, `python-vosk` (with `vosk-api`), `unzip` | Arch | Voice typing on the keyboard |
| `nerd-dictation-git` | AUR | Voice typing on the keyboard |
| `vosk-model-small-en-us-0.15` | alphacephei.com | Speech model, in `~/.local/share/vosk/` |
| `alsa-tools` (`hda-verb`) | Arch | Read and write the sound chip's settings |
