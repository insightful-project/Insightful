# ── Insightful Machine Mode Detection ──
# Source after lib/banner.sh

MODE_FILE="$HOME/.insightful-mode"

# Load container runtime abstraction (podman.exe / podman / docker)
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SELF_DIR/podman.sh"

# If the user set a mode file, honor it
if [[ -f "$MODE_FILE" ]]; then
    INSIGHTFUL_MODE=$(tr -d '[:space:]' < "$MODE_FILE")
fi

# Auto-detect if no mode file
if [[ -z "${INSIGHTFUL_MODE:-}" ]]; then
    if command -v podman.exe &>/dev/null; then
        INSIGHTFUL_MODE="dev"
    else
        INSIGHTFUL_MODE="live"
    fi
fi

# Validate
case "$INSIGHTFUL_MODE" in
    live|dev) ;;
    *) INSIGHTFUL_MODE="dev" ;;
esac

export INSIGHTFUL_MODE
