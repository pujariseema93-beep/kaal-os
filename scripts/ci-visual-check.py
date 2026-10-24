#!/usr/bin/env python3
"""Visual verification for the ISO boot test.

Why this exists
---------------
The boot test used to decide "the system booted" by grepping the serial log for
strings such as SDDM, GDM or Cinnamon. Those match far too early: the log line
``sddm.service start waiting`` contains "SDDM" while the unit is merely queued,
and "cinnamon" appears as a package name. Builds were therefore declared booted
while the guest was still in early boot -- one capture shows
``Job ldconfig.service/start running (1min 56s)`` and no graphical session at
all -- and the installer gate then tried to drive a machine with no desktop.

So the authority is now the *display*, not the log text. A screendump is
classified as console or graphical from two measurements, calibrated against
real frames captured by this pipeline:

    distinct colours (after downscale to 320x200)
        console frames : 1 .. 361
        login/other    : 1285 .. 1327
        desktop frames : 8338 .. 8342
    fraction of near-black pixels
        console frames : 0.79 .. 1.00
        desktop frames : 0.03

    graphical  :=  colours > 800  and  dark < 0.5

That is a factor of 20 between the classes, so the margin is wide.

Modes
-----
  --wait-graphical   poll the display until it is graphical. Fails on timeout,
                     and fails fast if the serial log shows a kernel panic or an
                     emergency shell.
  --gate             take a baseline frame, drive the guest to start Calamares,
                     then require the screen to have actually changed AND to
                     still be graphical. Writes calamares-first-page.png.
                     Exits non-zero when it cannot prove Calamares drew.
"""
import argparse
import os
import socket
import sys
import time

# ---------------------------------------------------------------- monitor I/O

def _key_for(ch):
    """QEMU monitor key name for a character. Letters are case-sensitive:
    an upper-case letter is ``shift-<lower>``."""
    if ch.isalpha():
        return ("shift-" + ch.lower()) if ch.isupper() else ch.lower()
    return {
        " ": "spc", "-": "minus", ".": "dot", "/": "slash", "=": "equal",
        "_": "shift-minus", ":": "shift-semicolon", ",": "comma",
        ";": "semicolon", "\n": "ret", "\t": "tab",
    }.get(ch)


class Monitor:
    def __init__(self, path, timeout=5):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(path)
        time.sleep(1)
        self.sock.settimeout(timeout)

    def talk(self, cmd, wait=0.06):
        self.sock.sendall((cmd + "\n").encode())
        time.sleep(wait)

    def type_text(self, text):
        for ch in text:
            key = _key_for(ch)
            if key:
                self.talk("sendkey %s" % key)
        time.sleep(0.4)

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


# ------------------------------------------------------------------ screendump

def screendump(mon, png_path):
    """Capture the guest display to png_path. Returns True on success.

    QEMU is started with -daemonize, which chdir()s to / (os_setup_post), so a
    relative path resolves against / and the write silently vanishes. Always
    hand it an absolute path.
    """
    ppm = os.path.abspath(png_path + ".ppm")
    if os.path.exists(ppm):
        os.remove(ppm)
    mon.talk("screendump %s" % ppm, wait=3)
    if not os.path.exists(ppm):
        return False
    try:
        from PIL import Image
        Image.open(ppm).save(png_path)
        os.remove(ppm)
        return True
    except Exception:                                   # noqa: BLE001
        return False


# ------------------------------------------------------------------ classifier

COLOUR_MIN = 800        # console max observed 361; graphical min observed 1285
DARK_MAX = 0.5          # console min observed 0.79; graphical max observed 0.03


def measure(png_path):
    """Return (colours, dark_fraction) for an image."""
    from PIL import Image
    im = Image.open(png_path).convert("RGB").resize((320, 200), Image.LANCZOS)
    px = list(im.getdata())
    n = len(px)
    colours = len(set(px))
    dark = sum(1 for r, g, b in px if max(r, g, b) < 40) / n
    return colours, dark


def is_graphical(png_path):
    colours, dark = measure(png_path)
    return (colours > COLOUR_MIN and dark < DARK_MAX), colours, dark


def mean_abs_diff(a_path, b_path):
    """Mean absolute per-pixel difference, 0..255."""
    from PIL import Image
    a = Image.open(a_path).convert("RGB").resize((320, 200), Image.LANCZOS)
    b = Image.open(b_path).convert("RGB").resize((320, 200), Image.LANCZOS)
    pa, pb = list(a.getdata()), list(b.getdata())
    total = 0
    for (r1, g1, b1), (r2, g2, b2) in zip(pa, pb):
        total += abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)
    return total / (len(pa) * 3)


