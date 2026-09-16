#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"

# Parse flags (--dry-run, --force, --recreate) that may appear at any position
DRY_RUN=0
INSIGHTFUL_FORCE=0
INSIGHTFUL_RECREATE=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        (--dry-run|--plan)  DRY_RUN=1 ;;
        (--force)           INSIGHTFUL_FORCE=1 ;;
        (--recreate)        INSIGHTFUL_RECREATE=1 ;;
        (*)                 ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]}"

PRODUCT="${1:-}"
MODE="${2:-prod}"

source "$ROOT_DIR/lib/banner.sh"

# ── Helpers ─────────────────────────────────────────────────────────
# _stack_containers, _stack_label, _stack_ports

# compose() is provided by lib/podman.sh (sourced via lib/banner.sh → lib/mode.sh)
# Usage: compose "compose/lifeos.yml" up -d

# Map compose file → container names for that stack.
_stack_containers()
{
    local yml="$1"
    local -n _out="$2"
    case "$yml" in
        (redis.yml)          _out=( "insightful-redis" ) ;;
        (ollama.yml)         _out=( "insightful-ollama" ) ;;
        (lifeos.yml)         _out=( "lifeos-db" "lifeos-api-nest" "lifeos-vue-app" ) ;;
        (odysseus.yml)       _out=( "odysseus" "odysseus-chromadb" "odysseus-searxng" "odysseus-ntfy" ) ;;
        (n8n.yml)            _out=( "n8n-db" "n8n" ) ;;
        (npm.yml)            _out=( "npm" ) ;;
        (code-server.yml)    _out=( "insightful-code-server" ) ;;
        (insightful-hub.yml) _out=( "insightful-hub" ) ;;
        (codespace.yml)      _out=( "codespace-db" "codespace-java" ) ;;
        (observability.yml)  _out=( "insightful-loki" "insightful-grafana" ) ;;
        (cloudbeaver.yml)    _out=( "lifeos-cloudbeaver" ) ;;
        (oauth2.yml)         _out=( "oauth-n8n" "oauth-codeserver" "oauth-odysseus" "oauth-cloudbeaver" "oauth-grafana" "oauth-hub" ) ;;
        (*)                  _out=( ) ;;
    esac
}

# Human-readable label for a compose file.
# Usage: label=$(_stack_label "lifeos.yml")   # → "LifeOS"
_stack_label()
{
    local yml="$1"
    case "$yml" in
        (redis.yml)          echo "Redis" ;;
        (ollama.yml)         echo "Ollama" ;;
        (lifeos.yml)         echo "LifeOS" ;;
        (odysseus.yml)       echo "Odysseus" ;;
        (n8n.yml)            echo "n8n" ;;
        (npm.yml)            echo "NPM" ;;
        (code-server.yml)    echo "code-server" ;;
        (insightful-hub.yml) echo "Hub" ;;
        (codespace.yml)      echo "codeSpace" ;;
        (observability.yml)  echo "Observability" ;;
        (cloudbeaver.yml)    echo "CloudBeaver" ;;
        (oauth2.yml)         echo "OAuth2" ;;
        (*)                  echo "${yml%.yml}" ;;
    esac
}

# Host ports exposed by a compose file (default values).
# Usage: _stack_ports "lifeos.yml" ports   # populates array $ports
_stack_ports()
{
    local yml="$1"
    local -n _out="$2"
    case "$yml" in
        (redis.yml)          _out=( 6379 ) ;;
        (ollama.yml)         _out=( 11434 ) ;;
        (lifeos.yml)         _out=( 5434 4001 3002 ) ;;
        (odysseus.yml)       _out=( 7000 8100 8080 8091 ) ;;
        (n8n.yml)            _out=( 5435 5678 ) ;;
        (npm.yml)            _out=( 80 81 ) ;;
        (code-server.yml)    _out=( 8081 ) ;;
        (insightful-hub.yml) _out=( 3003 ) ;;
        (codespace.yml)      _out=( 5436 ) ;;  # only DB exposed, Java is internal
        (observability.yml)  _out=( 3100 3000 ) ;;
        (cloudbeaver.yml)    _out=( "${CB_PORT:-8978}" ) ;;
        (oauth2.yml)         _out=( ) ;;  # internal only, no host ports
        (*)                  _out=( ) ;;
    esac
}

