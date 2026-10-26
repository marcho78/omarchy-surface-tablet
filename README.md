# Surface Pro 4 tablet mode for Omarchy

Turns a Surface Pro 4 running [Omarchy](https://omarchy.org) (Arch Linux,
Hyprland, Limine) into a touch-first tablet: working touch, an on-screen
keyboard with suggestions and voice typing, edge gestures, a Control Center, and
a tablet mode that switches on by itself when you detach the Type Cover. With
the cover attached, the desktop stays exactly as Omarchy made it.

How each problem was found and solved, with the tests: **[WRITEUP.md](WRITEUP.md)**.
What's left: **[TODO.md](TODO.md)**.

## Install

```bash
git clone <this repo> ~/surface-tablet
~/surface-tablet/install.sh        # everything; asks for sudo; then reboot
```

| Option | Installs | Needs |
|---|---|---|
| *(none)* | everything below | sudo, reboot |
| `--home` | scripts, Hyprland config, shell plugins (symlinked into `~`) | nothing |
| `--patches` | touch fixes to Omarchy's own shell, kept across Omarchy updates | sudo |
| `--camera` | the back-camera driver fix, rebuilt for each new kernel | sudo, reboot |
| `--voice` | voice typing (Vosk for the keyboard's mic, Voxtype for Omarchy's keys) | sudo |
| `--audio` | built-in microphone fixes | sudo, reboot |

Running it again is safe: every step checks before it changes anything. Files
under `home/` are symlinks, so editing them edits this repo.

## What you get

**Touch.** The linux-surface kernel and `iptsd` touch daemon, tuned so the
cursor keeps up with your finger and fast swipes aren't cut into pieces.

**Tablet mode.** Detach the cover (or tap the tablet button in the bar):
- apps fill the screen with finger-sized title bars, or an iPad-style "•••" handle
- a taller bar with a clock, desktops and search
- sliding animations

Re-attach and everything goes back where it was.

**Gestures** (tablet mode):

| Gesture | Opens |
|---|---|
| Pull down, top right | Control Center |
| Pull down, top left | Notification Center |
| Swipe up from the bottom | App drawer |
| Bottom-right corner | Keyboard |
| Swipe in from the middle of the right edge, or long-press the desktop | Radial menu: AI, Search, Apps, Stage Control, Dock |
| Swipe in from the left or right edge | Next or previous desktop |
| Double-tap the empty desktop | The app you hid last |
| Pull down at the top centre | Leaves full screen |

**Control Center.** Wi-Fi, Bluetooth, keyboard settings, dock, window controls,
screenshot, screen recording, night light, stay awake, reminders, a Sound page
(per app, Android style), Media Center, volume and brightness.

**On-screen keyboard** (wvkbd, patched):
- US QWERTY like Gboard, with symbol pages, arrow keys and Ctrl, Alt and Omarchy keys
- held keys repeat
- word suggestions that learn your words
- a key click
- Esc, and a **mic for voice typing**: offline, typing as you speak

**Cameras.** Front and back work in Snapshot (the "Camera" app). The back
camera needed a driver fix.

**Microphones.** Fixed for dictation: one of the pair is wired inverted, the
default level clipped, and a long sleep could reset the sound chip.

## Hardware

Surface Pro 4: Intel i5-6300U, 4 GB RAM, IPTS touchscreen and pen, Realtek
ALC298 sound, Intel IPU3 cameras (front OV5693, back OV8865).

| Part | Driver | Comes from |
|---|---|---|
| Touchscreen and pen | IPTS + `iptsd` | linux-surface kernel, `iptsd` package |
| Type Cover | `surface_aggregator`, `hid-multitouch` | linux-surface kernel |
| Cameras | `ipu3-cio2`, `ipu3-imgu`, `ov5693`, `ov8865` (rebuilt), `dw9719` | linux-surface kernel; firmware from `linux-firmware` |
| Sound | `snd_hda_intel` + patch file | kernel; patch file from this repo |

The infrared camera (OV7251) isn't supported by libcamera.

## Repo layout

| Path | What it is |
|---|---|
| `install.sh` | The installer (options above) |
| `home/.local/bin/` | `tablet-mode` (switches modes), `surface-osk` (keyboard and cover watcher), `surface-osk-keys` (word suggestions), `surface-dictate` (voice typing), `tablet-open-app`, `tablet-last-app` |
| `home/.config/hypr/tablet.lua` | Tablet look, animations, workspace swipes, full screen |
| `home/.config/omarchy/plugins/devsecai.*` | Shell plugins: `gestures`, `control-center`, `notification-center`, `app-drawer`, `tablet-clock`, `tablet-status`, bar buttons (`osk`, `tablet`), and `app-switcher` (unused) |
| `home/.config/wireplumber/` | Microphone starting level (35%) |
| `system/etc/iptsd.d/` | Touch tuning |
| `system/usr/local/bin/` | `surface-omarchy-patches`, `surface-camera-fix`, `surface-audio-wake` |
| `system/usr/local/share/surface-tablet/` | The Omarchy shell patches and the camera driver patch |
| `system/etc/pacman.d/hooks/` | Re-apply the shell patches after Omarchy updates; rebuild the camera driver after kernel updates |
| `system/usr/lib/firmware/`, `system/etc/modprobe.d/` | The sound chip's patch file and the option that loads it |
| `system/etc/systemd/system/` | `surface-audio-wake.service`, which checks the sound chip after every wake |
| `packages/wvkbd/` | The on-screen keyboard: the AUR package plus four patches |
| `tools/taplog.py` | Logs touch events, for debugging |

Also used, from marcho78's own plugin repos (not copied here, with local
touch-mode changes): Stage Control (window overview), O-Spotlight (search), Uber
TV (media center).

## Known issues

- **Chromium closes while typing with Shift on the Type Cover.** Under
  investigation; the main suspect is the input-method path, which includes the
  two flags this repo adds (`--enable-wayland-ime --wayland-text-input-version=3`).
- **Mic after a long sleep.** The wake-up fix is in but hasn't yet met a real
  reset.
- **Touch in desktop mode.** Bar taps can turn into drags, and the edge swipes
  are tablet-only.
- **Front camera.** Dim, with a pink tint (no tuning file).
- **squeekboard** (keyboard that pops up on text fields) is in the installer but
  not installed here: it conflicts with fcitx5, which owns the input method.
- **Service plugins** (gestures) only reload with `omarchy restart shell`.
