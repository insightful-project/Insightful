#!/usr/bin/env bash
set -euo pipefail

# NPM OAuth Proxy Setup
# Creates/updates Nginx Proxy Manager proxy hosts to route through OAuth2 sidecars.
# Run this AFTER OAuth sidecars are running and OAUTH2 env vars are set.
#
# Usage: ./bin/npm-oauth-setup.sh [--dry-run]

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NPM_URL="http://localhost:81"
DRY_RUN=0

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# ── NPM API helpers ────────────────────────────────────────────────

_npm_api()
{
    local method="$1" path="$2" data="${3:-}"
    local args=(-s -X "$method" "$NPM_URL$path")
    if [[ -n "$TOKEN" ]]; then
        args+=(-H "Authorization: Bearer $TOKEN")
    fi
    if [[ -n "$data" ]]; then
        args+=(-H "Content-Type: application/json" -d "$data")
    fi
    curl "${args[@]}"
}

_get_token()
{
    local email="${NPM_ADMIN_EMAIL:-admin@insightful-projects.com}"
    local pass="${NPM_ADMIN_PASSWORD:-${NPM_ADMIN_PASSWORD:-Insightful2026!}}"
    local resp
    resp=$(_npm_api POST "/api/tokens" "{\"identity\":\"$email\",\"secret\":\"$pass\"}")
    TOKEN=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null || true)
    if [[ -z "$TOKEN" ]]; then
        echo "  ${R}✗${N} Failed to authenticate with NPM at $NPM_URL"
        echo "  ${D}  Response: $resp${N}"
        exit 1
    fi
}

# ── Proxy host definitions ─────────────────────────────────────────
# Services going through OAuth2 Proxy sidecars
declare -A OAUTH_HOSTS
OAUTH_HOSTS["n8n.insightful-projects.com"]="oauth-n8n:4180|Google SSO (strict allowlist)"
OAUTH_HOSTS["code.insightful-projects.com"]="oauth-codeserver:4180|Google SSO (strict allowlist)"
OAUTH_HOSTS["odysseus.insightful-projects.com"]="oauth-odysseus:4180|Google SSO (strict allowlist)"
OAUTH_HOSTS["cloudbeaver.insightful-projects.com"]="oauth-cloudbeaver:4180|Google SSO (strict allowlist)"
OAUTH_HOSTS["grafana.insightful-projects.com"]="oauth-grafana:4180|Google SSO (domain)"
OAUTH_HOSTS["hub.insightful-projects.com"]="oauth-hub:4180|Google SSO (domain)"

# Direct services (no OAuth)
declare -A DIRECT_HOSTS
DIRECT_HOSTS["api.insightful-projects.com"]="api-nest:4001|NestJS API (JWT)"
DIRECT_HOSTS["vue.insightful-projects.com"]="vue-app:3000|Vue frontend (JWT)"
DIRECT_HOSTS["searxng.insightful-projects.com"]="searxng:8080|SearXNG search"
DIRECT_HOSTS["chromadb.insightful-projects.com"]="chromadb:8000|ChromaDB"
DIRECT_HOSTS["ntfy.insightful-projects.com"]="ntfy:80|ntfy notifications"
DIRECT_HOSTS["ollama.insightful-projects.com"]="insightful-ollama:11434|Local LLM"
DIRECT_HOSTS["npm.insightful-projects.com"]="npm:81|NPM admin UI"

# ── Main ───────────────────────────────────────────────────────────

echo ""
echo "  NPM OAuth Proxy Setup"
echo "  ──────────────────────"
echo ""

_get_token

# Get existing proxy hosts
local existing_json
existing_json=$(_npm_api GET "/api/nginx/proxy-hosts")
echo "$existing_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for h in data:
    domain = h.get('domain_names', [''])[0]
    print(f\"{h['id']}|{domain}|{h['forward_host']}|{h['forward_port']}\")
" 2>/dev/null | sort > /tmp/npm-existing.txt || true

echo -e "  ${D}Existing proxy hosts:${N}"
if [[ -s /tmp/npm-existing.txt ]]; then
    cat /tmp/npm-existing.txt | while IFS='|' read -r id domain host port; do
        echo -e "    ${C}${id}${N}  ${domain}  →  ${host}:${port}"
    done
else
    echo -e "    ${D}(none)${N}"
fi
echo ""

_create_or_update()
{
    local domain="$1" forward="$2" desc="$3"
    local fwd_host="${forward%%:*}"
    local fwd_port="${forward##*:}"

    # Check if this domain already exists
    local existing_id=""
    while IFS='|' read -r eid edomain ehost eport; do
        if [[ "$edomain" == "$domain" ]]; then
            existing_id="$eid"
            break
        fi
    done < /tmp/npm-existing.txt

    if [[ -n "$existing_id" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo -e "  ${Y}DRY RUN${N} Would UPDATE host ${existing_id}: ${domain} → ${forward} (${desc})"
        else
            echo -e "  ${G}UPDATING${N} host ${existing_id}: ${domain} → ${forward} (${desc})"
            local body
            body=$(cat <<EOF
{
  "domain_names": ["$domain"],
  "forward_scheme": "http",
  "forward_host": "$fwd_host",
  "forward_port": $fwd_port,
  "access_list_id": null,
  "certificate_id": null,
  "ssl_forced": false,
  "caching_enabled": false,
  "block_exploits": true,
  "advanced_config": "",
  "meta": { "letsencrypt_agree": false, "dns_challenge": false },
  "locations": [],
  "hsts_enabled": false,
  "hsts_subdomains": false,
  "http2_support": false
}
EOF
)
            _npm_api PUT "/api/nginx/proxy-hosts/$existing_id" "$body" >/dev/null
        fi
    else
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo -e "  ${Y}DRY RUN${N} Would CREATE host: ${domain} → ${forward} (${desc})"
        else
            echo -e "  ${G}CREATING${N} host: ${domain} → ${forward} (${desc})"
            local body
            body=$(cat <<EOF
{
  "domain_names": ["$domain"],
  "forward_scheme": "http",
  "forward_host": "$fwd_host",
  "forward_port": $fwd_port,
  "access_list_id": null,
  "certificate_id": null,
  "ssl_forced": false,
  "caching_enabled": false,
  "block_exploits": true,
  "advanced_config": "",
  "meta": { "letsencrypt_agree": false, "dns_challenge": false },
  "locations": [],
  "hsts_enabled": false,
  "hsts_subdomains": false,
  "http2_support": false
}
EOF
)
            _npm_api POST "/api/nginx/proxy-hosts" "$body" >/dev/null
        fi
    fi
}

echo -e "  ${W}OAuth2-Protected Services:${N}"
for domain in "${!OAUTH_HOSTS[@]}"; do
    IFS='|' read -r forward desc <<< "${OAUTH_HOSTS[$domain]}"
    _create_or_update "$domain" "$forward" "$desc"
done

echo ""
echo -e "  ${W}Direct Services:${N}"
for domain in "${!DIRECT_HOSTS[@]}"; do
    IFS='|' read -r forward desc <<< "${DIRECT_HOSTS[$domain]}"
    _create_or_update "$domain" "$forward" "$desc"
done

echo ""
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo -e "  ${Y}Dry run complete. Run without --dry-run to apply.${N}"
else
    echo -e "  ${G}✓${N} NPM proxy hosts configured."
    echo -e "  ${D}  Access services via http://<service>.insightful-projects.com${N}"
    echo -e "  ${D}  Note: OAuth requires SSL. Once DNS is live, run with ssl_forced=true${N}"
fi
echo ""
