#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"
PRODUCT="${1:-}"
SERVICE="${2:-}"

source "$ROOT_DIR/lib/banner.sh"
source "$ROOT_DIR/lib/box.sh"

# compose() is provided by lib/podman.sh (sourced via lib/banner.sh → lib/mode.sh)

# ── Helpers ──────────────────────────────────────────────────────────

# Check if all containers for a compose file are running.
# Mirrors stack_exists from start.sh.
_stack_ok()
{
    local yml="$1"
    # Static container list per compose file (same as start.sh)
    local -a containers
    case "$yml" in
        (lifeos.yml)         containers=( "lifeos-db" "lifeos-api-nest" "lifeos-vue-app" ) ;;
        (codespace.yml)      containers=( "codespace-db" "codespace-java" ) ;;
        (cloudbeaver.yml)    containers=( "lifeos-cloudbeaver" ) ;;
        (odysseus.yml)       containers=( "odysseus" "odysseus-chromadb" "odysseus-searxng" "odysseus-ntfy" ) ;;
        (n8n.yml)            containers=( "n8n-db" "n8n" ) ;;
        (redis.yml)          containers=( "insightful-redis" ) ;;
        (observability.yml)  containers=( "insightful-loki" "insightful-grafana" ) ;;
        (ollama.yml)         containers=( "insightful-ollama" ) ;;
        (npm.yml)            containers=( "npm" ) ;;
        (code-server.yml)    containers=( "insightful-code-server" ) ;;
        (insightful-hub.yml) containers=( "insightful-hub" ) ;;
        (oauth2.yml)         containers=( "oauth-n8n" "oauth-codeserver" "oauth-odysseus" "oauth-cloudbeaver" "oauth-grafana" "oauth-hub" ) ;;
        (*)                  return 1 ;;
    esac
    [[ ${#containers[@]} -eq 0 ]] && return 1
    for cname in "${containers[@]}"; do
        local state
        state=$($PODMAN inspect "$cname" --format '{{.State.Status}}' 2>/dev/null || echo "absent")
        [[ "$state" != "running" ]] && return 1
    done
    return 0
}

# ── Reboot ──────────────────────────────────────────────────────────

# Destroy and recreate a stack: compose down → start.sh fresh up → verify.
reboot()
{
    local label="$1" yml="$2"
    echo -e "  ${C}│${N}  ${D}Recycling containers for ${C}${label}${N}..."
    compose "$COMPOSE_DIR/$yml" down 2>&1 || echo -e "  ${C}│${N}    ${Y}(nothing to recycle)${N}"
    echo -e "  ${C}│${N}  ${D}Starting fresh ${Y}${label}${N}..."
    "$ROOT_DIR/start.sh" "$label"
    local rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${C}│${N}    ${R}✗ start.sh failed (exit $rc)${N}"
        return "$rc"
    fi
    if _stack_ok "$yml"; then
        echo -e "  ${C}│${N}    ${G}● Running${N}"
    else
        echo -e "  ${C}│${N}    ${R}○ Not all containers running${N}"
    fi
}

# ── Dispatch ──────────────────────────────────────────────────────

case "$PRODUCT" in
    (life-os)    echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}life-os${N}$(printf '%*s' $((BW - 18)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "life-os"    lifeos.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (odysseus)   echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}odysseus${N}$(printf '%*s' $((BW - 18)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "odysseus"   odysseus.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (n8n)        echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}n8n${N}$(printf '%*s' $((BW - 14)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "n8n"        n8n.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (ollama)     echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}ollama${N}$(printf '%*s' $((BW - 16)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "ollama"     ollama.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (npm)        echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}npm${N}$(printf '%*s' $((BW - 12)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "npm"        npm.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (code-server) echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}code-server${N}$(printf '%*s' $((BW - 20)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "code-server" code-server.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (hub)        echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}hub${N}$(printf '%*s' $((BW - 12)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "hub"        insightful-hub.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (codespace)  echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}codespace${N}$(printf '%*s' $((BW - 18)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "codespace"  codespace.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (cloudbeaver|cb) echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}cloudbeaver${N}$(printf '%*s' $((BW - 20)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "cloudbeaver" cloudbeaver.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (redis)      echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}redis${N}$(printf '%*s' $((BW - 14)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "redis"         redis.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (observability|obs) echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}observability${N}$(printf '%*s' $((BW - 22)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "observability" observability.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (oauth2)     echo -e "  ${C}┌${BOX}┐${N}"; echo -e "  ${C}│${N}  ${W}Rebuilding ${C}oauth2${N}$(printf '%*s' $((BW - 14)) '')${C}│${N}"; echo -e "  ${C}├${BOX}┤${N}"; reboot "oauth2"        oauth2.yml; echo -e "  ${C}└${BOX}┘${N}" ;;
    (all)
        banner_main "REBOOT ALL"
        local failures=0
        echo ""
        echo -e "  ${C}┌${BOX}┐${N}"
        echo -e "  ${C}│${N}  ${W}RECYCLING ALL STACKS${N}$(printf '%*s' $((BW - 22)) '')${C}│${N}"
        echo -e "  ${C}├${BOX}┤${N}"
        for pair in "ollama|ollama.yml" "redis|redis.yml" "observability|observability.yml" "life-os|lifeos.yml" "n8n|n8n.yml" "odysseus|odysseus.yml" "npm|npm.yml" "code-server|code-server.yml" "codespace|codespace.yml" "cloudbeaver|cloudbeaver.yml" "hub|insightful-hub.yml" "oauth2|oauth2.yml"; do
            label="${pair%%|*}"
            yml="${pair#*|}"
            echo -e "  ${C}│${N}"
            reboot "$label" "$yml" || ((failures++))
        done
        echo -e "  ${C}└${BOX}┘${N}"
        echo ""
        if [[ "$failures" -eq 0 ]]; then
            banner_main "ALL SYSTEMS NOMINAL"
            source "$ROOT_DIR/lib/notify.sh"
            notify "Insightful: all stacks rebuilt"
        else
            banner_main "REBOOT PARTIAL ($failures FAILED)"
            source "$ROOT_DIR/lib/notify.sh"
            notify "Insightful: $failures stacks failed to rebuild"
        fi
        echo ""
        "$ROOT_DIR/status.sh"
        ;;
    (*)
        echo "Usage: ./rebuild.sh <product> [service]"
        echo ""
        echo "Products:"
        echo "  all           Recycle ALL stacks (down + fresh up → verify)"
        echo "  life-os       Recycle Life OS stack"
        echo "  odysseus      Recycle Odysseus stack"
        echo "  n8n           Recycle n8n stack"
        echo "  redis         Recycle Redis stack"
        echo "  observability Recycle Loki + Grafana stack (or: obs)"
        echo "  ollama        Recycle Ollama stack"
        echo "  hub           Recycle Insightful Hub"
        echo "  codespace     Recycle CodeSpace stack"
        echo "  cloudbeaver   Recycle CloudBeaver (or: cb)"
        echo "  npm           Recycle Nginx Proxy Manager"
        echo "  oauth2        Recycle OAuth2 Proxy sidecars"
        echo ""
        echo "This destroys containers then starts fresh via ./start.sh"
        echo "Use for a clean restart when containers are misbehaving."
        exit 1
        ;;
esac
