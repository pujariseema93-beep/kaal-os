# Building KAAL OS ISOs on the openSUSE Build Service (OBS)

This guide takes you from zero to a KAAL OS live ISO built entirely on OBS's
free build farm — no local hardware, no GitHub Actions 2-core runners, no
wall-clock timeouts.

## Why OBS

GitHub Actions gives public repos unlimited *minutes*, but the runners are
2-core machines — too slow for a full ISO build. OBS is a free build service
for open source that builds images professionally (it builds openSUSE
itself). Your repo already contains a kiwi description; this kit adapts it
to OBS.

## What's in this kit (`packages/distro-iso-builder/obs/`)

| File | Purpose |
|------|---------|
| `config.kiwi` | kiwi image description, OBS-adapted: Fedora 42 repos come from your OBS project; includes KDE, Calamares and the KAAL overlay (milestone 1 scope) |
| `config.sh` | Runs inside the image during the build — KAAL os-release, SDDM autologin, dnf config, cleanup (the kiwi equivalent of the kickstart `%post`) |
| `make-obs-package.sh` | Assembles an osc working directory: the two files above plus a `root/` overlay containing the file trees of all 7 KAAL packages and the Calamares config in `/etc/calamares` |

## Setup — one time, about 20 minutes

### 1. Account

Create a free account at https://build.opensuse.org (Sign Up, top right).
Your projects live under `home:<username>`.

### 2. Install osc (the OBS command-line client)

On Fedora:

```bash
sudo dnf install osc
```

Then point it at the public instance:

```bash
osc -A https://api.opensuse.org whoami   # will ask for login once
```

### 3. Create the project

Web UI is the most reliable path (project names and repo layouts change):

1. Go to **Home Project → Overview → Add from a Distribution**.
2. Add **Fedora 42** (the standard repo). This gives your project the
   Fedora Everything binary pool.
3. In the same Repositories screen, tick the **images** repository checkbox
   (bottom of the selection screen) — this is what enables image builds.

Then add the kiwi builder project as a second repository path. Edit the
project meta (`osc meta -e home:<username>:kaal` or the web UI's Project
Config) so it contains roughly:

```xml
<project name="home:YOURNAME:kaal">
  <title>KAAL OS</title>
  <repository name="images">
    <path project="Fedora:42" repository="standard"/>
    <path project="Virtualization:Appliances:Builder" repository="Fedora_42"/>
    <arch>x86_64</arch>
  </repository>
</project>
```

> Verify the exact Fedora and Builder project/repository names in the web
> UI's distribution picker — they occasionally change between releases.
> `Virtualization:Appliances:Builder` is where OBS gets kiwi-NG from.

### 4. Tell OBS this package is a kiwi image

Edit the project config (`osc meta -e prjconf` — note: `prjconf`, not
`prj`) and add:

```
Type: kiwi
```

Without this line OBS tries to build the package as an RPM spec and fails.

### 5. Create the package and assemble the files

```bash
# create the package (web UI: "Create package", name it kaal-os-live)
osc -A https://api.opensuse.org co home:YOURNAME:kaal kaal-os-live

# from the repo root:
./packages/distro-iso-builder/obs/make-obs-package.sh \
     home:YOURNAME:kaal/kaal-os-live
```

This drops `config.kiwi`, `config.sh` and the `root/` overlay (all 7 KAAL
packages + `/etc/calamares`) into the package directory.

### 6. Commit and build

```bash
cd home:YOURNAME:kaal/kaal-os-live
osc addremove
osc ci -m "KAAL OS live ISO — initial upload"
```

OBS starts the build. Watch it:

```bash
osc results -w          # live status, Ctrl+C to stop
# or the web UI: your package → Build Results
```

A base live ISO typically builds in well under an hour on OBS workers.

### 7. Download the ISO

From the web UI: package → Repositories → images → click the architecture
→ download the `.iso`. Or:

```bash
osc getbinaries home:YOURNAME:kaal kaal-os-live images x86_64
```

Then flash and boot it exactly like the CI-built ISO (see issue #2's QEMU
boot test).

## Milestones

1. **Green base build** (this kit): Fedora 42 + KDE Plasma + Calamares +
   KAAL overlay files, liveuser autologin. The win: a real bootable ISO
   without owning build hardware.
2. **Full build**: once milestone 1 is green, add the RPM Fusion
   repositories and the gaming/NVIDIA package list from
   `kiwi/distro-live.xml` into `config.kiwi` (a commented marker sits
   where they go). Note: if OBS workers cannot fetch the external RPM
   Fusion URLs, keep the gaming stack for local kiwi builds and use OBS
   for the base ISO.
3. **Calamares polish**: verify the custom modules
   (profile-select, de-select, space-select, bootloader-select) render
   inside the live session and that `install-context.conf` is written
   during install — this is where the real distro personality kicks in.

## Gotchas and notes

- **`Type: kiwi` is mandatory** (step 4) — an RPM-format project defaults
  to spec builds and ignores kiwi files.
- **File must be named `config.kiwi`** — OBS ignores other kiwi names like
  `config.xml` or `distro-live.xml`.
- If OBS complains about ambiguous package choices (`have choice`),
  resolve with `Prefer: <package>` lines in `prjconf`.
- **Etiquette**: OBS is free for open source — keep builds reasonable,
  don't hammer it with dozens of parallel packages, and your project will
  be fine.
- The `root/` overlay is regenerated by `make-obs-package.sh` from the
  repo — never hand-edit it; change the source packages and re-run.
- The GitHub Actions pipeline stays as-is for the smoke test; OBS is the
  heavy-lifting path for full ISOs (issues #1/#3).

## Quick reference

```bash
# day-to-day, after editing packages or the kiwi description:
./packages/distro-iso-builder/obs/make-obs-package.sh home:YOU:kaal/kaal-os-live
cd home:YOU:kaal/kaal-os-live && osc addremove && osc ci -m "update"
osc results -w
```
