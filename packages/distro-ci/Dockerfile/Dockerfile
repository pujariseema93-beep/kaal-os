# =============================================================================
# Dockerfile — KAAL OS Build Container
# =============================================================================
# Fedora-based container with all tools needed to build the ISO.
# Used by CI/CD and for local builds.
#
# Build:   docker build -t distro-builder -f Dockerfile/Dockerfile .
# Run:     docker run --privileged -v $(pwd):/workspace distro-builder
# Build:   docker run --privileged -v $(pwd):/workspace distro-builder make build
# =============================================================================

FROM fedora:42

LABEL maintainer="KAAL OS Team"
LABEL description="Build environment for KAAL OS ISO"

# ---- Install build dependencies ----
RUN dnf update -y && dnf install -y \
    lorax \
    lorax-composer \
    xorriso \
    isomd5sum \
    pykickstart \
    livecd-tools \
    kiwi-cli \
    kiwi-system-dependencies \
    grub2 \
    grub2-efi-x64 \
    grub2-tools \
    shim-x64 \
    dracut \
    bash \
    bash-completion \
    git \
    curl \
    wget \
    jq \
    pciutils \
    findutils \
    sed \
    grep \
    gawk \
    coreutils \
    python3 \
    python3-pip \
    python3-devel \
    qemu-system-x86 \
    qemu-img \
    ovmf \
    ShellCheck \
    && dnf clean all

RUN pip3 install --no-cache-dir flake8 yamllint

RUN useradd -m -G wheel builder
USER builder
WORKDIR /workspace

CMD ["/bin/bash"]
