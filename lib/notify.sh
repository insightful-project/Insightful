# ── ntfy Push Notifications ──
# Source this file to get the `notify` function.
# ntfy runs inside the Odysseus stack at localhost:8091
#
# Fire-and-forget: never blocks startup or shutdown.
# If ntfy is unreachable, an async warning is printed.
#
# To receive notifications, subscribe to the topic:
#   curl -s http://localhost:8091/insightful/raw
# Or install the ntfy mobile app and subscribe to the topic.

# Default topic — override via INSIGHTFUL_NTFY_TOPIC env var
NTFY_TOPIC="${INSIGHTFUL_NTFY_TOPIC:-insightful}"

# Send a push notification via the local ntfy server
# Backgrounds the curl call so it never blocks execution.
# Prints a warning asynchronously if ntfy is unreachable.
# Usage: notify "LifeOS ready"
notify()
{
    local msg="$1"
    local ntfy_url="http://localhost:8091"
    # Fire-and-forget — no health probe, zero blocking
    (curl -sf -X POST -d "$msg" "$ntfy_url/$NTFY_TOPIC" >/dev/null 2>&1 || echo -e "  ${Y}⚠ ntfy not reachable${N}" >&2) &
}
