# ponytail: shared health-check URL definitions for dash.sh and status.sh.
# Add new services here — both dashboards pick them up automatically.
# Format: "Display Name|http://host:port/path"
#         "Display Name|tcp://host:port"   — for non-HTTP services (port check)

HEALTH_URLS=(
    "LifeOS API|http://localhost:4001/health"
    "LifeOS Vue|http://localhost:3002"
    "CloudBeaver|http://localhost:8978"
    "Ollama LLM|http://localhost:11434/api/tags"
    "n8n|http://localhost:5678/healthz"
    "Hub|http://localhost:3003"
    "NPM Admin|http://localhost:81"
    "code-server|http://localhost:8081"
    "codeSpace DB|tcp://localhost:5436"
    "Redis|tcp://localhost:6379"
    "Loki|http://localhost:3100/ready"
    "Grafana|http://localhost:3000/api/health"
    "Odysseus|http://localhost:7000/api/health"
    "ntfy|http://localhost:8091/v1/health"
    "SearXNG|http://localhost:8080/healthz"
    "ChromaDB|http://localhost:8100/api/v1/heartbeat"
    "OAuth2 n8n|http://localhost:4180/ping"
)
