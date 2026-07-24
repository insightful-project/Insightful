#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"
PRODUCT="${1:-all}"

source "$ROOT_DIR/lib/banner.sh"
source "$ROOT_DIR/lib/box.sh"

# ponytail: associative array dispatch. Add new stacks here.
declare -A STACKS=(
    [life-os]=lifeos.yml
    [odysseus]=odysseus.yml
    [n8n]=n8n.yml
    [qdrant]=qdrant.yml
    [ollama]=ollama.yml
    [npm]=npm.yml
    [code-server]=code-server.yml
    [hub]=insightful-hub.yml
    [codespace]=codespace.yml
    [cloudbeaver]=cloudbeaver.yml
    [oauth2]=oauth2.yml
    [redis]=redis.yml
    [observability]=observability.yml
)
declare -A ALIASES=( [codeserver]=code-server [cb]=cloudbeaver [obs]=observability )
ORDER=( npm code-server oauth2 n8n redis observability life-os hub codespace cloudbeaver odysseus ollama qdrant )

_stop()
{
    local label="$1" yml="$2"
    echo -e "  ${C}│${N}  ${D}Stopping ${C}${label}${N}..."
    if ! compose_stop "$COMPOSE_DIR/$yml" 2>&1; then
        echo -e "  ${C}│${N}    ${Y}(not running)${N}"
    else
        echo -e "  ${C}│${N}    ${G}done${N}"
    fi
}

if [ "$PRODUCT" = "all" ]; then
    banner_main "SHUTDOWN SEQUENCE"
    source "$ROOT_DIR/lib/notify.sh"
    notify "Insightful: shutting down all stacks"
    echo ""
    echo -e "  ${C}┌${BOX}┐${N}"
    echo -e "  ${C}│${N}  ${W}SHUTTING DOWN STACKS${N}$(printf '%*s' $((BW - 22)) '')${C}│${N}"
    echo -e "  ${C}├${BOX}┤${N}"
    for key in "${ORDER[@]}"; do
        _stop "$key" "${STACKS[$key]}"
    done
    echo -e "  ${C}└${BOX}┘${N}"
    echo ""
    banner_main "SERVICES HALTED"
else
    alias="${ALIASES[$PRODUCT]:-}"
    key="${alias:-$PRODUCT}"
    yml="${STACKS[$key]:-}"
    if [ -z "$yml" ]; then
        echo -e "  ${C}┌${BOX}┐${N}"
        echo -e "  ${C}│${N}  ${R}Unknown product: ${PRODUCT}${N}$(printf '%*s' $((BW - 20 - ${#PRODUCT})) '')${C}│${N}"
        echo -e "  ${C}├${BOX}┤${N}"
        echo -e "  ${C}│${N}  ${D}Usage: ./stop.sh [product]${N}$(printf '%*s' $((BW - 29)) '')${C}│${N}"
        echo -e "  ${C}│${N}  ${D}Products: ${Y}${!STACKS[*]}${N} ${D}all${N}$(printf '%*s' $((BW - 38 - ${#STACKS[*]})) '')${C}│${N}"
        echo -e "  ${C}│${N}  ${D}Examples: ./stop.sh oauth2${N}$(printf '%*s' $((BW - 32)) '')${C}│${N}"
        echo -e "  ${C}└${BOX}┘${N}"
        exit 1
    fi
    echo -e "  ${C}┌${BOX}┐${N}"
    _stop "$key" "$yml"
    echo -e "  ${C}└${BOX}┘${N}"
fi