# ── Port & Container Checks ─────────────────────────────────────────
# _check_ports, stack_exists, stack_up

# Check if any host ports are already in use, print warnings.
# Returns 0 if all clear, 1 if conflicts found (unless --force).
_check_ports()
{
    local yml="$1"
    local -a ports
    _stack_ports "$yml" ports
    [[ ${#ports[@]} -eq 0 ]] && return 0

    local conflicts=()
    for port in "${ports[@]}"; do
        local in_use=0
        # Try /dev/tcp (bash built-in, may be disabled in some builds)
        if timeout 1 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
            in_use=1
        elif command -v ss &>/dev/null; then
            # Fallback: ss -tlnp
            ss -tlnp "sport = :$port" 2>/dev/null | grep -q ":$port" && in_use=1
        elif command -v netstat &>/dev/null; then
            netstat -tlnp 2>/dev/null | grep -q ":$port " && in_use=1
        fi
        if [[ "$in_use" -eq 1 ]]; then
            conflicts+=( "$port" )
        fi
    done

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo -e "  ${Y}⚠ Port conflict: ${R}${conflicts[*]}${N}" >&2
        echo -e "  ${D}  Already in use by another process${N}" >&2
        echo -e "  ${D}  Use env vars to change ports (see compose/.env)${N}" >&2
        return 1
    fi
    return 0
}

# Check if all containers for a compose project exist AND are running.
# Returns 0 if every container exists and is running, 1 otherwise.
stack_exists()
{
    local yml="$1"
    local -a containers
    _stack_containers "$yml" containers
    [[ ${#containers[@]} -eq 0 ]] && return 1
    for cname in "${containers[@]}"; do
        local state
        state=$($PODMAN inspect "$cname" --format '{{.State.Status}}' 2>/dev/null || echo "absent")
        [[ "$state" != "running" ]] && return 1
    done
    return 0
}

# ── Stale Container Cleanup ───────────────────────────────────────────
# Remove containers that exist but aren't running, to prevent name
# conflicts when a container was previously created by a different
# compose project (e.g. lifeos-cloudbeaver from old lifeos.yml).
_clean_stale_containers()
{
    local yml="$1"
    local -a containers
    _stack_containers "$yml" containers
    for cname in "${containers[@]}"; do
        if $PODMAN container exists "$cname" 2>/dev/null; then
            local state
            state=$($PODMAN inspect "$cname" --format '{{.State.Status}}' 2>/dev/null || echo "absent")
            if [[ "$state" != "running" ]]; then
                $PODMAN rm -f "$cname" 2>/dev/null || true
            fi
        fi
    done
}

# Create + start a compose stack, skip if containers already running.
# Supports --dry-run, --force, and --recreate flags.
stack_up()
{
    local yml="$1"
    local label="$(_stack_label "$yml")"

    if [[ "$INSIGHTFUL_RECREATE" -eq 1 ]]; then
        echo -e "  ${D}[${label}] --recreate: recycling containers${N}"
        compose "$COMPOSE_DIR/$yml" down 2>&1 || echo -e "  ${Y}  (no containers to recycle)${N}"
    elif stack_exists "$yml"; then
        echo -e "  ${D}[${label}] Already running, skip${N}"
        return 0
    fi

    # Clean stale containers that exist but aren't running (e.g. from a
    # different compose project) to prevent name conflicts at compose up.
    _clean_stale_containers "$yml"

    if ! _check_ports "$yml"; then
        if [[ "${INSIGHTFUL_FORCE:-}" != "1" ]]; then
            echo -e "  ${D}  Set INSIGHTFUL_FORCE=1 or use --force to override${N}" >&2
            return 1
        fi
        echo -e "  ${Y}  --force set, starting anyway${N}"
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        local -a ports
        _stack_ports "$yml" ports
        echo -e "  ${D}[${label}] Would start on ports: ${C}${ports[*]}${N}"
        echo -e "  ${D}  containers:${N}"
        local -a cnames
        _stack_containers "$yml" cnames
        for cn in "${cnames[@]}"; do printf "  ${D}    - %s${N}\n" "$cn"; done
        return 0
    fi

    source "$ROOT_DIR/lib/spinner.sh"

    shift

    local -a containers
    _stack_containers "$yml" containers

    # Separate --build from compose args: run build step first with generous timeout,
    # then start containers (which is fast). This prevents timeout on slow WSL builds.
    local has_build=0
    local -a up_args=()
    for arg in "$@"; do
        if [[ "$arg" == "--build" ]]; then
            has_build=1
        else
            up_args+=("$arg")
        fi
    done

    if [[ "$has_build" -eq 1 ]]; then
        echo -e "  ${D}[${label}] Building images...${N}"
        local build_out; build_out=$(mktemp /tmp/compose-build.XXXXXX 2>/dev/null || echo "/tmp/compose-build.$$")
        compose "$COMPOSE_DIR/$yml" build >"$build_out" 2>&1 &
        local build_pid=$!
        if ! spinner "$build_pid" "${label} build"; then
            echo -e "  ${R}✗${N} ${label} build failed. Last output:"
            sed 's/^/    /' "$build_out" 2>/dev/null | tail -30
            rm -f "$build_out" 2>/dev/null
            return 1
        fi
        rm -f "$build_out" 2>/dev/null
    fi

    # Start containers (fast if images already built)
    local timeout=60
    # Build stacks can take slightly longer at startup too
    case "$yml" in
        (lifeos.yml)                           timeout=300 ;;
        (odysseus.yml|codespace.yml)            timeout=180 ;;
        (insightful-hub.yml|cloudbeaver.yml)     timeout=90  ;;
    esac

    # Capture compose output for error reporting
    local compose_out; compose_out=$(mktemp /tmp/compose-out.XXXXXX 2>/dev/null || echo "/tmp/compose-out.$$")
    compose "$COMPOSE_DIR/$yml" "${up_args[@]}" >"$compose_out" 2>&1 &
    local compose_pid=$!
    if ! stack_build "$compose_pid" "${label}" "$timeout" "${containers[@]}"; then
        local err_rc=$?
        echo -e "  ${R}✗${N} ${label} failed (exit ${err_rc}). Last compose output:"
        sed 's/^/    /' "$compose_out" 2>/dev/null | tail -20
        rm -f "$compose_out" 2>/dev/null
        return "$err_rc"
    fi
    rm -f "$compose_out" 2>/dev/null
}

# ── Stacks ──────────────────────────────────────────────────────────
# Each start* function creates the insightful network, then calls
# stack_up to bring up its compose file.  Some print access info.

# Start Ollama local LLM (Qwen 2.5:7b, GPU-enabled).
startOllama()
{
    $PODMAN network create insightful 2>/dev/null || true
    mkdir -p "$ROOT_DIR/data/ollama/models"
    local rc=0
    stack_up ollama.yml up -d || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} Ollama failed to start"
        return "$rc"
    fi
    echo ""
    echo "  Ollama:   http://localhost:11434  (Qwen 2.5:7b)"
    echo ""
    echo "  Logs:     $PODMAN compose -f compose/ollama.yml logs -f"
}

# Start Redis cache + rate limit store (shared by all stacks).
startRedis()
{
    $PODMAN network create insightful 2>/dev/null || true
    local rc=0
    stack_up redis.yml up -d || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} Redis failed to start"
        return "$rc"
    fi
    echo ""
    echo "  Redis:    localhost:6379  (cache + rate limit store + pub/sub)"
    echo ""
    echo "  Logs:     $PODMAN compose -f compose/redis.yml logs -f"
}

# Start Observability stack (Loki + Grafana).
# Loki stores logs from pino-loki transport; Grafana dashboards at port 3000.
startObservability()
{
    $PODMAN network create insightful 2>/dev/null || true
    local rc=0
    stack_up observability.yml up -d || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} Observability stack failed to start"
        return "$rc"
    fi
    echo ""
    echo "  Loki:     http://localhost:3100  (log storage)"
    echo "  Grafana:  http://localhost:3000  (dashboards — admin/admin)"
    echo ""
    echo "  Logs:     $PODMAN compose -f compose/observability.yml logs -f"
}

# Start LifeOS v2 stack (Postgres + NestJS API + Vue frontend).
# Supports modes: dev (hot-reload), prod (built images), db (data layer only).
startLifeOs()
{
    # ponytail: fail fast with clear message instead of cryptic container errors
    if [[ ! -f "$COMPOSE_DIR/.env" ]]; then
        echo -e "  ${R}✗${N} Missing $COMPOSE_DIR/.env — copy .env.example to .env and set JWT_SECRET" >&2
        return 1
    fi
    # shellcheck disable=SC1090
    JWT_SECRET=$(grep -E '^JWT_SECRET=' "$COMPOSE_DIR/.env" 2>/dev/null | cut -d= -f2- || true)
    if [[ -z "$JWT_SECRET" || "$JWT_SECRET" == "changeme" ]]; then
        echo -e "  ${R}✗${N} JWT_SECRET not set or still default 'changeme' in $COMPOSE_DIR/.env" >&2
        echo -e "  ${D}  Generate one: openssl rand -base64 48 | tr -d /=+ | cut -c1-64${N}" >&2
        return 1
    fi

    $PODMAN network create insightful 2>/dev/null || true
    case "$MODE" in
    (dev)
            if stack_exists lifeos.yml; then echo -e "  ${D}[LifeOS] Already running, skip${N}"; return; fi
            _clean_stale_containers lifeos.yml
            source "$ROOT_DIR/lib/spinner.sh"
            local base="$COMPOSE_DIR/lifeos.yml"
            local dev="$COMPOSE_DIR/../dev/ins1ght/products/life-os-v2/docker-compose.dev.yml"
            $PODMAN compose -f "$(_to_win "$base")" -f "$(_to_win "$dev")" up -d --build postgres api-nest vue-app >/tmp/lifeos-dev-build.log 2>&1 &
            local dev_pid=$!
            stack_build "$dev_pid" "LifeOS" 300 "lifeos-db" "lifeos-api-nest" "lifeos-vue-app"
            local dev_rc=$?
            if [[ "$dev_rc" -ne 0 ]]; then
                echo -e "  ${D}Build log (last 20 lines):${N}"
                sed 's/^/    /' /tmp/lifeos-dev-build.log 2>/dev/null | tail -20
                return 1
            fi
            echo ""
            echo "  API:      http://localhost:4001  (NestJS, hot-reload)"
            echo "  Frontend: http://localhost:3002  (Vue 3, hot-reload)"
            echo "  DB:       postgres://localhost:5434"
            echo ""
            echo "  Logs:     $PODMAN compose -f compose/lifeos.yml logs -f api-nest"
            ;;
        (prod)
            local rc=0
            stack_up lifeos.yml up -d --build || rc=$?
            if [[ "$rc" -ne 0 ]]; then
                echo -e "  ${R}✗${N} LifeOS failed to start"
                return "$rc"
            fi
            echo ""
            echo "  API:      http://localhost:4001  (NestJS)"
            echo "  Frontend: http://localhost:3002  (Vue 3)"
            echo "  DB:       postgres://localhost:5434"
            ;;
        (db)
            if stack_exists lifeos.yml; then echo -e "  ${D}[LifeOS] Already running, skip${N}"; return; fi
            _clean_stale_containers lifeos.yml
            source "$ROOT_DIR/lib/spinner.sh"
            compose lifeos.yml up -d postgres >/dev/null 2>&1 &
            local db_pid=$!
            stack_build "$db_pid" "LifeOS" 60 "lifeos-db"
            local db_rc=$?
            [[ "$db_rc" -ne 0 ]] && return 1
            echo ""
            echo "  DB:      postgres://localhost:5434"
            echo "  Run API: cd server && npm run dev"
            ;;
    (*)
            echo "Unknown mode: $MODE"
            echo "Modes: dev, prod, db"
            exit 1
            ;;
    esac
}

# Start Odysseus AI stack (LLM proxy + ChromaDB + SearXNG + ntfy).
startOdysseus()
{
    # ponytail: warn if admin password not set or still default
    if [[ -f "$COMPOSE_DIR/.env" ]]; then
        ODYSSEUS_ADMIN_PASSWORD=$(grep -E '^ODYSSEUS_ADMIN_PASSWORD=' "$COMPOSE_DIR/.env" 2>/dev/null | cut -d= -f2- || true)
    fi
    if [[ -z "${ODYSSEUS_ADMIN_PASSWORD}" || "${ODYSSEUS_ADMIN_PASSWORD}" == "changeme" ]]; then
        echo -e "  ${R}⚠${N} ODYSSEUS_ADMIN_PASSWORD not set or still default 'changeme' — set it in compose/.env"
    fi

    $PODMAN network create insightful 2>/dev/null || true
    mkdir -p "$ROOT_DIR/data/odysseus/chromadb" "$ROOT_DIR/data/odysseus/searxng" "$ROOT_DIR/data/odysseus/ntfy"
    local rc=0
    stack_up odysseus.yml up -d --build || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} Odysseus failed to start"
        return "$rc"
    fi
    echo ""
    echo "  Odysseus: http://localhost:7000"
    echo "  ChromaDB: http://localhost:8100"
    echo "  SearXNG:  http://localhost:8080"
    echo "  ntfy:     http://localhost:8091"
    echo ""
    echo "  Logs:     $PODMAN compose -f compose/odysseus.yml logs -f"
}

# Start n8n automation platform with its own Postgres database.
startN8n()
{
    $PODMAN network create insightful 2>/dev/null || true
    mkdir -p "$ROOT_DIR/data/n8n/postgres" "$ROOT_DIR/data/n8n/data"
    local rc=0
    stack_up n8n.yml up -d || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} n8n failed to start"
        return "$rc"
    fi
    echo ""
    echo "  n8n:    http://localhost:5678"
    echo "  DB:     postgres://localhost:5435"
    echo ""
    echo "  Logs:   $PODMAN compose -f compose/n8n.yml logs -f"
}

# Start Nginx Proxy Manager (reverse proxy with GUI on port 81).
startNpm()
{
    $PODMAN network create insightful 2>/dev/null || true
    mkdir -p "$ROOT_DIR/data/npm/data" "$ROOT_DIR/data/npm/ssl"
    local rc=0
    stack_up npm.yml up -d || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} NPM failed to start"
        return "$rc"
    fi
    echo ""
    echo "  Admin UI: http://localhost:81"
    echo "  Admin:    admin@insightful-projects.com"
    echo "  Default:  (set via NPM_ADMIN_PASSWORD env var, default: Insightful2026!)"
    echo ""
    echo "  Proxy hosts configured:"
    echo ""
    printf "  %-30s %-25s %s\n" "Domain" "Forward to" "Auth"
    printf "  %-30s %-25s %s\n" "──────────────────────────────" "─────────────────────────" "──────────────────────"
    printf "  %-30s %-25s %s\n" "api.insightful-projects.com" "api-nest:4001" "JWT (app)"
    printf "  %-30s %-25s %s\n" "vue.insightful-projects.com" "vue-app:3000" "JWT (app)"
    printf "  %-30s %-25s %s\n" "n8n.insightful-projects.com" "oauth-n8n:4180" "Google SSO (strict)"
    printf "  %-30s %-25s %s\n" "odysseus.insightful-projects.com" "oauth-odysseus:4180" "Google SSO (strict)"
    printf "  %-30s %-25s %s\n" "hub.insightful-projects.com" "oauth-hub:4180" "Google SSO (domain)"
    printf "  %-30s %-25s %s\n" "cloudbeaver.insightful-projects.com" "oauth-cloudbeaver:4180" "Google SSO (strict)"
    printf "  %-30s %-25s %s\n" "code.insightful-projects.com" "oauth-codeserver:4180" "Google SSO (strict)"
    printf "  %-30s %-25s %s\n" "grafana.insightful-projects.com" "oauth-grafana:4180" "Google SSO (domain)"
    printf "  %-30s %-25s %s\n" "searxng.insightful-projects.com" "searxng:8080" "none"
    printf "  %-30s %-25s %s\n" "chromadb.insightful-projects.com" "chromadb:8000" "none"
    printf "  %-30s %-25s %s\n" "ntfy.insightful-projects.com" "ntfy:80" "none"
    printf "  %-30s %-25s %s\n" "ollama.insightful-projects.com" "insightful-ollama:11434" "none"
    printf "  %-30s %-25s %s\n" "npm.insightful-projects.com" "npm:81" "NPM admin"
    echo ""
    echo "  All domains resolve to 127.0.0.1 via Windows hosts file."
    echo "  Configure SSL in NPM Admin UI (port 81) once your domain goes live."
}

