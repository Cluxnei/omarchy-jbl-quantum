#!/usr/bin/env python3
"""Poll all feature reports every 0.5s and print what changes, plus input reports.

Usage: tools/watch.py /dev/hidrawN seconds   (then toggle things on the headset)
"""
import fcntl, os, select, sys, time

DEV, DUR = sys.argv[1], float(sys.argv[2])
FEATURES = {0x05: 30, 0x0d: 1, 0x47: 1, 0x48: 16, 0x54: 63, 0x49: 1, 0x50: 2,
            0x51: 12, 0x52: 2, 0x53: 1, 0x72: 63, 0x55: 5, 0x57: 1, 0x58: 3,
            0x59: 1, 0x5a: 16, 0x5b: 63, 0x5c: 1, 0x5d: 1, 0x60: 1, 0x61: 16,
            0x62: 1, 0x67: 1, 0x68: 1, 0x70: 63, 0x71: 63, 0x74: 63, 0x75: 1, 0xf0: 8}

def ioc(n): return (3 << 30) | (n << 16) | (ord('H') << 8) | 0x07

fd = os.open(DEV, os.O_RDWR | os.O_NONBLOCK)
last = {}
end = time.time() + DUR
print("started", flush=True)
while time.time() < end:
    for rid, size in FEATURES.items():
        buf = bytearray([rid] + [0] * size)
        try:
            fcntl.ioctl(fd, ioc(len(buf)), buf)
            v = bytes(buf[1:]).rstrip(b"\0").hex(" ")
        except OSError as e:
            v = "ERR " + e.strerror
        if last.get(rid) != v:
            if rid in last:
                print(f"{time.strftime('%H:%M:%S')} feat 0x{rid:02x}: {last[rid]!r} -> {v!r}", flush=True)
            last[rid] = v
    while select.select([fd], [], [], 0)[0]:
        print(f"{time.strftime('%H:%M:%S')} in: {os.read(fd, 64).hex(' ')}", flush=True)
    time.sleep(0.5)
print("done")
