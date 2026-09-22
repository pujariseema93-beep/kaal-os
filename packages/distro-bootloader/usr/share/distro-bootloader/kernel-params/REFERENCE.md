# =============================================================================
# Kernel Command Line Parameter Reference
# =============================================================================
# This file documents every kernel parameter used by KAAL OS and
# explains what each one does, why it's set, and when it's applied.
#
# This is a reference document — the actual parameters are set in:
#   /etc/default/grub                         (base params)
#   /etc/default/grub.d/10-distro-gpu.conf    (GPU params)
#   /etc/default/grub.d/20-distro-resume.conf (hibernate resume)
# =============================================================================

## =============================================================================
## BASE PARAMETERS (always applied)
## =============================================================================

# loglevel=3
#   Kernel log verbosity level.
#   0 = silent (only emergency), 3 = warnings+errors (default), 7 = debug
#   Set to 3 for a clean boot — Plymouth handles the visual boot experience.

# systemd.show_status=0
#   Hides systemd service status messages during boot.
#   Reduces text noise behind Plymouth splash.

# vt.global_cursor_default=0
#   Disables the blinking cursor on VTs during boot.
#   Prevents cursor from showing through Plymouth splash.

# nvme_load=yes
#   Forces NVMe driver to load early in boot.
#   Ensures NVMe SSDs are available before root mount.

## =============================================================================
## NVIDIA PARAMETERS (applied when NVIDIA RTX 40+ is detected)
## =============================================================================

# nvidia-drm.modeset=1
#   Enables DRM modesetting for NVIDIA driver.
#   REQUIRED for Wayland to work with NVIDIA. Without this, you get X11 only.

# nvidia_drm.fbdev=1
#   Enables framebuffer device support via nvidia-drm.
#   Provides /dev/fb0 for apps that need a raw framebuffer.

# modprobe.blacklist=nouveau
#   Prevents the open-source nouveau driver from loading.
#   Necessary because nouveau conflicts with the proprietary nvidia driver.

# rd.driver.pre=nvidia
# rd.driver.pre=nvidia_modeset
# rd.driver.pre=nvidia_drm
# rd.driver.pre=nvidia_uvm
#   Pre-loads these NVIDIA kernel modules during initramfs phase.
#   Ensures the driver is ready before the display manager starts.

## =============================================================================
## AMD PARAMETERS (applied when AMD RDNA2+ is detected)
## =============================================================================

# amdgpu.ppfeaturemask=0xffffffff
#   Enables all PowerPlay feature flags.
#   Allows overclocking, fan curve control, and power limit adjustment
#   via tools like CoreCtrl or LACT.

# rd.driver.pre=amdgpu
#   Pre-loads the amdgpu kernel module during initramfs phase.
#   Ensures GPU is initialized before display manager starts.

# amdgpu.si_support=amdgpu
#   Use the amdgpu driver for Southern Islands (HD 7000 series).
#   Default is radeon — this switches to the modern amdgpu driver.

# amdgpu.cik_support=amdgpu
#   Use the amdgpu driver for Sea Islands (HD 8000 / R9 290).
#   Same as above — enables modern driver for older cards.

## =============================================================================
## INTEL iGPU PARAMETERS (applied when Intel iGPU is detected)
## =============================================================================

# i915.enable_guc=3
#   Enables GuC (Graphics Microcontroller) submission + HuC firmware.
#   Improves performance on Gen 12+ (Tiger Lake and newer).
#   On older GPUs, this may not have an effect.

# i915.fastboot=1
#   Skips the initial modeset during boot.
#   Reduces boot time and eliminates a potential screen flicker.

# rd.driver.pre=i915
#   Pre-loads the i915 Intel graphics driver during initramfs phase.

## =============================================================================
## GAMING / PERFORMANCE PARAMETERS (always applied)
## =============================================================================

# split_lock_detect=off
#   Disables split-lock detection.
#   Some games (especially emulators and Wine/Proton) trigger split locks
#   which cause severe performance degradation. Disabling fixes this.

# preempt=full
#   Sets the kernel preemption model to "full" (PREEMPT_RT-like behavior).
#   Reduces latency for interactive and gaming workloads.
#   Trade-off: slightly lower throughput, but much better responsiveness.

# transparent_hugepage=madvise
#   Only uses Transparent Huge Pages when explicitly requested via madvise().
#   THP can cause latency spikes when the kernel defragments memory.
#   "madvise" is the balanced setting — apps that want THP get it, others don't.

## =============================================================================
## SECURITY PARAMETERS (configurable, default: performance)
## =============================================================================

# mitigations=off
#   Disables all CPU vulnerability mitigations (Spectre, Meltdown, L1TF, MDS, etc).
#   Maximum performance, but reduced security.
#
#   Alternatives:
#     mitigations=auto          — Kernel default (all mitigations on)
#     mitigations=auto,nosmt    — All mitigations + disable SMT (most secure)
#     mitigations=off           — No mitigations (max performance)
#
#   For a gaming-focused distro, "off" is the default. Users who want
#   full security can change this via kaal-tweak-tool.

## =============================================================================
## RESUME / HIBERNATION (auto-populated by installer)
## =============================================================================

# resume=UUID=<swap-uuid>
#   Points to the swap device for hibernation resume.
#   Auto-populated by the installer based on the swap configuration.

# resume_offset=<offset>
#   For swapfiles on btrfs, specifies the physical offset of the swapfile.
#   Auto-populated by the installer using `filefrag`.

## =============================================================================
## FALLBACK / SAFE MODE (used in recovery entries only)
## =============================================================================

# nomodeset
#   Disables all kernel modesetting (KMS).
#   Forces the use of a basic framebuffer (VESA/UEFI GOP).
#   Used in the fallback entry to ensure boot works even if GPU drivers fail.

# rd.driver.blacklist=nvidia
# rd.driver.blacklist=nouveau
#   Prevents these drivers from loading in the initramfs.
#   Combined with nomodeset, this gives a guaranteed-working TTY.

# loglevel=7
#   Full debug logging — used in fallback to help diagnose boot issues.