# Start code-server (web-based VS Code IDE).
startCodeServer()
{
    # ponytail: fail fast if password not set or still default
    if [[ -f "$COMPOSE_DIR/.env" ]]; then
        CODE_SERVER_PASSWORD=$(grep -E '^CODE_SERVER_PASSWORD=' "$COMPOSE_DIR/.env" 2>/dev/null | cut -d= -f2- || true)
    fi
    if [[ -z "${CODE_SERVER_PASSWORD}" || "${CODE_SERVER_PASSWORD}" == "changeme" ]]; then
        echo -e "  ${R}⚠${N} CODE_SERVER_PASSWORD not set or still default 'changeme' — set it in compose/.env"
    fi

    $PODMAN network create insightful 2>/dev/null || true
    local rc=0
    stack_up code-server.yml up -d || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} code-server failed to start"
        return "$rc"
    fi
    echo ""
    echo "  code-server: http://localhost:${CODE_SERVER_PORT:-8081}"
    echo "  Password:    ${CODE_SERVER_PASSWORD:-changeme}"
    echo "  Workspace:   /workspace (project root)"
    echo ""
    echo "  Logs:        $PODMAN compose -f compose/code-server.yml logs -f"
}

# Start codeSpace backend (Postgres + Java entity-based RPC service).
# No host port for Java — only accessible via Docker internal network.
# DB port (5436) exposed for CloudBeaver/manual data management.
startCodeSpace()
{
    $PODMAN network create insightful 2>/dev/null || true
    mkdir -p "$ROOT_DIR/data/codespace/logs"

    # Start the codeSpace stack (Postgres + Java)
    local rc=0
    stack_up codespace.yml up -d --build || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} codeSpace failed to start"
        return "$rc"
    fi

    echo ""
    echo "  codeSpace Java:  http://codespace-java:7500  (Docker internal only)"
    echo "  DB:              postgres://localhost:5436/codespace"
    echo "  Schema:          code_space_process"
    echo ""
    echo "  Access:"
    echo "    API via code-server:   curl http://codespace-java:7500/api/codex/logs"
    echo "    DB GUI (CloudBeaver):  http://localhost:${CB_PORT:-8978}"
    echo "                             → Server: codespace-db:5432"
    echo "                             → Database: codespace  User: codespace_user"
    echo "                             → Password: from compose/.env (CODESPACE_DB_PASSWORD)"
    echo ""
    echo "  Logs:            $PODMAN compose -f compose/codespace.yml logs -f"
}

