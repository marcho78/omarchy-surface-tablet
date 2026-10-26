# Surface Pro 4 tablet mode for Omarchy

![Device: Surface Pro 4](https://img.shields.io/badge/device-Surface%20Pro%204-0078D4)
![OS: Omarchy](https://img.shields.io/badge/Omarchy-Arch%20%2B%20Hyprland-1793D1)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Turns a Surface Pro 4 running [Omarchy](https://omarchy.org) (Arch Linux,
Hyprland, Limine) into a touch-first tablet: working touch, an on-screen
keyboard with suggestions and voice typing, edge gestures, a Control Center, and
a tablet mode that switches on by itself when you detach the Type Cover. With
the cover attached, the desktop stays exactly as Omarchy made it.

How each problem was found and solved, with the tests: **[WRITEUP.md](WRITEUP.md)**.
What's left: **[TODO.md](TODO.md)**.

## Install

```bash
git clone https://github.com/marcho78/omarchy-surface-tablet.git ~/surface-tablet
~/surface-tablet/install.sh        # everything; asks for sudo; then reboot
```

Keep the folder where you cloned it: your home files become links into it.

| Option | Installs | Needs |
|---|---|---|
| *(none)* | everything below | sudo, reboot |
| `--home` | scripts, Hyprland config, shell plugins (symlinked into `~`) | nothing |
| `--patches` | touch fixes to Omarchy's own shell, kept across Omarchy updates | sudo |
| `--camera` | the back-camera driver fix, rebuilt for each new kernel | sudo, reboot |
| `--voice` | voice typing (Vosk for the keyboard's mic, Voxtype for Omarchy's keys) | sudo, `yay` (AUR) |
| `--audio` | built-in microphone fixes | sudo, reboot |

Running it again is safe: every step checks before it changes anything. The
full install also runs a system upgrade (`pacman -Syu`). Files under `home/` are
symlinks, so editing them edits this repo.

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
| Swipe up from the bottom-right corner | Keyboard on or off |
| Swipe in from the middle of the right edge, or long-press the desktop | Radial menu: AI, Search, Apps, Stage Control, Dock |
| Swipe in from the left edge, or the right edge away from its middle | Next or previous desktop (desktop mode too) |
| Double-tap the empty desktop | The app you hid last |
| Pull down at the top centre, while an app is full screen | Leaves full screen |

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

**Microphones.** Fixed for dictation: one of the pair is wired inverted, and the
default level clipped. A long sleep can also reset the sound chip; a check after
every wake restores it (not yet tested on a real reset).

## Hardware

Surface Pro 4: Intel i5-6300U, 4 GB RAM, IPTS touchscreen and pen, Realtek
ALC298 sound, Intel IPU3 cameras (front OV5693, back OV8865).

| Part | Driver | Comes from |
|---|---|---|
| Touchscreen and pen | IPTS + `iptsd` | linux-surface kernel, `iptsd` package |
| Type Cover | `hid-multitouch` (it's a USB keyboard and touchpad) | kernel |
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

## Plugins used

Three Omarchy shell plugins of my own, each in its own repo (not copied here).
Install with `omarchy plugin add <repo URL>`. What we changed in them for
tablet mode is in [WRITEUP.md](WRITEUP.md#10-plugins-used).

| Plugin | What it does | Repo |
|---|---|---|
| **Stage Control** | Overview of every window and desktop, with live previews | [marcho78/omarchy-stage-control](https://github.com/marcho78/omarchy-stage-control) |
| **O-Spotlight** | Spotlight-style search: apps, Omarchy actions and settings, files, maths; 12 themes | [marcho78/o-spotlight](https://github.com/marcho78/o-spotlight) |
| **Uber TV** | Media center: YouTube, IPTV with a guide, on-demand videos, apps | [marcho78/uber-tv](https://github.com/marcho78/uber-tv) |

## Known issues

- **Chromium closes while typing with Shift on the Type Cover.** Under
  investigation; the main suspect is the input-method path, which includes the
  two flags this repo adds (`--enable-wayland-ime --wayland-text-input-version=3`).
- **Mic after a long sleep.** The wake-up fix is in but hasn't yet met a real
  reset.
- **Touch in desktop mode.** Bar taps can turn into drags, and the pull-downs,
  bottom swipe and radial menu are tablet-only (desktop swipes work in both).
- **Front camera.** Dim, with a pink tint (no tuning file).
- **squeekboard** (keyboard that pops up on text fields) is in the installer but
  not installed here: it conflicts with fcitx5, which owns the input method.
- **Service plugins** (gestures) only reload with `omarchy restart shell`.

## Credits

- [linux-surface](https://github.com/linux-surface/linux-surface): the kernel and `iptsd` that make the Surface's hardware work
- [wvkbd](https://git.sr.ht/~proycon/wvkbd): the on-screen keyboard patched here
- [Vosk](https://alphacephei.com/vosk/) and [nerd-dictation](https://github.com/ideasman42/nerd-dictation): offline voice typing
- [Omarchy](https://omarchy.org): the desktop this builds on

## License

[MIT](LICENSE). Patches to other projects keep their project's license: the
wvkbd patches are GPL-3.0, the kernel camera patch GPL-2.0-only.
