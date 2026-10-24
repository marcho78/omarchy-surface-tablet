#!/usr/bin/env python3
# Log touch down/up events from the touchscreen devices for 15 seconds.
import glob, os, select, struct, time

def find(name):
    for d in glob.glob("/sys/class/input/event*"):
        try:
            if open(d + "/device/name").read().strip() == name:
                return "/dev/input/" + os.path.basename(d)
        except OSError:
            pass

DEVICES = {find("IPTS 1B96:006A Touchscreen"): "kernel-ipts",
           find("IPTSD Virtual Touchscreen 1B96:006A"): "iptsd-virtual"}
FMT = "llHHi"
SIZE = struct.calcsize(FMT)
EV_KEY, BTN_TOUCH = 0x01, 0x14a

fds = {os.open(p, os.O_RDONLY | os.O_NONBLOCK): n for p, n in DEVICES.items() if p}
counts = {n: 0 for n in fds.values()}
down_at = {}
end = time.time() + 15
print("Tap the screen normally for 15 seconds...", flush=True)

while time.time() < end:
    r, _, _ = select.select(list(fds), [], [], 0.5)
    for fd in r:
        data = os.read(fd, SIZE * 64)
        for i in range(0, len(data) - SIZE + 1, SIZE):
            sec, usec, typ, code, val = struct.unpack(FMT, data[i:i + SIZE])
            name = fds[fd]
            counts[name] += 1
            if typ == EV_KEY and code == BTN_TOUCH:
                t = sec + usec / 1e6
                if val:
                    down_at[name] = t
                    print(f"{t:.3f} {name:14} DOWN", flush=True)
                else:
                    held = (t - down_at.get(name, t)) * 1000
                    print(f"{t:.3f} {name:14} UP   (held {held:.0f} ms)", flush=True)

print("event counts:", counts)
