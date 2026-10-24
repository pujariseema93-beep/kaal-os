#!/usr/bin/env python3
"""Launch Calamares in a booted live guest and screenshot its first page.

The ISO Boot Test mounts the ISO to prove the installer is *present and
configured*; that says nothing about whether Calamares actually starts.
This is the launch half of the installer gate — "the ISO boots" is not
"the installer works".

Input is injected through the QEMU monitor socket (the boot test starts
QEMU with ``-monitor unix:mon.sock``). The guest's graphical session
locks itself after a few idle minutes and swallows typed keys — which is
exactly why the older ``--diagnose`` screenshots all came out identical.
So this logs in on a *text* VT (``ctrl-alt-f2``), a separate console the
lock screen does not cover, starts Calamares on the graphical display,
switches back to it and takes a screendump.

Deliberately non-fatal: it produces evidence, and must not turn a green
build red while the input path is being tuned.
"""
import argparse
import os
import socket
import time

# QEMU monitor key names. Letters are case-sensitive: an upper-case letter
# is ``shift-<lower>`` (the older screenshot helper lower-cased everything,
# so any command with capitals was typed wrong — one reason diagnostics
# were useless).
def _key_for(ch):
    if ch.isalpha():
        return ("shift-" + ch.lower()) if ch.isupper() else ch.lower()
    return {
        " ": "spc", "-": "minus", ".": "dot", "/": "slash", "=": "equal",
        "_": "shift-minus", ":": "shift-semicolon", ",": "comma",
        ";": "semicolon", "\n": "ret", "\t": "tab",
    }.get(ch)


def talk(mon, cmd, wait=0.06):
    mon.sendall((cmd + "\n").encode())
    time.sleep(wait)


def type_text(mon, text):
    for ch in text:
        key = _key_for(ch)
        if key:
            talk(mon, "sendkey %s" % key)
    time.sleep(0.4)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--monitor", default="mon.sock",
                    help="QEMU monitor socket the boot test created")
    ap.add_argument("--outdir", default="calamares")
    ap.add_argument("--user", default="liveuser",
                    help="live user (distro-live.ks sets this user's password)")
    ap.add_argument("--password", default="kaal-live",
                    help="that user's password (distro-live.ks: liveuser / kaal-live)")
    ap.add_argument("--display", default=":0",
                    help="X display of the autologged-in graphical session")
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    mon = socket.socket(socket.AF_UNIX)
    mon.connect(args.monitor)
    time.sleep(1)
    mon.settimeout(5)

    # Text VT (tty2): unaffected by the graphical session's lock screen.
    talk(mon, "sendkey ctrl-alt-f2")
    time.sleep(5)
    type_text(mon, args.user + "\n")
    time.sleep(5)
    type_text(mon, args.password + "\n")
    time.sleep(5)

    # Start Calamares on the graphical display. Run as the live user, not
    # root: Calamares shows a "not running as root" warning but still draws
    # its first page, which is what the gate needs to see. Avoids a sudo
    # password prompt on the VT.
    type_text(mon, "DISPLAY=%s XAUTHORITY=/home/%s/.Xauthority calamares\n"
              % (args.display, args.user))
    time.sleep(30)

    # Back to the graphical display so the screendump captures Calamares.
    talk(mon, "sendkey ctrl-alt-f1")
    time.sleep(10)

    # QEMU is launched with -daemonize, which chdir()s the process to /
    # (see QEMU's os_setup_post()). A relative screendump path is therefore
    # resolved against / — where our outdir does not exist — so QEMU writes
    # nothing and the capture silently fails. Hand it an absolute path.
    ppm = os.path.abspath(os.path.join(args.outdir, "first-page.ppm"))
    talk(mon, "screendump %s" % ppm, wait=3)
    mon.close()

    if not os.path.exists(ppm):
        print("::warning::no screendump produced — Calamares first page not captured")
        return

    try:
        from PIL import Image
        png = os.path.join(args.outdir, "calamares-first-page.png")
        Image.open(ppm).save(png)
        os.remove(ppm)
        print("calamares first page captured: %s" % png)
    except Exception as exc:                       # noqa: BLE001
        print("screenshot convert failed: %s" % exc)


if __name__ == "__main__":
    main()
