# ── Shared box-drawing variables for Insightful CLI ──
# Source right after banner.sh:  source "$ROOT_DIR/lib/box.sh"
#
# Provides:
#   BW   = 120  (box width in chars)
#   BOX  = string of 120 ─ chars (for top/bottom/divider borders)
#
# Usage:  echo -e "  ${C}┌${BOX}┐${N}"
#         echo -e "  ${C}│${N}  content here$(printf '%*s' $((BW - 18)) '')${C}│${N}"
#         echo -e "  ${C}└${BOX}┘${N}"

BW=120
BOX=$(printf '─%.0s' {1..120} 2>/dev/null || printf '─%.0s' $(seq 1 120))