# Start CloudBeaver database GUI (shared by Life OS, codeSpace, etc).
# Connects to any Postgres on the insightful network.
startCloudBeaver()
{
    $PODMAN network create insightful 2>/dev/null || true
    mkdir -p "$ROOT_DIR/data/lifeos/cloudbeaver"  # shared workspace dir

    # Idempotent: skip if already running (called by multiple start* functions)
    if stack_exists cloudbeaver.yml; then
        echo -e "  ${D}[CloudBeaver] Already running, skip${N}"
        return 0
    fi

    local rc=0
    stack_up cloudbeaver.yml up -d --build || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} CloudBeaver failed to start"
        return "$rc"
    fi
    echo ""
    echo "  CloudBeaver:     http://localhost:${CB_PORT:-8978}"
    echo "  Workspace:       $ROOT_DIR/data/lifeos/cloudbeaver/"
    echo ""
    echo "  ┌─ Connect to a database ─────────────────────────────────────────────────────────────────────┐"
    echo "  │  Server:   <db-container>:5432                                                              │"
    echo "  │  Database: <db-name>                                                                        │"
    echo "  │                                                                                             │"
    echo "  │  Life OS:   lifeos-db:5432 / lifeos / lifeos_user                                          │"
    echo "  │  codeSpace: codespace-db:5432 / codespace / codespace_user                                 │"
    echo "  │  n8n:       n8n-db:5432 / insightful_n8n / insightful_n8n                                  │"
    echo "  │                                                                                             │"
    echo "  │  Password: from compose/.env (DB_PASSWORD / CODESPACE_DB_PASSWORD / N8N_DB_PASSWORD)        │"
    echo "  └─────────────────────────────────────────────────────────────────────────────────────────────┘"
    echo ""
}

