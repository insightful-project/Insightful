# Life OS — Quickstart Guide

## Prerequisites

- **Podman** (recommended) or **Docker**
  - Windows: `winget install RedHat.Podman` or Docker Desktop
  - macOS: `brew install podman` or Docker Desktop
  - Linux: `apt install podman` or `apt install docker.io`
- **Git**
- **curl** (for health checks)

---

## 1. Clone & Configure

```bash
git clone <repo-url> Insightful
cd Insightful
cp .env.example compose/.env
```

Edit `compose/.env` — at minimum set these two:

```
JWT_SECRET=<generate a random 64-char string>
DB_PASSWORD=<generate a strong password>
```

Generate secure values:

```bash
# Linux/macOS
openssl rand -base64 48 | tr -d /=+ | cut -c1-64

# or
node -e "console.log(crypto.randomBytes(48).toString('hex'))"
```

---

## 2. Start Life OS

```bash
./start.sh life-os
```

First start builds the Docker images (~2 min). Subsequent starts are instant.

**What you get:**

| Service | URL | Purpose |
|---------|-----|---------|
| Vue frontend | http://localhost:3002 | PWA dashboard |
| NestJS API | http://localhost:4001 | REST backend |
| Postgres | localhost:5434 | Database |
| CloudBeaver | http://localhost:8978 | DB admin GUI |

**Expected output:**

```
[LifeOS] Building images...
[LifeOS] Starting containers...
  ✓ LifeOS API
  ✓ LifeOS Frontend
  ✓ Postgres
```

Verify with:

```bash
curl http://localhost:4001/health
# → {"status":"ok","db":"connected","time":"..."}
```

---

## 3. Usage

Open **http://localhost:3002**. You'll see:

1. **Welcome screen** — overview of Life OS features
2. **Sign Up or Log In** — email registration enables cloud sync
3. **Profile setup** — identity, bio-metrics, financials
4. **Dashboard** — daily budget, tasks, fitness summary

### Guest Mode

Skip registration to use the app with device-local storage only. Data syncs via cloud when you register later.

---

## 4. Stop & Manage

```bash
./stop.sh           # stop all stacks
./stop.sh life-os   # stop Life OS only
./start.sh life-os  # start again (no rebuild needed)
./status.sh         # health dashboard
```

### Rebuild after updates

```bash
./rebuild.sh life-os api-nest    # rebuild API container
./rebuild.sh life-os vue-app     # rebuild frontend
```

---

## 5. Database Backup

Postgres data lives in a named volume (`lifeos-postgres`). Back it up with:

```bash
# One-time backup
podman exec lifeos-db pg_dump -U lifeos_user lifeos > backup_$(date +%Y%m%d).sql

# Restore
cat backup_20260715.sql | podman exec -i lifeos-db psql -U lifeos_user lifeos
```

### Automated Backups (cron)

Add to your crontab (`crontab -e`):

```cron
# Daily 3am backup, keep 7 days
0 3 * * * cd /path/to/Insightful && podman exec lifeos-db pg_dump -U lifeos_user lifeos > backups/daily_$(date +\%Y\%m\%d).sql && find backups/ -name 'daily_*' -mtime +7 -delete
```

### Docker Users

Replace `podman` with `docker` in all commands above.

---

## SSL with Nginx Proxy Manager

Life OS runs on plain HTTP by default. For production access with TLS:

1. **Start NPM**: `./start.sh npm`
2. **Open admin UI**: http://localhost:81
   - Login: `admin@insightful-projects.com`
   - Password: from `compose/.env` (default: `Insightful2026!`)
3. **Add Proxy Host**:
   - Domain: `lifeos.yourdomain.com`
   - Forward Hostname: `localhost`
   - Forward Port: `3002` (frontend) or `4001` (API)
   - **SSL tab**: Request Let's Encrypt certificate
   - Enable: Force SSL, HTTP/2

NPM handles certificate renewal automatically.

### Port Exposure

Containers bind to `127.0.0.1` only — they're not externally accessible. NPM (port 80/443) is the only public entry point.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `DATABASE_URL not set` | Copy `.env.example` to `compose/.env` and fill in values |
| `JWT_SECRET` errors | Generate a random JWT_SECRET (see step 1) |
| Port conflicts | Set `LIFEOS_VUE_PORT=3003` etc. in `compose/.env` |
| `relation not found` | Migrations auto-run on container startup |
| Images won't build | Run `./rebuild.sh life-os` to force rebuild |
| Podman not found | Set `PODMAN=docker` or alias: `alias podman=docker` |

### Healthcheck

```bash
curl http://localhost:4001/health
# Expected: {"status":"ok","db":"connected","time":"..."}
# If db is disconnected, Postgres may still be starting — wait 10s and retry.
```

---

## Architecture Reference

Architecture docs live in the repo:

- `dev/ins1ght/docs/` — Build standards (architecture-map, class-hierarchy, CI/CD, ops)
- `dev/insightful-hub/ai-framework/ai-memory/` — Running-state docs (system-map, infra-map, decision-log)
- `AGENTS.md` — AI agent guide for the dev workspace
