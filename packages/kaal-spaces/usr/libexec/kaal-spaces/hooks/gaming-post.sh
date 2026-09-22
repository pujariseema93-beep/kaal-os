#!/bin/bash
# Post-enter hook for Gaming Space
# Final touches after switching to gaming

set -euo pipefail

# Ensure GameMode daemon is running
if command -v gamemoded &>/dev/null; then
    gamemoded --daemon &
fi

# Preload Steam libraries into memory for faster launch
if command -v ldconfig &>/dev/null; then
    ldconfig 2>/dev/null || true
fi

# Set swappiness to lower value (prioritize apps over cache)
echo 10 > /proc/sys/vm/swappiness 2>/dev/null || true

# Enable transparent hugepages for game performance
echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true

logger -t kaal-spaces "Gaming space post-enter hook completed"
