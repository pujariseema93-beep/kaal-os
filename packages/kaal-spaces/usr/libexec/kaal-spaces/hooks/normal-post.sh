#!/bin/bash
# Post-enter hook for Normal Space
set -euo pipefail

# Enable power saving features
if [[ -f /sys/devices/system/cpu/intel_pstate/status ]]; then
    echo "active" > /sys/devices/system/cpu/intel_pstate/status 2>/dev/null || true
fi

# Set conservative CPU governor for battery savings
for dir in /sys/devices/system/cpu/cpu*/cpufreq; do
    [[ -d "$dir" ]] && echo "powersave" > "$dir/scaling_governor" 2>/dev/null || true
done

logger -t kaal-spaces "Normal space post-enter hook completed"
