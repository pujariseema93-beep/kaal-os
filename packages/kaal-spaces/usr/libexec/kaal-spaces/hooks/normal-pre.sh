#!/bin/bash
# Pre-enter hook for Normal Space
set -euo pipefail

# Restore default swappiness
echo 60 > /proc/sys/vm/swappiness 2>/dev/null || true

# Stop resource-heavy services
systemctl stop docker.service 2>/dev/null || true
systemctl stop libvirtd.service 2>/dev/null || true
systemctl stop cockpit.socket 2>/dev/null || true

logger -t kaal-spaces "Normal space pre-enter hook completed"
