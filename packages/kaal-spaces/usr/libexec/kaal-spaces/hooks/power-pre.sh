#!/bin/bash
# Pre-enter hook for Power User Space
set -euo pipefail

# Enable verbose logging
echo 1 > /proc/sys/kernel/printk 2>/dev/null || true

# Start SSH if configured
systemctl start sshd.service 2>/dev/null || true

logger -t kaal-spaces "Power User space pre-enter hook completed"
