# ── Push Notifications (disabled) ──
# Source this file to get the `notify` function.
#
# ntfy was part of the removed Odysseus stack. The `notify` function is kept as
# a no-op so start.sh, stop.sh and rebuild.sh keep working unchanged.
#
# ponytail: future task — replace ntfy with an n8n webhook so stack start/stop
# and rebuild events are delivered by the existing n8n stack (compose/n8n.yml)
# instead of a dedicated notification container.
#
# To restore notifications, replace the body below with a real delivery call.

# Send a push notification. Currently a no-op.
# Usage: notify "LifeOS ready"
notify()
{
    return 0
}