# --------------------------------------------------------------- serial checks

PANIC_PATTERNS = (
    "kernel panic", "not syncing", "you are in emergency mode",
    "emergency shell", "dracut.*timeout", "timed out waiting for device",
    "call trace:",
)


def serial_problem(path):
    """Return a matched panic/emergency pattern, or None."""
    import re
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, "r", errors="replace") as fh:
            blob = fh.read().lower()
    except OSError:
        return None
    for pat in PANIC_PATTERNS:
        if re.search(pat, blob):
            return pat
    return None


# ----------------------------------------------------------------------- modes

def wait_graphical(args):
    deadline = time.time() + args.timeout
    attempt = 0
    last = None
    while time.time() < deadline:
        attempt += 1
        problem = serial_problem(args.serial)
        if problem:
            print("::error::boot failure in serial log: %s" % problem)
            return 1
        mon = Monitor(args.monitor)
        tmp = os.path.join(args.outdir, "wait-%03d.png" % attempt)
        ok = screendump(mon, tmp)
        mon.close()
        if not ok:
            print("  [%3ds] screendump failed" % int(time.time() - (deadline - args.timeout)))
            time.sleep(args.interval)
            continue
        graphical, colours, dark = is_graphical(tmp)
        print("  attempt %d: colours=%d dark=%.2f -> %s"
              % (attempt, colours, dark, "GRAPHICAL" if graphical else "console"))
        last = tmp
        if graphical:
            print("graphical session detected after %d attempts" % attempt)
            os.replace(tmp, os.path.join(args.outdir, "graphical-session.png"))
            return 0
        time.sleep(args.interval)
    print("::error::no graphical session within %ds — the display never left the console"
          % args.timeout)
    if last:
        print("  last frame: %s" % last)
    return 1


def gate(args):
    """Baseline -> start Calamares -> require the screen changed and is graphical."""
    os.makedirs(args.outdir, exist_ok=True)
    mon = Monitor(args.monitor)

    base = os.path.join(args.outdir, "baseline.png")
    if not screendump(mon, base):
        print("::error::could not capture a baseline frame from the guest display")
        mon.close()
        return 1
    graphical, colours, dark = is_graphical(base)
    print("baseline: colours=%d dark=%.2f graphical=%s" % (colours, dark, graphical))
    if not graphical:
        print("::error::guest is not at a graphical session — refusing to claim Calamares ran")
        mon.close()
        return 1

    # Text VT (tty2) is unaffected by the graphical session's lock screen.
    mon.talk("sendkey ctrl-alt-f2")
    time.sleep(5)
    mon.type_text(args.user + "\n")
    time.sleep(5)
    mon.type_text(args.password + "\n")
    time.sleep(5)

    # Run as the live user, not root: Calamares warns but still draws.
    mon.type_text("DISPLAY=%s XAUTHORITY=/home/%s/.Xauthority calamares\n"
                  % (args.display, args.user))
    time.sleep(30)

    mon.talk("sendkey ctrl-alt-f1")
    time.sleep(10)

    shot = os.path.join(args.outdir, "calamares-first-page.png")
    if not screendump(mon, shot):
        print("::error::screendump produced nothing after the launch attempt")
        mon.close()
        return 1
    mon.close()

    graphical, colours, dark = is_graphical(shot)
    diff = mean_abs_diff(base, shot)
    print("after launch: colours=%d dark=%.2f graphical=%s diff=%.1f"
          % (colours, dark, graphical, diff))

    if not graphical:
        print("::error::the display is a console, not a graphical page — Calamares did not draw")
        return 1
    if diff < args.min_diff:
        print("::error::the screen is unchanged (diff %.1f < %.1f) — Calamares did not start"
              % (diff, args.min_diff))
        return 1

    print("Calamares drew its first page: screen changed (diff %.1f) and is graphical" % diff)
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--monitor", default="mon.sock")
    ap.add_argument("--outdir", default="calamares")
    ap.add_argument("--serial", default="serial.log")
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--interval", type=int, default=15)
    ap.add_argument("--min-diff", type=float, default=5.0)
    ap.add_argument("--user", default="liveuser")
    ap.add_argument("--password", default="kaal-live")
    ap.add_argument("--display", default=":0")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--wait-graphical", action="store_true")
    mode.add_argument("--gate", action="store_true")
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)
    if args.wait_graphical:
        return wait_graphical(args)
    return gate(args)


if __name__ == "__main__":
    sys.exit(main())
