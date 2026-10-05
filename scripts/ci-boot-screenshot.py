#!/usr/bin/env python3
"""Capture periodic screenshots from a QEMU monitor socket, and optionally log
in to the guest and run a few diagnostic commands.

Used by CI. QEMU is started like this:

    qemu-system-x86_64 ... -display none -vga std \
        -monitor unix:<socket>,server,nowait

Two jobs:
  1. ``screendump`` every ``--interval`` seconds, converting PPM to PNG. These
     screenshots are the boot proof: they show the boot menu, kernel messages,
     login prompt or desktop without needing the guest's serial console.
  2. With ``--diagnose``, type a login and a short list of commands into the
     guest and screenshot each answer. When a graphical session does not come
     up, this is the only way to find out why — the screenshots alone cannot
     tell you whether the default target, the display manager or the session
     is the thing that is broken.
"""
import argparse
import os
import socket
import time

# QEMU monitor key names for everything the diagnostic commands need.
KEYS = {}
for _c in "abcdefghijklmnopqrstuvwxyz":
    KEYS[_c] = _c
for _c in "0123456789":
    KEYS[_c] = _c
KEYS.update({
    " ": "spc", "-": "minus", ".": "dot", "/": "slash", "=": "equal",
    ",": "comma", ";": "semicolon", ":": "shift-semicolon",
    "|": "shift-backslash", "_": "shift-minus", "\n": "ret", "\t": "tab",
})


def talk(mon, cmd, wait=1.0, read=True):
    """Send one monitor command and return whatever comes back."""
    mon.sendall((cmd + "\n").encode())
    time.sleep(wait)
    if not read:
        return ""
    mon.settimeout(3.0)
    try:
        return mon.recv(65536).decode(errors="replace")
    except socket.timeout:
        return ""


def type_text(mon, text):
    """Type a string into the guest one key at a time."""
    unknown = []
    for ch in text:
        key = KEYS.get(ch.lower() if ch.isalpha() else ch)
        if key is None:
            unknown.append(ch)
            continue
        talk(mon, f"sendkey {key}", wait=0.04, read=False)
    if unknown:
        print(f"     (skipped unsupported characters: {unknown!r})")
    time.sleep(0.3)


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


def shot(mon, outdir, name):
    ppm = os.path.join(outdir, f"{name}.ppm")
    png = os.path.join(outdir, f"{name}.png")
    reply = talk(mon, f"screendump {ppm}", wait=1.5)
    ok = os.path.exists(ppm)
    print(f"  shot {name}: file={ok} reply={reply.strip()[:50]!r}")
    if ok:
        print(f"       {os.path.getsize(ppm)} bytes")
        if to_png(ppm, png):
            os.remove(ppm)
            print(f"       -> {png}")
            return True
    return False


DIAGNOSTICS = [
    ("diag0_get-default", "systemctl get-default"),
    ("diag1_sddm-enabled", "systemctl is-enabled sddm"),
    ("diag2_graphical-active", "systemctl is-active graphical.target"),
    ("diag3_failed-units", "systemctl --failed --no-pager"),
    ("diag4_sessions", "ls /usr/share/wayland-sessions /usr/share/xsessions"),
    ("diag5_sddm-state", "systemctl is-active sddm"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--monitor", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--interval", type=int, default=180)
    ap.add_argument("--count", type=int, default=16)
    ap.add_argument("--press-enter-first", action="store_true")
    ap.add_argument("--diagnose", action="store_true",
                    help="log in as liveuser and screenshot diagnostic command output")
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
        print(f"[{i:02d}] t={args.interval * (i + 1)}s")
        if shot(mon, args.outdir, f"shot{i:02d}"):
            saved += 1

    if args.diagnose:
        print("\n=== diagnostics: logging in as liveuser and asking the guest ===")
        type_text(mon, "liveuser\n")
        time.sleep(6)
        # liveuser has an empty password, so the password prompt only needs Enter.
        # Without this the diagnostic commands get typed as the password and the
        # login fails with "Login incorrect".
        type_text(mon, "\n")
        time.sleep(4)
        shot(mon, args.outdir, "diag_login")
        for name, cmd in DIAGNOSTICS:
            print(f"  typing: {cmd}")
            type_text(mon, cmd + "\n")
            time.sleep(5)
            shot(mon, args.outdir, name)

    mon.close()
    print(f"done: {saved} boot screenshot(s) + diagnostics in {args.outdir}")


if __name__ == "__main__":
    main()
