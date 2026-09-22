#!/bin/bash
# KAAL OS — Space Apply Script
# Reads a space configuration file and applies all system settings.
# Usage: apply-space.sh <space_name>

set -euo pipefail

SPACE_NAME="${1:-}"
SPACES_DIR="/etc/kaal/spaces"
SPACE_CONF="${SPACES_DIR}/${SPACE_NAME}.conf"
LOG_TAG="kaal-spaces"

log() {
    logger -t "$LOG_TAG" "$1"
    echo "[$LOG_TAG] $1" >&2
}

if [[ -z "$SPACE_NAME" ]]; then
    echo "Usage: $0 <space_name>" >&2
    exit 1
fi

if [[ ! -f "$SPACE_CONF" ]]; then
    log "Error: Space config not found: $SPACE_CONF"
    exit 1
fi

log "Applying space: $SPACE_NAME"

# ============================================================================
# Helper: read config value
# ============================================================================
get_conf() {
    local section="$1"
    local key="$2"
    local default="${3:-}"
    local value

    value=$(awk -F= -v sec="\\[$section\\]" -v key="$key" '
        $0 ~ sec { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && $1 ~ "^\\s*" key "\\s*$" {
            gsub(/^\s+|\s+$/, "", $2)
            print $2
            exit
        }
    ' "$SPACE_CONF")

    echo "${value:-$default}"
}


# ============================================================================
# User-session helpers
# ============================================================================
# gsettings must run in the user's session context, not as root.
# Find the active graphical user and run commands through them.
run_as_user() {
    local cmd="$1"
    local user
    user=$(loginctl list-sessions --no-legend 2>/dev/null | \
        awk '/seat/ {print $3; exit}')
    [[ -z "$user" ]] && user="${SUDO_USER:-}"
    [[ -z "$user" || "$user" == "root" ]] && return 0

    if command -v runuser &>/dev/null; then
        runuser -u "$user" -- bash -c "$cmd" 2>/dev/null || true
    elif command -v sudo &>/dev/null; then
        sudo -u "$user" bash -c "$cmd" 2>/dev/null || true
    fi
}

# ============================================================================
# CPU Governor
# ============================================================================
apply_cpu_governor() {
    local governor
    governor=$(get_conf system cpu_governor "balanced")

    # Available CPUs
    local cpu_dirs=()
    for dir in /sys/devices/system/cpu/cpu*/cpufreq; do
        [[ -d "$dir" ]] && cpu_dirs+=("$dir")
    done

    if [[ ${#cpu_dirs[@]} -eq 0 ]]; then
        log "No CPU freq directories found, skipping governor"
        return 0
    fi

    # Map our names to kernel governor names
    case "$governor" in
        performance|powersave|schedutil|userspace|ondemand|conservative)
            for dir in "${cpu_dirs[@]}"; do
                local avail
                avail=$(cat "$dir/scaling_available_governors" 2>/dev/null || echo "")
                if echo "$avail" | grep -qw "$governor"; then
                    echo "$governor" > "$dir/scaling_governor" 2>/dev/null || true
                    log "Set CPU governor to $governor"
                else
                    log "Governor $governor not available on this CPU"
                fi
            done
            ;;
        balanced)
            # Try schedutil first, fall back to ondemand, then powersave
            for fallback_gov in schedutil ondemand powersave; do
                for dir in "${cpu_dirs[@]}"; do
                    local avail
                    avail=$(cat "$dir/scaling_available_governors" 2>/dev/null || echo "")
                    if echo "$avail" | grep -qw "$fallback_gov"; then
                        echo "$fallback_gov" > "$dir/scaling_governor" 2>/dev/null || true
                        break
                    fi
                done
                # Check if we successfully set it
                local current
                current=$(cat "${cpu_dirs[0]}/scaling_governor" 2>/dev/null || echo "")
                [[ "$current" == "$fallback_gov" ]] && break
            done
            log "Set CPU governor to balanced (auto-selected)"
            ;;
        *)
            log "Unknown governor: $governor"
            ;;
    esac

    # Energy performance preference (Intel)
    local epp
    epp=$(get_conf system cpu_energy_perf "balance_performance")
    for dir in /sys/devices/system/cpu/cpu*/cpufreq; do
        [[ -f "$dir/energy_performance_preference" ]] && \
            echo "$epp" > "$dir/energy_performance_preference" 2>/dev/null || true
    done

    # Intel P-State performance
    if [[ -f /sys/devices/system/cpu/intel_pstate/status ]]; then
        case "$governor" in
            performance)
                echo "performance" > /sys/devices/system/cpu/intel_pstate/status 2>/dev/null || true
                ;;
            *)
                echo "active" > /sys/devices/system/cpu/intel_pstate/status 2>/dev/null || true
                ;;
        esac
    fi
}

