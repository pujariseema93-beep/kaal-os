#!/bin/bash
# Post-enter hook for Power User Space
set -euo pipefail

# Start cockpit web management if installed
systemctl start cockpit.socket 2>/dev/null || true

# Enable sysstat (system statistics collection)
systemctl start sysstat-collect.service 2>/dev/null || true

logger -t kaal-spaces "Power User space post-enter hook completed"