# Start OAuth2 Proxy sidecars (Google SSO for dashboard services).
# Requires OAUTH2_GOOGLE_CLIENT_ID, OAUTH2_GOOGLE_CLIENT_SECRET, OAUTH2_COOKIE_SECRET in .env.
startOauth2()
{
    $PODMAN network create insightful 2>/dev/null || true
    local rc=0
    stack_up oauth2.yml up -d || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} OAuth2 sidecars failed to start"
        echo -e "  ${D}  Set OAUTH2_GOOGLE_CLIENT_ID/SECRET and OAUTH2_COOKIE_SECRET in compose/.env${N}"
        return "$rc"
    fi
    echo ""
    echo "  OAuth2 Proxy sidecars running for:"
    echo "    n8n, code-server, Odysseus, CloudBeaver (strict allowlist)"
    echo "    Grafana, Hub (domain: @insightful-projects.com)"
    echo ""
    echo "  Run bin/npm-oauth-setup.sh to configure NPM proxy hosts."
}

# Start Insightful Hub (service registry + health monitor).
startInsightfulHub()
{
    $PODMAN network create insightful 2>/dev/null || true
    mkdir -p "$ROOT_DIR/data/hub"
    local rc=0
    stack_up insightful-hub.yml up -d --build || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo -e "  ${R}✗${N} Hub failed to start"
        return "$rc"
    fi
    echo ""
    echo "  Hub:  http://localhost:3003"
    echo "  Domain: http://hub.insightful-projects.com"
}

