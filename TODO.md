# To do

## Make it work on any x86 tablet, not only the Surface Pro 4

Most of this repo is hardware-neutral: tablet mode, the shell plugins (Control
Center, Notification Center, app drawer, app switcher, edge swipes), workspace
swipes and the whole on-screen keyboard work on any x86 touchscreen running
Omarchy. What ties it to the Surface Pro 4, and what to change:

- [ ] **Installer: Surface steps only on a Surface.** Detect the hardware
  (`/sys/class/dmi/id/sys_vendor` is `Microsoft Corporation` and
  `product_name` starts with `Surface`) and only then add the linux-surface
  repo and key, install `linux-surface`, `linux-surface-headers` and `iptsd`,
  set Limine's `BOOT_ORDER`, and install the iptsd low-latency config. On other
  tablets the stock kernel's HID multitouch driver usually handles touch, and
  making the Surface kernel the default would be wrong.

- [ ] **Automatic tablet mode on other hardware.** `surface-osk` switches on
  the Type Cover appearing or disappearing
  (`/dev/input/by-id/usb-Microsoft_Surface_Type_Cover-event-kbd`).
  - Convertibles (Lenovo Yoga, HP x360, ...) report a tablet-mode switch
    (`SW_TABLET_MODE`, shown by `libinput debug-events` as
    `SWITCH_TOGGLE tablet-mode`). Hyprland can bind switch events by name, as
    Omarchy already does for the lid (`switch:on:Lid Switch`), so tablet mode
    could follow `switch:on:<device>` / `switch:off:<device>`.
  - Other detachables have their own keyboard device: make the device name a
    setting, found automatically where possible.
  - The Surface Pro 4 has no tablet-mode switch (only `Lid Switch`), so keep
    the Type Cover check as its default.

- [ ] **Swipe strips on the built-in screen.** `devsecai.gestures` uses
  `Quickshell.screens[0]`. With an external monitor attached that may be the
  wrong one: prefer the built-in panel (`eDP-*`).

- [ ] **Keyboard size from the screen.** wvkbd's heights are fixed logical
  pixels (300 landscape / 400 portrait, Small/Medium/Large around them), tuned
  for the Surface Pro 4's 12.3" 3:2 screen at scale 2. Derive the default from
  the screen's physical size so it suits 8" and 13" tablets alike.

- [ ] **Auto-rotation.** Not built. Needs `iio-sensor-proxy` (`monitor-sensor`)
  driving the monitor transform and the touchscreen's input transform, wvkbd's
  portrait layout, and tablet mode re-fitting apps after each turn.

- [ ] **Note on budget tablets.** Some cheap x86 tablets (Atom with Silead or
  Goodix touch controllers) need touchscreen firmware or DMI quirks before
  touch works at all. That is driver work outside this repo, but worth a line
  in the README for anyone trying it.

- [ ] **README.** Say up front which parts are Surface-only and which work on
  any Omarchy tablet.