# ============================================================================
# GPU Power Profile
# ============================================================================
apply_gpu_power() {
    local profile
    profile=$(get_conf system gpu_power_profile "auto")
    local force_dedicated
    force_dedicated=$(get_conf system gpu_force_dedicated "false")

    # NVIDIA
    if command -v nvidia-smi &>/dev/null; then
        case "$profile" in
            performance)
                nvidia-smi -pm 1 2>/dev/null || true
                nvidia-smi --query-gpu=clocks.max.gr,clocks.max.mem \
                    --format=csv,noheader 2>/dev/null || true
                log "NVIDIA: set to performance mode"
                ;;
            balanced|auto)
                nvidia-smi -pm 1 2>/dev/null || true
                # Let driver manage clocks
                log "NVIDIA: set to balanced mode"
                ;;
        esac
    fi

    # AMD — via sysfs
    for card in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [[ -f "$card" ]] || continue
        case "$profile" in
            performance)
                echo "high" > "$card" 2>/dev/null || true
                log "AMD GPU: set to high performance"
                ;;
            balanced|auto)
                echo "auto" > "$card" 2>/dev/null || true
                log "AMD GPU: set to auto"
                ;;
        esac
    done

    # NVIDIA optimus/PRIME — force dedicated GPU if requested
    if [[ "$force_dedicated" == "true" ]] && command -v nvidia-smi &>/dev/null; then
        if [[ -f /etc/X11/xorg.conf.d/10-nvidia.conf ]]; then
            log "NVIDIA PRIME: dedicated GPU already configured"
        else
            cat > /etc/X11/xorg.conf.d/10-nvidia-dynamic.conf << 'EOF'
Section "ServerLayout"
    Identifier "layout"
    Screen 0 "nvidia"
    Inactive "intel"
EndSection

Section "Device"
    Identifier "nvidia"
    Driver "nvidia"
    BusID "PCI:0:1:0"  # Adjust per system
EndSection
EOF
            log "NVIDIA PRIME: created dynamic config for dedicated GPU"
        fi
    fi
}

# ============================================================================
# Audio (PipeWire)
# ============================================================================
apply_audio() {
    local quantum
    quantum=$(get_conf system audio_quantum "256")
    local rate
    rate=$(get_conf system audio_rate "48000")

    # Create per-space PipeWire config overlay
    local pw_conf_dir="/etc/pipewire/client.conf.d"
    mkdir -p "$pw_conf_dir"

    cat > "${pw_conf_dir}/50-kaal-space.conf" << PIPEWIREEOF
# KAAL Space: $SPACE_NAME
# Audio quantum: $quantum samples at $rate Hz
context.properties = {
    default.clock.rate = $rate
    default.clock.quantum = $quantum
    default.clock.min-quantum = $quantum
    default.clock.max-quantum = $quantum
}
PIPEWIREEOF

    log "PipeWire config: quantum=$quantum rate=$rate"

    # Restart PipeWire to apply
    if command -v systemctl &>/dev/null; then
        systemctl --user restart wireplumber.service 2>/dev/null || true
        systemctl --user restart pipewire.service 2>/dev/null || true
        systemctl --user restart pipewire-pulse.service 2>/dev/null || true
        log "PipeWire restarted with new settings"
    fi
}

