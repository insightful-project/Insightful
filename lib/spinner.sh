# ── Terminal Spinner + Progress Bar ──
# Source after lib/banner.sh

# Load container runtime abstraction
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SELF_DIR/podman.sh"

# Track compose + container startup. Shows `<spin> <label> [bar] N%  (Ts)`.
# Bar climbs 0-80% during compose (time-based), then 0-100% post-compose
# from actual running container count.
# Usage: stack_build $! "LifeOS" 60 "lifeos-db" "lifeos-api-nest" ...
# Returns 0 when all running, 1 on compose failure, 2 on timeout.
stack_build()
{
    local compose_pid=$1 label="$2" timeout="$3"
    shift 3
    local -a names=("$@")
    local total=${#names[@]}
    local compose_done=0
    SECONDS=0

    while ((SECONDS < timeout)); do
        local running=0
        for cname in "${names[@]}"; do
            local state
            state=$($PODMAN inspect "$cname" --format '{{.State.Status}}' 2>/dev/null || true)
            [[ "$state" == "running" ]] && ((running++))
        done

        local pct=0
        if kill -0 "$compose_pid" 2>/dev/null; then
            pct=$(( SECONDS * 80 / timeout ))
            [[ "$pct" -gt 80 ]] && pct=80
        else
            if [[ "$compose_done" -eq 0 ]]; then
                compose_done=1
                local rc=0
                wait "$compose_pid" 2>/dev/null || rc=$?
                if [[ "$rc" -ne 0 ]]; then
                    echo ""
                    return "$rc"
                fi
            fi
            [[ "$total" -gt 0 ]] && pct=$((running * 100 / total))
        fi

        progress "$label" "$pct" "$SECONDS"

        if [[ "$running" -ge "$total" ]] && [[ "$total" -gt 0 ]]; then
            printf "\r  ${G}●${N} ${C}%-18s${N} ${G}●${N}  ${D}(%ds)${N}\033[K\n" "$label" "$SECONDS"
            return 0
        fi

        sleep 0.2
    done

    echo ""
    echo -e "  ${R}✗${N} Timed out after ${timeout}s. Failed containers:"
    for cname in "${names[@]}"; do
        local state
        state=$($PODMAN inspect "$cname" --format '{{.State.Status}}' 2>/dev/null || echo "absent")
        echo -e "  ${D}  -${N} ${cname} ${R}[${state}]${N}"
    done
    return 2
}

# Spinner — animated character while a background PID runs.
# Shows: `| LifeOS building... (5s)`
# Usage: spinner $! "LifeOS"
# Returns the PID's exit code.
spinner()
{
    local pid=$1 msg="${2:-Loading...}"
    local spin='|/-\'
    SECONDS=0

    while kill -0 "$pid" 2>/dev/null; do
        for ((i=0; i<${#spin}; i++)); do
            printf "\r  ${C}%s${N} %s... ${D}(%ds)${N}\033[K" "${spin:$i:1}" "$msg" "$SECONDS"
            sleep 0.08
        done
    done

    local rc=0
    wait "$pid" 2>/dev/null || rc=$?

    if [[ $rc -eq 0 ]]; then
        printf "\r  ${G}●${N} %s... ${D}(%ds)${N}\033[K\n" "$msg" "$SECONDS"
    else
        printf "\r  ${R}✗${N} %s... ${D}(%ds)${N}\033[K\n" "$msg" "$SECONDS"
    fi
    return $rc
}

# Progress bar with spinner — call repeatedly to animate.
# Shows: `<spin> <label> [████▓░░░░] 42%  (12s)`
# The spinner cycles |/-\ automatically each call.
# Usage: progress "LifeOS" 42 12
progress()
{
    local label="$1" pct="$2" secs="${3:-}" barw=18
    local spin='|/-\'
    sp_idx=$(( (${sp_idx:-0} + 1) % 4 ))
    local sp="${spin:$sp_idx:1}"
    local filled=$((pct * barw / 100))
    local bar=""
    for ((i=0; i<barw; i++)); do
        if ((i < filled)); then bar+="${G}█${N}"
        elif ((i == filled)); then bar+="${C}▒${N}"
        else bar+="${D}░${N}"
        fi
    done
    printf "\r  ${C}%s${N} ${C}%-18s${N} ${C}[${N}%s${C}]${N} %3d%%  ${D}(%ds)${N}\033[K" "$sp" "$label" "$bar" "$pct" "$secs"
}