# Start all stacks in sequence, with optional ntfy notification.
startAll()
{
    banner_main "BOOT SEQUENCE"
    echo -e "  \033[2;37mInitializing all stacks...\033[0m"
    echo ""

    $PODMAN network create insightful 2>/dev/null || true

    # Ensure all data directories exist (for bind mounts)
    mkdir -p "$ROOT_DIR/data/n8n/postgres" "$ROOT_DIR/data/n8n/data"
    mkdir -p "$ROOT_DIR/data/ollama/models"
    mkdir -p "$ROOT_DIR/data/npm/data" "$ROOT_DIR/data/npm/ssl"
    mkdir -p "$ROOT_DIR/data/hub"
    mkdir -p "$ROOT_DIR/data/codespace/logs"

    startOllama || true
    echo ""
    startRedis || true
    echo ""
    startObservability || true
    echo ""
    startLifeOs || true
    echo ""
    startN8n || true
    echo ""
    startNpm || true
    echo ""
    startCodeServer || true
    echo ""
    startInsightfulHub || true
    echo ""
    startCodeSpace || true
    echo ""
    startCloudBeaver || true
    echo ""
    startOauth2 || true
    echo ""

    banner_main "ALL SYSTEMS NOMINAL"
    echo -e "  \033[2;37mNPM:  http://localhost:80    Status: ./status.sh --live\033[0m"
    echo -e "  \033[2;37mHub:  http://localhost:3003  Stop:   ./stop.sh all\033[0m"

    if [[ "$DRY_RUN" -eq 0 ]]; then
        source "$ROOT_DIR/lib/notify.sh"
        notify "Insightful: all stacks online"
    fi
}


