#!/usr/bin/env python3
"""Capture periodic screenshots from a QEMU monitor socket.

Used by CI. QEMU is started like this:

    qemu-system-x86_64 ... -display none -vga std \
        -monitor unix:<socket>,server,nowait

This script connects to that monitor socket and asks for a ``screendump``
every ``--interval`` seconds, converting each PPM to PNG when Pillow is
available. Screenshots are the boot proof: they show whatever the guest is
displaying (boot menu, kernel messages, login prompt, desktop) without
depending on the guest's serial console being configured.

With --press-enter-first it also taps Enter twice in the first half minute,
so a GRUB menu that is waiting for input does not stall the whole test.
"""
import argparse
import os
import socket
import time


def talk(mon, cmd, wait=1.5):
    """Send one monitor command and return whatever comes back."""
    mon.sendall((cmd + "\n").encode())
    time.sleep(wait)
    mon.settimeout(3.0)
    try:
        return mon.recv(65536).decode(errors="replace")
    except socket.timeout:
        return ""


def to_png(ppm, png):
    try:
        from PIL import Image
    except ImportError:
        print("     (Pillow not installed — keeping the PPM)")
        return False
    try:
        Image.open(ppm).save(png)
        return True
    except Exception as exc:                       # noqa: BLE001
        print(f"     (convert failed: {exc})")
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--monitor", required=True, help="path to the QEMU monitor unix socket")
    ap.add_argument("--outdir", required=True, help="where screenshots are written")
    ap.add_argument("--interval", type=int, default=180, help="seconds between shots")
    ap.add_argument("--count", type=int, default=12, help="how many shots to take")
    ap.add_argument("--press-enter-first", action="store_true",
                    help="tap Enter twice early on, in case a boot menu is waiting")
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    mon = socket.socket(socket.AF_UNIX)
    mon.connect(args.monitor)
    time.sleep(1.0)
    mon.settimeout(3.0)
    try:
        banner = mon.recv(65536).decode(errors="replace").strip()
        print("monitor banner:", banner.splitlines()[0] if banner else "(none)")
    except socket.timeout:
        print("monitor banner: (none)")

    if args.press_enter_first:
        for _ in range(2):
            time.sleep(15)
            print("sendkey ret ->", talk(mon, "sendkey ret").strip()[:40])

    saved = 0
    for i in range(args.count):
        time.sleep(args.interval)
        ppm = os.path.join(args.outdir, f"shot{i:02d}.ppm")
        png = os.path.join(args.outdir, f"shot{i:02d}.png")
        reply = talk(mon, f"screendump {ppm}")
        elapsed = args.interval * (i + 1)
        print(f"[{i:02d}] t={elapsed}s reply={reply.strip()[:70]!r}")
        if os.path.exists(ppm):
            print(f"     ppm: {os.path.getsize(ppm)} bytes")
            if to_png(ppm, png):
                os.remove(ppm)
                saved += 1
                print(f"     png: {png}")
        else:
            print("     (no file produced — the guest display may not be up yet)")
    mon.close()
    print(f"done: {saved} PNG screenshot(s) in {args.outdir}")


if __name__ == "__main__":
    main()
