#!/bin/bash
# Pre-exit hook for Gaming Space
# Cleanup before leaving gaming space

set -euo pipefail

# Restore swappiness
echo 60 > /proc/sys/vm/swappiness 2>/dev/null || true

# Kill any lingering game processes (optional — user may want to keep them)
# We DON'T kill Steam/games here — let the user decide

logger -t kaal-spaces "Gaming space pre-exit hook completed"
