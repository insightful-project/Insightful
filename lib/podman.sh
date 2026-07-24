# ── Container Runtime Abstraction ──────────────────────────────────
# Source this file from any script that needs podman/docker operations.
# Auto-detects: podman.exe (WSL) → podman (Linux) → docker (fallback).
#
# Exports:
#   $PODMAN        — the container runtime binary to use
#   compose()      — podman compose wrapper with cross-platform path handling
#   compose_down() — same for compose down (stops + removes)
#   compose_stop() — same for compose stop (stops, keeps containers)
#   _to_win()      — WSL→Windows path conversion (no-op on Linux)

if command -v podman.exe &>/dev/null; then
    PODMAN=podman.exe
    # WSL→Windows path translation for podman.exe
    _to_win()
    {
        local p="${1#/mnt/c/}"
        echo "C:/$p"
    }
elif command -v podman &>/dev/null; then
    PODMAN=podman
    _to_win() { echo "$1"; }
else
    PODMAN=docker
    _to_win() { echo "$1"; }
fi

export PODMAN

# Run podman/docker compose with cross-platform path handling.
# Strips the noisy "Executing external compose provider" line.
# Always returns the compose command's exit code (not grep's).
# Compatible with set -euo pipefail (|| true guards against pipefail).
# Usage: compose "path/to/file.yml" up -d
compose()
{
    local file="$1"; shift
    $PODMAN compose -f "$(_to_win "$file")" "$@" 2>&1 | grep -v "Executing external compose provider" || true
    return "${PIPESTATUS[0]}"
}

# Shorthand for compose down (stops + removes containers)
# Usage: compose_down "path/to/file.yml"
compose_down()
{
    compose "$1" down
}

# Shorthand for compose stop (stops containers, keeps them)
# Usage: compose_stop "path/to/file.yml"
compose_stop()
{
    compose "$1" stop
}
