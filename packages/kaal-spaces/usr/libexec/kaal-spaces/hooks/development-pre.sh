#!/bin/bash
# Pre-enter hook for Development Space
set -euo pipefail

# Restore swappiness to default (compilers benefit from caching)
echo 60 > /proc/sys/vm/swappiness 2>/dev/null || true

# Ensure Docker daemon is ready
if command -v docker &>/dev/null; then
    systemctl start docker.service 2>/dev/null || true
fi

logger -t kaal-spaces "Development space pre-enter hook completed"
