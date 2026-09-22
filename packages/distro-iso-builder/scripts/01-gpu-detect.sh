#!/bin/bash
# =============================================================================
# 01-gpu-detect.sh — GPU Detection & Driver Setup (Post-Install)
# =============================================================================
# Runs during Calamares post-install phase. Detects the GPU and ensures
# the correct driver stack is installed and configured.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS GPU Detection & Driver Setup ==="

# Detect GPU
GPU_NVIDIA=false
GPU_AMD=false
GPU_INTEL=false

if lspci | grep -qi 'NVIDIA'; then
    GPU_NVIDIA=true
    echo "Detected: NVIDIA GPU"
elif lspci | grep -qi 'AMD.*Radeon\|AMD.*RDNA'; then
    GPU_AMD=true
    echo "Detected: AMD GPU"
elif lspci | grep -qi 'Intel.*Graphics\|Intel.*UHD\|Intel.*Iris\|Intel.*Arc'; then
    GPU_INTEL=true
    echo "Detected: Intel iGPU"
fi

# Hybrid detection
GPU_COUNT=$(lspci | grep -icE 'VGA compatible|3D controller|Display controller' || echo 1)
if [ "$GPU_COUNT" -gt 1 ]; then
    echo "Hybrid graphics detected ($GPU_COUNT GPUs)"
fi

# ---- NVIDIA Setup ----
if [ "$GPU_NVIDIA" = "true" ]; then
    echo "Setting up NVIDIA driver..."

    # Ensure akmod-nvidia is installed and built
    dnf5 install -y akmod-nvidia nvidia-settings nvidia-persistenced 2>/dev/null || true

    # Build the kernel modules for the current kernel
    akmods --force 2>/dev/null || true

    # Enable nvidia-persistenced
    systemctl enable nvidia-persistenced 2>/dev/null || true

    # Enable NVIDIA DRM modesetting (required for Wayland)
    if grep -q 'nvidia-drm.modeset' /etc/default/grub; then
        sed -i 's/.*nvidia-drm.modeset=.*/nvidia-drm.modeset=1/' /etc/default/grub
    else
        # Add to GRUB_CMDLINE_LINUX
        sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 nvidia-drm.modeset=1"/' /etc/default/grub
    fi

    # Blacklist nouveau
    echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
    echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf

    echo "NVIDIA driver setup complete"
fi

# ---- AMD Setup ----
if [ "$GPU_AMD" = "true" ]; then
    echo "Setting up AMD GPU..."
    # AMDGPU is already in the kernel — just ensure mesa drivers are installed
    dnf5 install -y mesa-vulkan-drivers mesa-dri-drivers mesa-va-drivers mesa-vdpau-drivers vulkan-radeon 2>/dev/null || true

    # Enable power play features for overclocking
    if grep -q 'amdgpu.ppfeaturemask' /etc/default/grub; then
        sed -i 's/.*amdgpu.ppfeaturemask=.*/amdgpu.ppfeaturemask=0xffffffff/' /etc/default/grub
    else
        sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 amdgpu.ppfeaturemask=0xffffffff"/' /etc/default/grub
    fi

    echo "AMD GPU setup complete"
fi

# ---- Intel Setup ----
if [ "$GPU_INTEL" = "true" ]; then
    echo "Setting up Intel iGPU..."
    dnf5 install -y mesa-vulkan-drivers mesa-dri-drivers vulkan-intel 2>/dev/null || true

    if grep -q 'i915.enable_guc' /etc/default/grub; then
        sed -i 's/.*i915.enable_guc=.*/i915.enable_guc=3/' /etc/default/grub
    fi

    echo "Intel iGPU setup complete"
fi

# Regenerate GRUB config with new parameters
echo "Regenerating GRUB config..."
if [ -d /sys/firmware/efi ]; then
    grub2-mkconfig -o /boot/efi/EFI/distro/grub.cfg 2>/dev/null || \
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
else
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
fi

# Regenerate initramfs with GPU drivers
echo "Regenerating initramfs..."
for kernel_dir in /lib/modules/*/; do
    kver=$(basename "$kernel_dir")
    dracut --force --kver "$kver" 2>/dev/null || true
done

echo "=== GPU Detection & Driver Setup Complete ==="
