#!/usr/bin/env python3
"""Dump every feature report of a hidraw device, then print input reports as they arrive.

Usage: tools/probe.py /dev/hidrawN [listen_seconds]
"""
import fcntl, os, select, sys, time

DEV = sys.argv[1] if len(sys.argv) > 1 else "/dev/hidraw0"
LISTEN = float(sys.argv[2]) if len(sys.argv) > 2 else 10

# feature report id -> payload size, from the report descriptor
FEATURES = {0x05: 30, 0x0d: 1, 0x47: 1, 0x48: 16, 0x54: 63, 0x49: 1, 0x50: 2,
            0x51: 12, 0x52: 2, 0x53: 1, 0x72: 63, 0x55: 5, 0x57: 1, 0x58: 3,
            0x59: 1, 0x5a: 16, 0x5b: 63, 0x5c: 1, 0x5d: 1, 0x60: 1, 0x61: 16,
            0x62: 1, 0x67: 1, 0x68: 1, 0x70: 63, 0x71: 63, 0x74: 63, 0x75: 1, 0xf0: 8}

def HIDIOCGFEATURE(n):  # _IOWR('H', 0x07, n)
    return (3 << 30) | (n << 16) | (ord('H') << 8) | 0x07

fd = os.open(DEV, os.O_RDWR | os.O_NONBLOCK)
for rid, size in FEATURES.items():
    buf = bytearray([rid] + [0] * size)
    try:
        fcntl.ioctl(fd, HIDIOCGFEATURE(len(buf)), buf)
        data = bytes(buf[1:])
        txt = "".join(chr(b) if 32 <= b < 127 else "." for b in data)
        print(f"feat 0x{rid:02x}: {data.hex(' ')}  |{txt}|")
    except OSError as e:
        print(f"feat 0x{rid:02x}: ERR {e.strerror}")

print(f"\nlistening {LISTEN}s for input reports...")
end = time.time() + LISTEN
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.5)
    if r:
        d = os.read(fd, 64)
        print(f"{time.strftime('%H:%M:%S')} in: {d.hex(' ')}")
