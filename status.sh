#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT_DIR/lib/banner.sh"
source "$ROOT_DIR/lib/box.sh"
source "$ROOT_DIR/lib/health-urls.sh"

# ── Live Dashboard Dispatch ─────────────────────────────────────────
case "${1:-}" in
    (--live|-w|--watch)
        source "$ROOT_DIR/lib/dash.sh"
        live_dash "${2:-3}"
        exit 0
        ;;
esac

banner_main

# ── Container table ──
echo -e "  ${C}┌${BOX}┐${N}"
echo -e "  ${C}│${N}  ${W}PODMAN CONTAINERS${N}$(printf '%*s' $((BW - 18)) '')${C}│${N}"
echo -e "  ${C}├${BOX}┤${N}"

container_output=$($PODMAN ps --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null || true)
if [[ -n "$container_output" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf "  ${C}│${N}  %-$((BW - 5))s ${C}│${N}\n" "$line"
    done <<< "$container_output"
else
    printf "  ${C}│${N}  %-$((BW - 2))s ${C}│${N}\n" "(no containers running)"
fi
echo -e "  ${C}└${BOX}┘${N}"
echo ""

# ── Health checks ──
echo -e "  ${C}┌${BOX}┐${N}"
echo -e "  ${C}│${N}  ${W}HEALTH CHECKS${N}$(printf '%*s' $((BW - 14)) '')${C}│${N}"
echo -e "  ${C}├${BOX}┤${N}"

for pair in "${HEALTH_URLS[@]}"; do
    name="${pair%%|*}"
    url="${pair##*|}"
    icon=

    if [[ "$url" == tcp://* ]]; then
        hostport="${url#tcp://}"
        host="${hostport%%:*}"
        port="${hostport##*:}"
        if timeout 1 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
            icon="${G}●${N}"
        else
            icon="${R}○${N}"
        fi
    else
        if command -v curl &>/dev/null && curl -sf "$url" >/dev/null 2>&1; then
            icon="${G}●${N}"
        else
            icon="${R}○${N}"
        fi
    fi

    printf "  ${C}│${N}  %b %-18s %-45s ${C}│${N}\n" "$icon" "$name" "$url"
done

echo -e "  ${C}└${BOX}┘${N}"
echo ""
echo -e "  ${D}Commands: ./start.sh <product>  ./stop.sh <product>  ./status.sh --live${N}"
