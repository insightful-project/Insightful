# ── ASCII Art Banners for Insightful CLI ──
# Source: source lib/banner.sh
#
# Palette inspired by Odysseus: --fg: #9cdef2, --green: #50fa7b, --red: #e06c75

C=$'\033[0;36m'    # cyan primary    (Odysseus --fg)
G=$'\033[0;32m'    # green           (Odysseus --green)
Y=$'\033[0;33m'    # yellow/warn     (Odysseus --warn)
R=$'\033[0;31m'    # red             (Odysseus --red)
B=$'\033[1;34m'    # blue accent
W=$'\033[1;37m'    # white bold
D=$'\033[2;37m'    # dim gray
N=$'\033[0m'       # reset

# Source mode detection if not already loaded
if [[ -z "${INSIGHTFUL_MODE:-}" ]]; then
    SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SELF_DIR/mode.sh"
fi

# Box width = 50 chars between the ║ edges
banner_main()
{
    local label="${1:-SYSTEMS NOMINAL}"
    local label_pad="$(printf "%-18s" "$label")"
    local mode_pad="$(printf "%-4s" "$INSIGHTFUL_MODE")"

    echo ""
    printf "  ${C}╔══════════════════════════════════════════════════╗${N}\n"
    printf "  ${C}║${N}              ${W}INSIGHTFUL PROJECTS${N}                 ${C}║${N}\n"
    printf "  ${C}║${N}          ${D}SYSTEM CONTROL INTERFACE${N}                ${C}║${N}\n"
    printf "  ${C}╠══════════════════════════════════════════════════╣${N}\n"
    printf "  ${C}║${N} MODE:  ${C}%s${N}%38s${C}║${N}\n" "$mode_pad" ""
    printf "  ${C}║${N} STATUS ${C}██████████████████████${N}  ${C}%s${N}${C}║${N}\n" "$label_pad"
    printf "  ${C}╚══════════════════════════════════════════════════╝${N}\n"
    echo ""
}