# ============================================================================
# Services
# ============================================================================
apply_services() {
    local enable_str disable_str restart_str
    enable_str=$(get_conf services enable "")
    disable_str=$(get_conf services disable "")
    restart_str=$(get_conf services restart "")

    # Enable services
    if [[ -n "$enable_str" ]]; then
        IFS=', ' read -ra svcs <<< "$enable_str"
        for svc in "${svcs[@]}"; do
            [[ -z "$svc" ]] && continue
            systemctl enable --now "$svc" 2>/dev/null || \
                log "Could not enable $svc (may not be installed)"
            log "Enabled service: $svc"
        done
    fi

    # Disable services
    if [[ -n "$disable_str" ]]; then
        IFS=', ' read -ra svcs <<< "$disable_str"
        for svc in "${svcs[@]}"; do
            [[ -z "$svc" ]] && continue
            systemctl disable --now "$svc" 2>/dev/null || \
                log "Could not disable $svc (may not be running)"
            log "Disabled service: $svc"
        done
    fi

    # Restart services
    if [[ -n "$restart_str" ]]; then
        IFS=', ' read -ra svcs <<< "$restart_str"
        for svc in "${svcs[@]}"; do
            [[ -z "$svc" ]] && continue
            systemctl restart "$svc" 2>/dev/null || \
                log "Could not restart $svc"
            log "Restarted service: $svc"
        done
    fi
}

# ============================================================================
# Desktop Environment
# ============================================================================
apply_desktop() {
    local wallpaper panel_layout
    wallpaper=$(get_conf desktop wallpaper "")
    panel_layout=$(get_conf desktop panel_layout "normal")

    # Set wallpaper via gsettings (GNOME) or plasma-apply-wallpaperimage (KDE)
    if [[ -n "$wallpaper" ]] && [[ -f "$wallpaper" ]]; then
        # GNOME
        if command -v gsettings &>/dev/null; then
            run_as_user "gsettings set org.gnome.desktop.background picture-uri 'file://$wallpaper'"
            run_as_user "gsettings set org.gnome.desktop.background picture-uri-dark 'file://$wallpaper'"
            log "GNOME wallpaper set"
        fi

        # KDE Plasma
        if command -v plasma-apply-wallpaperimage &>/dev/null; then
            run_as_user "plasma-apply-wallpaperimage '$wallpaper'"
            log "KDE wallpaper set"
        fi
    fi

    # Write current space to environment for DE scripts to read
    echo "SPACE=$SPACE_NAME" > /run/kaal/space-env
    echo "PANEL_LAYOUT=$panel_layout" >> /run/kaal/space-env

    # Panel layout profiles are applied by DE-specific scripts
    local panel_script="/usr/libexec/kaal-spaces/panels/${panel_layout}.sh"
    if [[ -f "$panel_script" ]]; then
        bash "$panel_script" 2>/dev/null || true
        log "Panel layout applied: $panel_layout"
    fi
}

# ============================================================================
# Environment Variables
# ============================================================================
apply_environment() {
    local env_file="/run/kaal/space-env"

    # Parse [environment] section and write to env file
    awk -F= '
        /^\[environment\]/ { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && /=/ {
            gsub(/^\s+|\s+$/, "", $1)
            gsub(/^\s+|\s+$/, "", $2)
            printf "%s=%s\n", $1, $2
        }
    ' "$SPACE_CONF" >> "$env_file"

    log "Environment variables written to $env_file"

    # Also write to /etc/environment.d for session-level persistence
    local envd_dir="/etc/environment.d"
    mkdir -p "$envd_dir"
    awk -F= '
        /^\[environment\]/ { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && /=/ {
            gsub(/^\s+|\s+$/, "", $1)
            gsub(/^\s+|\s+$/, "", $2)
            printf "%s=%s\n", $1, $2
        }
    ' "$SPACE_CONF" > "${envd_dir}/50-kaal-space.conf"
}

# ============================================================================
# Notifications
# ============================================================================
apply_notifications() {
    local notif_mode
    notif_mode=$(get_conf system notifications "normal")

    case "$notif_mode" in
        dnd)
            # GNOME
            run_as_user "gsettings set org.gnome.desktop.notifications show-banner false"
            # KDE
            "$KWRITECONFIG" --file ~/.config/plasmarc --group Notifications --key DoNotDisturb true 2>/dev/null || true
            log "Notifications: Do Not Disturb"
            ;;
        minimal|normal|all)
            run_as_user "gsettings set org.gnome.desktop.notifications show-banner true"
            "$KWRITECONFIG" --file ~/.config/plasmarc --group Notifications --key DoNotDisturb false 2>/dev/null || true
            log "Notifications: $notif_mode"
            ;;
    esac
}

