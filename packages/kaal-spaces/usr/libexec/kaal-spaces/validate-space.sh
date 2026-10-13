#!/bin/bash
# KAAL OS — Space Configuration Validator
#
# Checks a space config against the schema the engine actually reads, and reports
# what is wrong BEFORE anything is applied. Without this, a typo is silently
# ignored (unknown keys are never read) or applied as-is (a bad enum value), and
# the only symptom is a space that quietly does not do what it says.
#
# Usage: validate-space.sh <space_name|path-to-conf>
#
# Exit codes:  0 = valid (warnings allowed)   1 = invalid (errors found)
#
# This does not apply anything. It only reads and reports.

set -uo pipefail

TARGET="${1:-}"
SPACES_DIR="/etc/kaal/spaces"
TEMPLATES_DIR="/usr/share/kaal/spaces/templates"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 <space_name|path-to-conf>" >&2
    exit 1
fi

# Resolve the target: a path, an installed space, or a template.
if [[ -f "$TARGET" ]]; then
    CONF="$TARGET"
elif [[ -f "${SPACES_DIR}/${TARGET}.conf" ]]; then
    CONF="${SPACES_DIR}/${TARGET}.conf"
elif [[ -f "${TEMPLATES_DIR}/${TARGET}.conf" ]]; then
    CONF="${TEMPLATES_DIR}/${TARGET}.conf"
else
    echo "validate: no such space or file: ${TARGET}" >&2
    exit 1
fi

