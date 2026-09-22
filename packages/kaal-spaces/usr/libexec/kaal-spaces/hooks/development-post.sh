#!/bin/bash
# Post-enter hook for Development Space
set -euo pipefail

# Start distrobox default containers if any exist
if command -v distrobox &>/dev/null; then
    # List running containers, don't auto-start — let user choose
    true
fi

# Enable core dumps for debugging
ulimit -c unlimited 2>/dev/null || true

logger -t kaal-spaces "Development space post-enter hook completed"