# ============================================================================
# Network QoS (gaming traffic prioritization)
# ============================================================================
apply_network_qos() {
    local qos
    qos=$(get_conf system network_qos "false")

    if [[ "$qos" == "true" ]]; then
        # Enable network QoS for gaming (prioritize UDP game traffic)
        if command -v tc &>/dev/null; then
            # Find default network interface
            local iface
            iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
            if [[ -n "$iface" ]]; then
                # Simple HTB QoS: prioritize small UDP packets (game traffic)
                tc qdisc add dev "$iface" root handle 1: htb default 20 2>/dev/null || true
                tc class add dev "$iface" parent 1: classid 1:1 htb rate 1000mbit 2>/dev/null || true
                tc class add dev "$iface" parent 1:1 classid 1:10 htb rate 500mbit prio 0 2>/dev/null || true
                tc class add dev "$iface" parent 1:1 classid 1:20 htb rate 500mbit prio 1 2>/dev/null || true
                tc filter add dev "$iface" parent 1: protocol ip u32 \
                    match ip protocol 17 0xffff \
                    flowid 1:10 2>/dev/null || true  # UDP -> high priority
                log "Network QoS enabled on $iface (game traffic prioritized)"
            fi
        fi
    else
        # Remove any existing QoS rules
        local iface
        iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
        if [[ -n "$iface" ]]; then
            tc qdisc del dev "$iface" root 2>/dev/null || true
            log "Network QoS disabled"
        fi
    fi
}

# ============================================================================
# Bluetooth
# ============================================================================
apply_bluetooth() {
    local bt_mode
    bt_mode=$(get_conf system bluetooth "on")

    case "$bt_mode" in
        on)
            systemctl enable --now bluetooth.service 2>/dev/null || true
            log "Bluetooth: enabled"
            ;;
        off)
            systemctl disable --now bluetooth.service 2>/dev/null || true
            log "Bluetooth: disabled"
            ;;
    esac
}

# ============================================================================
# Compositor Effects
# ============================================================================
apply_compositor() {
    local effects vsync
    effects=$(get_conf system compositor_effects "true")
    vsync=$(get_conf system compositor_vsync "true")

    # GNOME — mutter
    if command -v gsettings &>/dev/null; then
        if [[ "$effects" == "true" ]]; then
            run_as_user "gsettings set org.gnome.desktop.interface enable-animations true"
        else
            run_as_user "gsettings set org.gnome.desktop.interface enable-animations false"
        fi
    fi

    # KDE — kwin
    # Plasma 6 renamed kwriteconfig5 to kwriteconfig6 — detect the right one
KWRITECONFIG="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"

if [[ -n "$KWRITECONFIG" ]]; then
        local animations="true"
        [[ "$effects" == "false" ]] && animations="false"
        "$KWRITECONFIG" --file ~/.config/kwinrc --group Compositing \
            --key OpenGLIsUnsafe "$([[ "$vsync" == "false" ]] && echo true || echo false)" 2>/dev/null || true
    fi

    log "Compositor: effects=$effects vsync=$vsync"
}

# ============================================================================
# SSH (Power User space)
# ============================================================================
apply_ssh() {
    local ssh_enabled
    ssh_enabled=$(get_conf system network_ssh "false")

    if [[ "$ssh_enabled" == "true" ]]; then
        systemctl enable --now sshd.service 2>/dev/null || true
        log "SSH: enabled"
    else
        systemctl disable --now sshd.service 2>/dev/null || true
        log "SSH: disabled"
    fi
}

# ============================================================================
# Main
# ============================================================================
log "=== Applying $SPACE_NAME space ==="

apply_cpu_governor
apply_gpu_power
apply_audio
apply_services
apply_desktop
apply_environment
apply_notifications
apply_network_qos
apply_bluetooth
apply_compositor
apply_ssh

log "=== Space $SPACE_NAME applied successfully ==="
