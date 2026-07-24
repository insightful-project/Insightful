#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"

source "$ROOT_DIR/lib/banner.sh"
source "$ROOT_DIR/lib/box.sh"

# ── Flags ──
DRY_RUN=0
DO_WAIT=1        # --wait by default
DO_UPGRADE=0     # --upgrade flag to check for newer image versions
FORCE=0

_ARGS=()
for arg in "$@"; do
    case "$arg" in
        (--dry-run|--plan)     DRY_RUN=1 ;;
        (--wait)               DO_WAIT=1 ;;
        (--no-wait)            DO_WAIT=0 ;;
        (--upgrade)            DO_UPGRADE=1 ;;
        (--force)              FORCE=1 ;;
        (*)                    _ARGS+=("$arg") ;;
    esac
done
set -- "${_ARGS[@]}"

# ── Map product name → compose file ──
_resolve_yml()
{
    local name="$1"
    case "$name" in
        (observability|obs)  echo "observability.yml" ;;
        (code-server|cs)     echo "code-server.yml" ;;
        (cloudbeaver|cb)     echo "cloudbeaver.yml" ;;
        (insightful-hub|hub) echo "insightful-hub.yml" ;;
        (life-os|lifeos)     echo "lifeos.yml" ;;
        (odysseus)           echo "odysseus.yml" ;;
        (n8n)                echo "n8n.yml" ;;
        (npm)                echo "npm.yml" ;;
        (qdrant)             echo "qdrant.yml" ;;
        (ollama)             echo "ollama.yml" ;;
        (redis)              echo "redis.yml" ;;
        (codespace)          echo "codespace.yml" ;;
        (oauth2)             echo "oauth2.yml" ;;
        (*)                  echo "" ;;
    esac
}

# ── Upgrade strategies ──
# Each entry: image_base|strategy
# Strategies:
#   semver:same-major   — bump within current major (2.28.5 → latest 2.x)
#   semver:major-minor  — bump within current major.minor (3.4 → latest 3.x)
#   semver:v-prefix     — v-prefixed semver (v1.18.2 → latest v1.x)
#   skip                — date-based or floating, don't auto-upgrade
_UPGRADE_MAP()
{
    cat <<'MAP'
n8nio/n8n|semver:same-major
ollama/ollama|semver:same-major
grafana/grafana|semver:major-minor
grafana/loki|semver:major-minor
qdrant/qdrant|semver:v-prefix
jc21/nginx-proxy-manager|semver:same-major
codercom/code-server|semver:same-major
chromadb/chroma|semver:same-major
binwiederhier/ntfy|semver:v-prefix
dbeaver/cloudbeaver|semver:same-major
MAP
}

# ── Version helpers ──

# Query Docker Hub for all tags of an image. Paginates to get 500 max.
# Usage: _fetch_tags "library/redis"  → prints tag names, one per line
_fetch_tags()
{
    local path="$1"   # e.g. "library/redis" or "n8nio/n8n"
    local url="https://hub.docker.com/v2/repositories/${path}/tags"
    local page=1
    local total=0

    while [[ "$page" -lt 6 && "$total" -lt 500 ]]; do
        local resp
        resp=$(curl -sSf "${url}?page=${page}&page_size=100" 2>/dev/null || echo '{"results":[],"next":null}')
        echo "$resp" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//'
        local count
        count=$(echo "$resp" | grep -o '"name":"[^"]*"' | wc -l)
        total=$((total + count))
        local next
        next=$(echo "$resp" | grep -o '"next":"[^"]*"' | sed 's/"next":"//;s/"$//' || true)
        [[ -z "$next" || "$next" = "null" ]] && break
        page=$((page + 1))
    done
}

# Filter tags matching semver within a major version, sort, return latest.
# Usage: _latest_same_major "2." "2.28.5" < tags
# Accepts: 2.1.0, 2.28.5, 2.30.0 (three-part semver)
# Rejects: 2, 20-alpine, 2a, 1605bdf9
_latest_same_major()
{
    local prefix="$1"
    local current="$2"
    grep -E "^${prefix}[0-9]+\.[0-9]+$" | sort -V | tail -1
}

