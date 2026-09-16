#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT_DIR/lib/banner.sh"
source "$ROOT_DIR/lib/box.sh"

# Map product to its container names
_containers()
{
    local product="$1"
    local -n _out="$2"
    case "$product" in
        (ollama)      _out=( "insightful-ollama" ) ;;
        (life-os)     _out=( "lifeos-db" "lifeos-api-nest" "lifeos-vue-app" ) ;;
        (odysseus)    _out=( "odysseus" "odysseus-chromadb" "odysseus-searxng" "odysseus-ntfy" ) ;;
        (n8n)         _out=( "n8n-db" "n8n" ) ;;
        (npm)         _out=( "npm" ) ;;
        (code-server) _out=( "insightful-code-server" ) ;;
        (hub)         _out=( "insightful-hub" ) ;;
        (codespace)   _out=( "codespace-db" "codespace-java" ) ;;
        (cloudbeaver) _out=( "lifeos-cloudbeaver" ) ;;
        (redis)       _out=( "insightful-redis" ) ;;
        (observability) _out=( "insightful-loki" "insightful-grafana" ) ;;
        (oauth2)      _out=( "oauth-n8n" "oauth-codeserver" "oauth-odysseus" "oauth-cloudbeaver" "oauth-grafana" "oauth-hub" ) ;;
        (*)           _out=( ) ;;
    esac
}

PRODUCT="${1:-}"
SERVICE="${2:-}"

if [[ -z "$PRODUCT" ]]; then
    echo -e "  ${C}┌${BOX}┐${N}"
    echo -e "  ${C}│${N}  ${W}restart.sh — Restart containers (faster than rebuild)${N}$(printf '%*s' $((BW - 54)) '')${C}│${N}"
    echo -e "  ${C}├${BOX}┤${N}"
    echo -e "  ${C}│${N}${D}  Usage: ./restart.sh <product> [service]${N}$(printf '%*s' $((BW - 44)) '')${C}│${N}"
    echo -e "  ${C}│${N}${D}  Example: ./restart.sh life-os api-nest${N}$(printf '%*s' $((BW - 42)) '')${C}│${N}"
    echo -e "  ${C}├${BOX}┤${N}"
    echo -e "  ${C}│${N}  ${Y}Products:${N}${D} ollama life-os odysseus n8n npm code-server hub codespace cloudbeaver redis observability oauth2${N}$(printf '%*s' $((BW - 108)) '')${C}│${N}"
    echo -e "  ${C}└${BOX}┘${N}"
    exit 1
fi

declare -a containers
_containers "$PRODUCT" containers

if [[ ${#containers[@]} -eq 0 ]]; then
    echo -e "  ${C}┌${BOX}┐${N}"
    echo -e "  ${C}│${N}  ${R}Unknown product: ${PRODUCT}${N}$(printf '%*s' $((BW - 20 - ${#PRODUCT})) '')${C}│${N}"
    echo -e "  ${C}└${BOX}┘${N}"
    exit 1
fi

echo -e "  ${C}┌${BOX}┐${N}"
echo -e "  ${C}│${N}  ${W}Restarting ${C}${PRODUCT}${N}${N}$(printf '%*s' $((BW - 16 - ${#PRODUCT})) '')${C}│${N}"
echo -e "  ${C}├${BOX}┤${N}"

restart_one()
{
    local cname="$1"
    echo -e "  ${C}│${N}    ${D}[${cname}]${N}"
    if $PODMAN container exists "$cname" 2>/dev/null; then
        if $PODMAN restart "$cname" >/dev/null 2>&1; then
            echo -e "  ${C}│${N}      ${G}restarted${N}"
        else
            echo -e "  ${C}│${N}      ${R}failed${N}"
        fi
    else
        echo -e "  ${C}│${N}      ${Y}not running${N}"
    fi
}

if [[ -n "$SERVICE" ]]; then
    # Map service shorthand to full container name
    found=""
    for cname in "${containers[@]}"; do
        if [[ "$cname" == *"$SERVICE"* ]]; then
            found="$cname"
            break
        fi
    done
    if [[ -z "$found" ]]; then
        echo -e "  ${C}│${N}    ${R}No container matching '${SERVICE}' in ${PRODUCT}${N}"
        echo -e "  ${C}│${N}    ${D}Available: ${containers[*]}${N}"
        echo -e "  ${C}└${BOX}┘${N}"
        exit 1
    fi
    restart_one "$found"
else
    for cname in "${containers[@]}"; do
        restart_one "$cname"
    done
fi
echo -e "  ${C}└${BOX}┘${N}"
