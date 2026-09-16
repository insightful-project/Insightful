#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"
PRODUCT="${1:-}"
SERVICE="${2:-}"

source "$ROOT_DIR/lib/banner.sh"
source "$ROOT_DIR/lib/box.sh"

# compose() is provided by lib/podman.sh (sourced via lib/banner.sh → lib/mode.sh)
compose_logs()
{
    local yml="$COMPOSE_DIR/$1"
    if [[ -n "$SERVICE" ]]; then
        compose "$yml" logs -f "$SERVICE"
    else
        compose "$yml" logs -f
    fi
}

case "$PRODUCT" in
    (life-os) compose_logs lifeos.yml ;;
    (odysseus) compose_logs odysseus.yml ;;
    (n8n) compose_logs n8n.yml ;;
    (ollama) compose_logs ollama.yml ;;
    (npm) compose_logs npm.yml ;;
    (code-server) compose_logs code-server.yml ;;
    (hub) compose_logs insightful-hub.yml ;;
    (redis) compose_logs redis.yml ;;
    (observability|obs) compose_logs observability.yml ;;
    (codespace) compose_logs codespace.yml ;;
    (cloudbeaver|cb) compose_logs cloudbeaver.yml ;;
    (oauth2) compose_logs oauth2.yml ;;
    (*)
        echo -e "  ${C}┌${BOX}┐${N}"
        echo -e "  ${C}│${N}  ${W}logs.sh — Tail container logs${N}$(printf '%*s' $((BW - 33)) '')${C}│${N}"
        echo -e "  ${C}├${BOX}┤${N}"
        echo -e "  ${C}│${N}${D}  Usage: ./logs.sh <product> [service]${N}$(printf '%*s' $((BW - 40)) '')${C}│${N}"
        echo -e "  ${C}│${N}${D}  Example: ./logs.sh life-os api-nest${N}$(printf '%*s' $((BW - 38)) '')${C}│${N}"
        echo -e "  ${C}├${BOX}┤${N}"
        echo -e "  ${C}│${N}  ${Y}Products:${N}${D} life-os odysseus n8n ollama npm code-server redis observability codespace cloudbeaver oauth2 hub${N}$(printf '%*s' $((BW - 118)) '')${C}│${N}"
        echo -e "  ${C}└${BOX}┘${N}"
        exit 1
        ;;
esac