ERRORS=0
WARNINGS=0
err()  { echo "  ERROR   $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "  warning $1"; WARNINGS=$((WARNINGS + 1)); }

# ---- the schema, exactly as the engine reads it -------------------------------
KNOWN_SECTIONS="space system services desktop environment hooks rules"

# Keys the engine reads. [environment] and [rules] are deliberately open: the
# first is arbitrary env vars, the second is app names the auto-switcher matches.
KNOWN_KEYS_space="name description icon color"
KNOWN_KEYS_system="cpu_governor cpu_energy_perf gpu_power_profile gpu_force_dedicated audio_quantum audio_rate compositor_effects compositor_vsync network_qos network_ssh notifications bluetooth"
KNOWN_KEYS_services="enable disable restart"
KNOWN_KEYS_desktop="wallpaper panel_layout app_menu_filter pinned_apps show_categories hide_categories"
KNOWN_KEYS_hooks="pre_enter post_enter pre_exit post_exit"

# Enumerated values, taken from what apply-space.sh actually understands.
ENUM_cpu_governor="performance powersave schedutil ondemand conservative"
ENUM_cpu_energy_perf="performance balance_performance balance_power power"
ENUM_gpu_power_profile="auto balanced performance powersave"
ENUM_notifications="all normal dnd minimal off silent"
BOOL_KEYS="gpu_force_dedicated compositor_effects compositor_vsync network_qos network_ssh"
ENUM_bluetooth="on off"
NUM_KEYS="audio_quantum audio_rate"

has_word() { # has_word <needle> <space-separated haystack>
    local n="$1" w
    for w in $2; do [[ "$w" == "$n" ]] && return 0; done
    return 1
}

echo "Validating: ${CONF}"

# ---- parse into section|key|value triples -------------------------------------
section=""
declare -A seen_sections=()
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip full-line comments and blank lines. Inline '#' is NOT stripped: these
    # configs use none, and stripping it would eat the '#' of every hex colour
    # (color = #FF6B35 would read as an empty value).
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
        section="${BASH_REMATCH[1]}"
        seen_sections["$section"]=1
        if ! has_word "$section" "$KNOWN_SECTIONS"; then
            err "unknown section [$section] — the engine will not read it"
        fi
        continue
    fi

    if [[ ! "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
        err "not a key = value line: ${line}"
        continue
    fi
    key="${BASH_REMATCH[1]}"
    value="$(printf '%s' "${BASH_REMATCH[2]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if [[ -z "$section" ]]; then
        err "key '${key}' appears before any [section]"
        continue
    fi

    # section-specific checks
    case "$section" in
        space|system|services|desktop|hooks)
            local_known="KNOWN_KEYS_${section}"
            if ! has_word "$key" "${!local_known}"; then
                warn "unknown key '${key}' in [$section] — the engine will ignore it"
            fi
            ;;
        environment)
            # env var names: the engine exports these, so the name must be one
            # the shell would accept (letters, digits, underscore)
            [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || \
                err "invalid environment variable name: ${key}"
            ;;
        rules)
            : # app names are free-form; only the control keys below are checked
            ;;
    esac

    # value checks for enumerated keys
    for e in cpu_governor cpu_energy_perf gpu_power_profile notifications bluetooth; do
        if [[ "$key" == "$e" ]]; then
            enumvar="ENUM_${e}"
            if ! has_word "$value" "${!enumvar}"; then
                err "[$section] ${key} = '${value}' is not one of: ${!enumvar}"
            fi
        fi
    done

    # booleans
    if has_word "$key" "$BOOL_KEYS" && [[ "$value" != "true" && "$value" != "false" ]]; then
        err "[$section] ${key} = '${value}' must be true or false"
    fi

    # numbers
    if has_word "$key" "$NUM_KEYS" && ! [[ "$value" =~ ^[0-9]+$ ]]; then
        err "[$section] ${key} = '${value}' must be a whole number"
    fi

    # colour
    if [[ "$key" == "color" ]] && ! [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        err "[$section] color = '${value}' must be a #RRGGBB hex value"
    fi

    # services must look like unit names
    if [[ "$section" == "services" ]]; then
        IFS=',' read -ra units <<< "$value"
        for u in "${units[@]}"; do
            u="$(printf '%s' "$u" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            [[ -z "$u" ]] && continue
            if ! [[ "$u" =~ \.(service|timer|socket|target|mount|path)$ ]]; then
                warn "[services] ${key}: '${u}' does not end in a systemd unit suffix"
            fi
        done
        unset IFS
    fi

    # paths the engine will use must exist (a missing wallpaper is a silent no-op)
    case "$key" in
        icon|wallpaper|pre_enter|post_enter|pre_exit|post_exit)
            if [[ -n "$value" && "$value" != /* ]]; then
                warn "[$section] ${key} = '${value}' is not an absolute path"
            elif [[ -n "$value" && ! -e "$value" ]]; then
                warn "[$section] ${key}: ${value} does not exist"
            fi
            ;;
    esac

    # rules control keys
    if [[ "$section" == "rules" ]]; then
        case "$key" in
            enabled)          [[ "$value" == "true" || "$value" == "false" ]] || err "[rules] enabled must be true or false" ;;
            on_ac|on_battery)
                              if [[ -n "${SPACES_DIR:-}" && ! -f "${SPACES_DIR}/${value}.conf" ]]; then
                                  warn "[rules] ${key} = '${value}' does not match any installed space"
                              fi ;;
            cooldown_seconds) [[ "$value" =~ ^[0-9]+$ ]] || err "[rules] cooldown_seconds must be a whole number" ;;
            evening_start|evening_end)
                              # a bare hour, 0-23 — not HH:MM
                              [[ "$value" =~ ^([0-9]|1[0-9]|2[0-3])$ ]] || err "[rules] ${key} = '${value}' should be an hour 0-23" ;;
            evening_time)
                              # names the space to switch to in the evening
                              if [[ -n "${SPACES_DIR:-}" && ! -f "${SPACES_DIR}/${value}.conf" ]]; then
                                  warn "[rules] evening_time = '${value}' does not match any installed space"
                              fi ;;
        esac
    fi
done < "$CONF"

# ---- required bits -----------------------------------------------------------
# Two kinds of file live in this directory:
#   - a space:      has a [space] section
#   - auto-switch:  the rules file, which has [rules] and deliberately no [space]
if [[ -n "${seen_sections[space]:-}" ]]; then
    grep -qE '^[[:space:]]*name[[:space:]]*=' "$CONF" || err "[space] has no name"
elif [[ -n "${seen_sections[rules]:-}" ]]; then
    grep -qE '^[[:space:]]*enabled[[:space:]]*=' "$CONF" || err "[rules] has no enabled switch"
else
    err "neither a [space] section nor a [rules] section — nothing would read this file"
fi

# ---- report ------------------------------------------------------------------
echo
if [[ "$ERRORS" -gt 0 ]]; then
    echo "INVALID: ${ERRORS} error(s), ${WARNINGS} warning(s). Nothing has been changed."
    exit 1
fi
if [[ "$WARNINGS" -gt 0 ]]; then
    echo "Valid: no errors, ${WARNINGS} warning(s). Warnings mean something will be ignored."
    exit 0
fi
echo "Valid: ${CONF} matches the schema."
exit 0
