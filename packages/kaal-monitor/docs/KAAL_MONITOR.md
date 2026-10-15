# KAAL System Monitor

A live view of what the machine is doing: CPU, memory, disks, temperatures and
running services. A PyQt6 app, matching `kaal-space-editor` and
`kaal-space-switcher`.

```
kaal-monitor            # the GUI
kaal-monitor --dump     # one sample to stdout, no GUI (works over SSH)
kaal-monitor --version
```

## What it reads

Everything comes from `/proc` and `/sys`, plus `systemctl` for the service list.
There is no `psutil` dependency — the image already has PyQt6, and that is the
only requirement.

| Tab | Source | Refresh |
|-----|--------|---------|
| CPU | `/proc/stat` deltas, `/proc/loadavg`, `/proc/uptime`, `/proc/cpuinfo` | 1 s |
| Memory | `/proc/meminfo` | 1 s |
| Disks | `/proc/mounts` + `statvfs` | 5 s |
| Temperatures | `/sys/class/thermal`, `/sys/class/hwmon` | 5 s |
| Services | `systemctl list-units --type=service` | 5 s |

## Design notes

The data-collection functions at the top of `usr/bin/kaal-monitor` are pure —
they take no arguments beyond what they read, return plain values, and never
touch Qt. That is deliberate: it means the half that can be wrong about the
system can be tested on a machine with no display.

Two things the first screenshots caught, both fixed:

- **Bind-mounted files were listed as disks.** Container runtimes mount single
  files (`/etc/hostname`, `/etc/resolv.conf`, `/dev/termination-log`), which
  appear in `/proc/mounts` with a real fstype. A mountpoint that is not a
  directory is now skipped.
- **A 9p mount reported 8192 PiB.** `statvfs` can overflow on network
  filesystems. Sizes above 1 EiB are now skipped — no real filesystem is that big.

Also worth knowing: `/proc/cpuinfo` reports `model name : unknown` on some
kernels and in every container, so the app falls back to the architecture rather
than showing a user the word "unknown".

## Testing

```
kaal-monitor --dump                       # sanity-check the data collection
QT_QPA_PLATFORM=offscreen python3 -c "..."  # build the window with no display
```

The GUI half is testable without a screen: `create_window()` builds and returns
the window without entering the event loop, so it can be driven, inspected and
screenshotted on a headless machine.
