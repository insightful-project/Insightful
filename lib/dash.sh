#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/banner.sh"
source "$ROOT_DIR/lib/health-urls.sh"

health_icon()
{
    local url="$1"
    if curl -sf "$url" >/dev/null 2>&1; then
        echo -e "${G}●${N}"
    else
        echo -e "${R}○${N}"
    fi
}

container_row()
{
    local name="$1" cpu="$2" mem="$3"
    printf "  │ %-22s %-7s %-12s │\n" "$name" "${cpu}%" "${mem}%"
}

dash_containers()
{
    echo -e "  ${C}┌──────────────────────────────────────────────┐${N}"
    echo -e "  ${C}│${N}  ${W}CONTAINER           CPU     MEMORY        ${C}│${N}"
    echo -e "  ${C}├──────────────────────────────────────────────┤${N}"

    local data
    data=$($PODMAN stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}" 2>/dev/null || true)
    if [[ -z "$data" ]]; then
        echo -e "  ${C}│${N}  ${D}(no containers)                             ${C}│${N}"
    else
        echo "$data" | while IFS=$'\t' read -r name cpu mem; do
            container_row "$name" "$cpu" "$mem"
        done
    fi
    echo -e "  ${C}└──────────────────────────────────────────────┘${N}"
}

dash_health()
{
    echo -e "  ${C}┌──────────────────────────────────────────────┐${N}"
    echo -e "  ${C}│${N}  ${W}HEALTH CHECKS                              ${C}│${N}"
    echo -e "  ${C}├──────────────────────────────────────────────┤${N}"
    for pair in "${HEALTH_URLS[@]}"; do
        local name="${pair%%|*}"
        local url="${pair##*|}"
        local icon
        icon=$(health_icon "$url")
        printf "  ${C}│${N}  %s %-22s %-26s ${C}│${N}\n" "$icon" "$name" "$url"
    done
    echo -e "  ${C}└──────────────────────────────────────────────┘${N}"
}

live_dash()
{
    local interval="${1:-3}"
    while true; do
        clear
        banner_main
        dash_containers
        echo ""
        dash_health
        echo ""
        echo -e "  ${D}Refreshing every ${interval}s · Ctrl+C to exit${N}"
        sleep "$interval"
    done
}
