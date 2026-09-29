# KAAL OS — Validation & Status Report

Last updated: 2026-09-29 · Reflects commit history through the CI green-smoke milestone.

## Executive summary

The project's first bootable ISO is real: the **minimal test ISO** builds green in
GitHub Actions on every push and is downloadable as a workflow artifact. The
Fedora 42 → 44 rebase is complete. The **full live ISO** (all 7 packages, 6 DEs)
is passing its early gates (staging, kickstart validation, lmc startup) and is
in active iteration.

## What has been verified

| Check | Result |
|-------|--------|
| Kickstart syntax (`ksvalidator`, both kickstarts) | ✅ Pass (CI + locally) |
| Fedora 44 repository reachability (Everything + updates, x86_64) | ✅ Pass (install completes in CI) |
| Full package install into disk image (smoke: 1472 packages) | ✅ Pass |
| Anaconda post-install + exit in container | ✅ Pass |
| squashfs runtime creation | ✅ Pass |
| EFI (el torito + efiboot) ISO assembly | ✅ Pass |
| ISO artifact upload + download + `file` verification | ✅ Pass ("ISO 9660 ... bootable") |
| 7-package staging in full build | ✅ Pass |
| lmc invocation (full build) | ✅ Pass (after flag cleanup) |

## CI state (per workflow)

| Workflow | State | Notes |
|----------|-------|-------|
| Build ISO | 🟡 smoke job green · full job iterating | Full build ~1–3 h; failures so far were config-level, each fixed in a dedicated commit |
| Validate | 🔴 11 lint findings | Pre-existing shellcheck/flake8 items in build scripts; do not block Build ISO. Tracked below |
| Test ISO | ⏸ awaiting green Build ISO | Boots ISO in QEMU, watches serial console for boot stages/panics |
| Release | ⏸ awaits `v*` tag | Never run by design |

## Fix history (one change per commit)

1. `b8d4157`…`1bc4382` — Fedora 42 → 44 rebase (17 files)
2. `3bda52a` — remove nonexistent `@wayland` group (smoke kickstart)
3. `78cf3f3` — remove `--image-only` (was skipping ISO creation)
4. `1981270` — add `grub2-efi-x64-cdboot` (missing EFI files in ISO)
5. `2e504e5` — add `--iso-only` (result-dir layout)
6. `d931adbb` — remove self-destructing `docker rmi` in full-build prep
7. `5ddfd1f` — remove `@wayland` group (full kickstart)
8. `5320204` — remove nonexistent `--iso-label`/`--title` flags
9. `a3130ae` — remove `text` display-mode directive (lmc refuses it)

## Open issues

1. **Validate workflow red** — 11 lint findings (shellcheck/flake8) across build
   scripts. Cosmetic-to-minor; none block the build.
2. **No LICENSE file** — a license must be chosen before wide distribution.
3. **RPM packaging** — the 7 packages are staged into the image via kickstart
   `%post --nochroot` copy, not built/installed as RPMs.
4. **`kiwi/distro-live.xml`** — contains an invalid XML comment (a `--description`
   string inside a comment block); harmless for the lmc path, breaks strict XML
   consumers.
5. **Full build untested end-to-end** — first complete run pending.

## How to verify the smoke ISO yourself

Download the `kaal-minimal-test-iso` artifact from the latest green Build ISO
run, then:

```sh
sha256sum boot.iso        # compare against the run's checksum output
qemu-system-x86_64 -m 4096 -enable-kvm -cdrom boot.iso
```

Expected: GRUB menu → kernel boots → GNOME desktop, autologin as `liveuser`.
