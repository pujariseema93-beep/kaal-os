#!/bin/bash
# Pre-enter hook for Gaming Space
# Save current state before switching

set -euo pipefail

# Save current audio settings
if command -v pw-cli &>/dev/null; then
    pw-cli info 0 2>/dev/null | grep -q "quantum" && \
        cat /etc/pipewire/client.conf.d/50-kaal-space.conf 2>/dev/null | \
        grep quantum > /var/lib/kaal/spaces/last-audio-quantum || true
fi

# Kill resource-heavy background processes (docker containers, VMs)
if command -v docker &>/dev/null; then
    docker stop $(docker ps -q) 2>/dev/null || true
fi

logger -t kaal-spaces "Gaming space pre-enter hook completed"