# Filter major.minor tags (no patch), sort, return latest.
# Usage: _latest_major_minor "3." "3.4" < tags
# Accepts: 3.4, 3.5, 3.10 (two-part)
# Rejects: 3.4.0, 3, 31-alpine
_latest_major_minor()
{
    local prefix="$1"
    local current="$2"
    # Match X.Y format (no third dot), within the major
    grep -E "^${prefix}[0-9]+$" | sort -V | tail -1
}

# Strip registry prefix from an image reference.
# "docker.io/n8nio/n8n:2.28.5" → "n8nio/n8n"
# "php:8.3-cli-alpine" → "library/php"
_image_path()
{
    local ref="$1"
    # Strip registry prefix
    ref="${ref#docker.io/}"
    ref="${ref#registry-1.docker.io/}"
    # If no /, it's a library image
    if [[ "$ref" != */* ]]; then
        # It might have a namespace like n8nio/n8n — check for /
        if [[ "$ref" =~ ^([^/]+)/([^:]+) ]]; then
            echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        else
            echo "library/${ref%:*}"
        fi
    else
        echo "${ref%:*}"
    fi
}

# Extract tag from image reference.
# "docker.io/n8nio/n8n:2.28.5" → "2.28.5"
_image_tag()
{
    local ref="$1"
    echo "${ref##*:}"
}

# Check if a tag looks like a floating version (alpine, latest, slim, etc.)
_is_floating()
{
    local tag="$1"
    [[ "$tag" =~ ^(latest|alpine|slim|bookworm|bullseye|jammy)$ ]] && return 0
    [[ "$tag" =~ -alpine$ ]] && return 0
    [[ "$tag" =~ -slim$ ]] && return 0
    [[ "$tag" =~ -bookworm$ ]] && return 0
    return 1
}

# ── Check and upgrade a single pinned image ──
# Reads a compose file line like:   image: docker.io/n8nio/n8n:2.28.5
# If a newer tag exists on Docker Hub within the same major version, updates it.
_check_upgrade()
{
    local file="$1"
    local lineno="$2"
    local line="$3"

    # Extract image reference (strip image: prefix and quotes)
    local ref
    ref=$(echo "$line" | sed 's/^[[:space:]]*image:[[:space:]]*//' | sed 's/["'"'"']//g' | tr -d '[:space:]')
    [[ -z "$ref" ]] && return

    # Skip floating tags
    local tag; tag="$(_image_tag "$ref")"
    if _is_floating "$tag"; then
        [[ "$DRY_RUN" -eq 1 ]] && echo -e "    ${D}skip $ref (floating tag)${N}"
        return
    fi

    local path; path="$(_image_path "$ref")"
    # Map to upgrade strategy
    local strategy=""
    while IFS='|' read -r img strat; do
        # Match against the last two segments of the path
        # "n8nio/n8n" matches "n8nio/n8n", "library/postgres" matches "library/postgres"
        if [[ "$path" == "$img" ]]; then
            strategy="$strat"
            break
        fi
    done < <(_UPGRADE_MAP)

    if [[ -z "$strategy" ]]; then
        [[ "$DRY_RUN" -eq 1 ]] && echo -e "    ${D}skip $ref (no upgrade strategy)${N}"
        return
    fi

    if [[ "$strategy" == "skip" ]]; then
        [[ "$DRY_RUN" -eq 1 ]] && echo -e "    ${D}skip $ref (explicit skip)${N}"
        return
    fi

    echo -e "  ${C}│${N}    ${C}checking${N} $ref ..."

    # Fetch tags from Docker Hub
    local tags
    tags=$(_fetch_tags "$path") || {
        echo -e "  ${C}│${N}    ${Y}warning:${N} could not fetch tags for $path"
        return
    }
    [[ -z "$tags" ]] && { echo -e "  ${C}│${N}    ${Y}warning:${N} no tags returned for $path"; return; }

    local current_tag="$tag"
    local current_major=""
    local candidate=""

    case "$strategy" in
        (semver:same-major)
            # Extract major version (e.g., "2." from "2.28.5")
            current_major=$(echo "$current_tag" | grep -o '^[0-9]\+\.')
            if [[ -z "$current_major" ]]; then
                echo -e "  ${C}│${N}    ${Y}skip${N} $ref (cannot parse major version)"
                return
            fi
            candidate=$(echo "$tags" | _latest_same_major "$current_major" "$current_tag")
            ;;
        (semver:major-minor)
            # Extract major version (e.g., "11." from "11.5")
            current_major=$(echo "$current_tag" | grep -o '^[0-9]\+\.')
            if [[ -z "$current_major" ]]; then
                echo -e "  ${C}│${N}    ${Y}skip${N} $ref (cannot parse major version)"
                return
            fi
            candidate=$(echo "$tags" | _latest_major_minor "$current_major" "$current_tag")
            ;;
        (semver:v-prefix)
            local stripped="${current_tag#v}"
            current_major=$(echo "$stripped" | grep -o '^[0-9]\+\.')
            if [[ -z "$current_major" ]]; then
                echo -e "  ${C}│${N}    ${Y}skip${N} $ref (cannot parse v-prefixed version)"
                return
            fi
            local raw_candidate
            raw_candidate=$(echo "$tags" | sed 's/^v//' | _latest_same_major "$current_major" "$stripped")
            [[ -n "$raw_candidate" ]] && candidate="v${raw_candidate}"
            ;;
        (*)
            echo -e "  ${C}│${N}    ${Y}skip${N} $ref (unknown strategy: $strategy)"
            return
            ;;
    esac

    if [[ -z "$candidate" ]]; then
        echo -e "  ${C}│${N}    ${D}no candidate found${N}"
        return
    fi

    if [[ "$candidate" == "$current_tag" ]]; then
        echo -e "  ${C}│${N}    ${G}already up to date${N} ($current_tag)"
        return
    fi

    # New version found!
    local prefix_part
    prefix_part=$(echo "$line" | sed 's/^[[:space:]]*image:[[:space:]]*//' | sed 's/:[^:]*$//')
    echo -e "  ${C}│${N}    ${G}upgrade${N} ${current_tag} ${C}→${N} ${candidate}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "  ${C}│${N}    ${D}would update:${N} $prefix_part:${current_tag} → $prefix_part:${candidate}"
        return
    fi

    # Do the YAML edit — replace only the tag at end of image: line
    # Escape dots in old_tag for sed
    local old_escaped
    old_escaped=$(echo "$current_tag" | sed 's/\./\\./g')
    if sed -i "${lineno}s/${old_escaped}$/${candidate}/" "$file"; then
        echo -e "  ${C}│${N}    ${G}✓${N} updated $file"
    else
        echo -e "  ${C}│${N}    ${R}✗${N} failed to update $file"
    fi
}

# ── Determine stacks ──
if [[ $# -gt 0 ]]; then
    STACKS=("$@")
else
    # Update all stacks (dependency order: infra → apps → ai)
    STACKS=(redis qdrant ollama oauth2 observability life-os n8n npm code-server codespace cloudbeaver hub odysseus)
fi

if [[ "$DO_UPGRADE" -eq 1 ]]; then
    echo ""
    echo -e "  ${C}┌${BOX}┐${N}"
    echo -e "  ${C}│${N}  ${W}VERSION CHECK${N}$(printf '%*s' $((BW - 16)) '')${C}│${N}"
    echo -e "  ${C}├${BOX}┤${N}"
    echo -e "  ${C}│${N}  ${D}Checking for newer image versions on Docker Hub...${N}$(printf '%*s' $((BW - 54)) '')${C}│${N}"
    echo -e "  ${C}└${BOX}┘${N}"
    echo ""

    for product in "${STACKS[@]}"; do
        yml="$(_resolve_yml "$product")"
        [[ -z "$yml" ]] && continue
        compose_file="$COMPOSE_DIR/$yml"
        [[ ! -f "$compose_file" ]] && continue

        echo -e "  ${C}┌${BOX}┐${N}"
        echo -e "  ${C}│${N}  ${C}[$product]${N}$(printf '%*s' $((BW - 10 - ${#product})) '')${C}│${N}"
        echo -e "  ${C}├${BOX}┤${N}"

        # Find image: lines (not commented out)
        grep -n '^\s*image:\s' "$compose_file" 2>/dev/null | while IFS=: read -r lineno line; do
            _check_upgrade "$compose_file" "$lineno" "$line"
        done || true  # grep exits 1 if no matches
        echo -e "  ${C}└${BOX}┘${N}"
        echo ""
    done
fi

# ── Update all stacks ──
PULLED=0
BUILT=0
SKIPPED=0
FAILED=0
ROLLED_BACK=0

for product in "${STACKS[@]}"; do
    yml="$(_resolve_yml "$product")"
    if [[ -z "$yml" ]]; then
        echo -e "  ${C}┌${BOX}┐${N}"
        echo -e "  ${C}│${N}  ${Y}Unknown product: $product${N}$(printf '%*s' $((BW - 22 - ${#product})) '')${C}│${N}"
        echo -e "  ${C}│${N}  ${D}  Use: redis qdrant ollama observability life-os n8n npm code-server codespace cloudbeaver hub odysseus oauth2${N}$(printf '%*s' $((BW - 89)) '')${C}│${N}"
        echo -e "  ${C}└${BOX}┘${N}"
        ((SKIPPED++))
        continue
    fi

    compose_file="$COMPOSE_DIR/$yml"
    if [[ ! -f "$compose_file" ]]; then
        echo -e "  ${C}┌${BOX}┐${N}"
        echo -e "  ${C}│${N}  ${Y}[$product] compose file not found: $compose_file${N}$(printf '%*s' $((BW - 44 - ${#product} - ${#compose_file})) '')${C}│${N}"
        echo -e "  ${C}└${BOX}┘${N}"
        ((SKIPPED++))
        continue
    fi

    echo ""
    echo -e "  ${C}┌${BOX}┐${N}"
    echo -e "  ${C}│${N}  ${W}$product${N}$(printf '%*s' $((BW - 10 - ${#product})) '')${C}│${N}"
    echo -e "  ${C}├${BOX}┤${N}"

    # ── Snapshot current images for rollback ──
    declare -A IMAGE_SNAPSHOT
    if [[ "$DRY_RUN" -eq 0 ]]; then
        while IFS='|' read -r svc img; do
            [[ -n "$img" ]] && IMAGE_SNAPSHOT["$svc"]="$img"
        done < <(compose "$compose_file" images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | sed 's/|/:/' || true)
    fi

    # ── 1. Pull pre-built images ──
    echo -e "  ${C}│${N}  ${D}Pulling images...${N}"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "  ${C}│${N}  ${D}(would pull)${N}"
        ((PULLED++))
    elif compose "$compose_file" pull; then
        ((PULLED++))
    fi

    # ── 2. Rebuild custom images ──
    echo -e "  ${C}│${N}  ${D}  Rebuilding custom images...${N}"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "  ${C}│${N}  ${D}(would build --pull)${N}"
        ((BUILT++))
    elif compose "$compose_file" build --pull; then
        ((BUILT++))
    fi
    WAIT_FLAG=""
    [[ "$DO_WAIT" -eq 1 ]] && WAIT_FLAG="--wait"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "  ${C}│${N}  ${D}  Restarting ($([ "$DO_WAIT" -eq 1 ] && echo "with --wait" || echo "no wait"))...${N}"
        echo -e "  ${C}│${N}  ${D}    (would run: compose up -d ${WAIT_FLAG})${N}"
        echo -e "  ${C}│${N}  ${G}✓${N} $product (dry-run)"
        echo -e "  ${C}└${BOX}┘${N}"
        continue
    fi

    echo -e "  ${C}│${N}  ${D}  Restarting ($([ "$DO_WAIT" -eq 1 ] && echo "with --wait" || echo "no wait"))...${N}"
    if compose "$compose_file" up -d $WAIT_FLAG; then
        echo -e "  ${C}│${N}  ${G}✓${N} $product updated"
        echo -e "  ${C}└${BOX}┘${N}"
    else
        echo -e "  ${C}│${N}  ${R}✗${N} $product failed to restart"
        ((FAILED++))

        # ── Rollback attempt ──
        if [[ ${#IMAGE_SNAPSHOT[@]} -gt 0 ]]; then
            echo -e "  ${C}│${N}  ${Y}  Attempting rollback...${N}"
            rolled=0
            for svc in "${!IMAGE_SNAPSHOT[@]}"; do
                old_img="${IMAGE_SNAPSHOT[$svc]}"
                if [[ -n "$old_img" ]]; then
                    tag="${old_img##*:}"
                    repo="${old_img%:*}"
                    if $PODMAN tag "$old_img" "$repo:$tag.rollback" 2>/dev/null; then
                        echo -e "  ${C}│${N}  ${D}    saved $old_img -> $tag.rollback${N}"
                        ((rolled++))
                    fi
                fi
            done
            if [[ "$rolled" -gt 0 ]]; then
                echo -e "  ${C}│${N}  ${D}    rollback images saved with .rollback suffix${N}"
                echo -e "  ${C}│${N}  ${D}    restore: podman tag IMAGE:OLD.rollback IMAGE:OLD && compose -f $yml up -d${N}"
                ((ROLLED_BACK++))
            fi
        fi
        echo -e "  ${C}└${BOX}┘${N}"
    fi
done

echo ""
echo -e "  ${C}┌${BOX}┐${N}"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo -e "  ${C}│${N}  ${C}Dry-run complete${N}$(printf '%*s' $((BW - 20)) '')${C}│${N}"
    echo -e "  ${C}│${N}  Pulled: ${G}$PULLED${N} | Rebuilt: ${G}$BUILT${N} | Skipped: ${Y}$SKIPPED${N}$(printf '%*s' $((BW - 49)) '')${C}│${N}"
    echo -e "  ${C}│${N}  ${D}Run without --dry-run to apply.${N}$(printf '%*s' $((BW - 34)) '')${C}│${N}"
else
    echo -e "  ${C}│${N}  ${C}Update complete${N}$(printf '%*s' $((BW - 18)) '')${C}│${N}"
    echo -e "  ${C}│${N}  Pulled: ${G}$PULLED${N} | Rebuilt: ${G}$BUILT${N} | Skipped: ${Y}$SKIPPED${N} | Failed: ${R}$FAILED${N} | Rollback: ${Y}$ROLLED_BACK${N}$(printf '%*s' $((BW - 81)) '')${C}│${N}"
    if [[ "$ROLLED_BACK" -gt 0 ]]; then
        echo -e "  ${C}│${N}  ${Y}Some stacks failed. Rollback images saved with .rollback suffix.${N}$(printf '%*s' $((BW - 67)) '')${C}│${N}"
        echo -e "  ${C}│${N}  ${D}  Restore: podman tag <image>:<version>.rollback <image>:<version> && compose -f <stack>.yml up -d${N}$(printf '%*s' $((BW - 95)) '')${C}│${N}"
    fi
    if [[ "$FAILED" -gt 0 ]]; then
        echo -e "  ${C}│${N}  ${D}  Check logs: ./logs.sh <product>${N}$(printf '%*s' $((BW - 37)) '')${C}│${N}"
    fi
fi
echo -e "  ${C}└${BOX}┘${N}"
