# KAAL OS CI/CD Pipeline

Complete automation for building, testing, and releasing the distro ISO — GitHub Actions workflows, Docker build container, Makefile, and QEMU boot tests.

## Pipeline Overview

```
Push to main/develop
  → Validate (shellcheck, flake8, ksvalidator, yamllint, placeholder check)
  → Build ISO (Fedora 42 container, livemedia-creator, ~45 min)
  → Test ISO (QEMU boot, verify desktop/login reached)
  → Upload artifact (14-day retention)

Tag push (v*)
  → Build ISO (same as above)
  → Release (GitHub Release with ISO + checksums)
```

## File Structure

```
distro-ci/
├── .github/workflows/
│   ├── validate.yml              — Code quality: shellcheck, flake8, ksvalidator
│   ├── build-iso.yml             — Build ISO in Fedora container
│   ├── test-iso.yml              — Boot ISO in QEMU, verify it works
│   └── release.yml               — Create GitHub Release with ISO
├── Dockerfile/
│   └── Dockerfile                — Fedora 42 build container
├── ci/
│   ├── qemu-boot-test.sh         — QEMU boot test script
│   └── assemble-all.sh           — Assemble all packages into one tree
├── config/
│   └── (placeholder for CI config overrides)
├── docs/
│   └── CICD_GUIDE.md             — Full CI/CD documentation
├── Makefile                      — Unified build targets
├── .editorconfig                 — Code style enforcement
└── README.md                     — This file
```

## Quick Start

### Local Build

```bash
# Install dependencies (Fedora)
sudo dnf install lorax xorriso isomd5sum pykickstart livecd-tools

# Validate code
make validate

# Build ISO (requires root, ~45 min)
sudo make build

# Test ISO in QEMU
make test

# Clean up
make clean
```

### Docker Build

```bash
# Build the Docker container
make docker-build

# Build ISO inside Docker
make docker-build-iso

# Or run interactively
make docker-run
```

### Assemble All Packages

```bash
# Collect files from all 5 packages into a single tree
make assemble
# or
./ci/assemble-all.sh
```

## GitHub Actions

### Validate Workflow
Triggers on every push and PR to main/develop.
- **shellcheck** — all `.sh` scripts
- **flake8** — Calamares Python modules
- **ksvalidator** — kickstart files (in Fedora container)
- **yamllint** — YAML files
- **Placeholder check** — flags `KAAL OS`, TODO, FIXME
- **Structure check** — verifies required files exist

### Build ISO Workflow
Triggers on push to main/develop, tag pushes (v*), and manual dispatch.
- Runs in Fedora 42 container with `--privileged`
- Executes `livemedia-creator` with the kickstart
- Uploads ISO + checksums + build log as artifact (14-day retention)
- Generates build summary in GitHub Actions

### Test ISO Workflow
Triggers after successful Build ISO workflow.
- Downloads ISO artifact
- Boots in QEMU (2GB RAM, 2 cores, UEFI via OVMF)
- Monitors serial console for boot stages (GRUB → kernel → systemd → desktop)
- Checks for kernel panic
- Attempts SSH connection on forwarded port 2222
- Uploads serial log as artifact

### Release Workflow
Triggers on tag push (v*).
- Downloads ISO from latest successful build
- Generates release notes with features list
- Creates GitHub Release with ISO + SHA256 checksum
- Marks as pre-release if version contains alpha/beta/rc

## Make Targets

| Target | Description |
|--------|-------------|
| `make help` | Show available targets |
| `make validate` | Run all validation checks |
| `make validate-shell` | Shellcheck only |
| `make validate-python` | flake8 only |
| `make validate-kickstart` | ksvalidator only |
| `make validate-yaml` | yamllint only |
| `make assemble` | Assemble all packages into build-tree/ |
| `make build` | Build the live ISO |
| `make test` | Boot-test ISO in QEMU |
| `make release VERSION=x.y.z` | Create git tag for release |
| `make docker-build` | Build Docker container |
| `make docker-run` | Run container interactively |
| `make docker-build-iso` | Build ISO in Docker |
| `make clean` | Remove build artifacts |
| `make dist-clean` | Remove everything |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DISTRO_NAME` | `KAAL OS` | Distro name (replace before release) |
| `RELEASEVER` | `42` | Fedora release version |
| `PROFILE` | `all` | Software profile |
| `WORKDIR` | `/var/tmp/distro-build` | Build working directory |
| `RESULTDIR` | `results` | Output directory for ISO |

## Releasing

```bash
# Tag and push
git tag -a v0.1.0 -m "First alpha release"
git push origin v0.1.0

# GitHub Actions will:
# 1. Build the ISO
# 2. Create a GitHub Release
# 3. Attach the ISO + checksum
```

## Requirements

- **Local build**: Fedora 40+ host, root access, 20GB disk
- **Docker build**: Docker, 20GB disk
- **CI/CD**: GitHub Actions (free tier works, but ISO build takes ~45 min)
- **QEMU test**: QEMU, OVMF (for UEFI), 2GB RAM for VM