# ── Dispatch ─────────────────────────────────────────────────────────
# Routes $PRODUCT to the correct start* function.
# Default (no args) runs status.sh.

case "$PRODUCT" in
    (all)
        startAll
        ;;
    (life-os)
        startLifeOs
        ;;
    (odysseus)
        startOdysseus
        ;;
    (n8n)
        startN8n
        ;;
    (redis)
        startRedis
        ;;
    (observability|obs)
        startObservability
        ;;
    (ollama)
        startOllama
        ;;
    (npm)
        startNpm
        ;;
    (code-server|codeserver)
        startCodeServer
        ;;
    (hub)
        startInsightfulHub
        ;;
    (codespace)
        startCodeSpace
        ;;
    (cloudbeaver|cb)
        startCloudBeaver
        ;;
    (oauth2)
        startOauth2
        ;;
    (dev)
        MODE=dev
        startAll
        ;;
    (live|--live|watch|--watch)
        source "$ROOT_DIR/lib/dash.sh"
        live_dash "${2:-3}"
        ;;
    (mode)
        source "$ROOT_DIR/lib/mode.sh"
        echo "Current mode: $INSIGHTFUL_MODE"
        echo "Set with:  echo 'live' > ~/.insightful-mode"
        echo "           echo 'dev'  > ~/.insightful-mode"
        ;;
    (status|"")
        if [[ "$DRY_RUN" -eq 1 ]]; then
            banner_main "DRY RUN"
            echo -e "  ${D}Showing what would start (use --force to override port checks)${N}"
            echo ""
            startAll
            exit 0
        fi
        "$ROOT_DIR/status.sh"
        ;;
    (*)
        echo "Usage: ./start.sh <product> [mode] [flags]"
        echo ""
        echo "Flags:"
        echo "  --dry-run   Show what would start without doing it"
        echo "  --force     Override port conflict warnings"
        echo "  --recreate  Destroy + recreate containers even if running"
        echo ""
        echo "Products:"
        echo "  all         Start everything (full stack)"
        echo "  dev         Start ALL stacks in dev mode (hot-reload)"
        echo "  life-os     Life OS v2 (Postgres + API + Frontend)"
        echo "  odysseus    Odysseus AI (AI + ChromaDB + SearXNG + ntfy)"
        echo "  n8n         n8n automation + its own Postgres"
        echo "  redis       Redis cache / rate limit store (port 6379)"
        echo "  observability Loki + Grafana log aggregation (ports 3100, 3000)"
        echo "  ollama      Ollama local LLM (Qwen 2.5:7b with GPU)"
        echo "  code-server Browser-based VS Code IDE (port 8081)"
        echo "  npm         Nginx Proxy Manager (Web UI for reverse proxy)"
        echo "  hub         Insightful Hub (service registry + health monitor)"
        echo "  codespace   codeSpace Java backend (Postgres + entity RPC service)"
        echo "  cloudbeaver DB GUI (CloudBeaver) — shared by Life OS, codeSpace, etc."
        echo "  oauth2      OAuth2 Proxy sidecars (Google SSO)"
        echo "  live        Live dashboard with streaming container stats"
        echo "  mode        Show current machine mode (live/dev)"
        echo "  status      Show running services (default)"
        echo ""
        echo "Modes (life-os only, when using start + life-os):"
        echo "  dev         Development — NestJS hot-reloads on code changes"
        echo "  prod        Production — built images, all frontends (default)"
        echo "  db          Database only — run API on host via npm run dev"
        echo ""
        echo "Examples:"
        echo "  ./start.sh              # same as ./status.sh"
        echo "  ./start.sh dev          # all stacks, hot-reload on life-os"
        echo "  ./start.sh all          # start everything (prod mode)"
        echo "  ./start.sh all --recreate # force recreate all containers"
        echo "  ./start.sh live         # live container dashboard"
        echo "  ./start.sh life-os dev  # life-os dev stack with hot-reload"
        echo "  ./start.sh odysseus     # Odysseus stack"
        echo "  ./start.sh n8n          # n8n + Postgres"
        echo "  ./start.sh npm          # Nginx Proxy Manager (port 81)"
        exit 1
        ;;
esac
