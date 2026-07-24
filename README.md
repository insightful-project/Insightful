# Insightful — Life OS

**Life OS** is an offline-first personal data operating system. A Vue 3 PWA backed by NestJS + Postgres. Runs on Podman or Docker.

## What It Does

- **Finance** — Track income, expenses, budgets (50/30/20), savings goals
- **Fitness** — Log workouts, exercises, body metrics, TDEE/BMI calculations
- **Nutrition** — Food diary with calorie and macro tracking
- **Schedule** — Tasks, calendar events, routines with daily time blocking

Data syncs when online, works fully offline via Dexie (IndexedDB).

## Quick Start

```bash
# Requirements: Podman (or Docker), Git
git clone <repo-url> Insightful
cd Insightful
cp .env.example compose/.env
nano compose/.env          # set JWT_SECRET + DB_PASSWORD
./start.sh life-os         # starts Postgres + API + frontend
```

Then open **http://localhost:3002** in a browser.

## Architecture

```
Browser (Vue PWA) → REST API (NestJS, port 4001) → Postgres (port 5434)
                        ↓ (future)
                   RPC (Java codeSpace)
```

- **Frontend**: Vue 3 + Pinia + Dexie + Tailwind (port 3002)
- **API**: NestJS + Drizzle ORM + JWT auth + Helmet CSP (port 4001)
- **DB**: Postgres 16 Alpine (port 5434)
- **PWA**: Offline-first, installable, service worker cached

## Included Stacks

| Command | What starts |
|---------|-------------|
| `./start.sh life-os` | Postgres + API + Frontend |
| `./start.sh odysseus` | AI proxy (port 7000) + ChromaDB + SearXNG + ntfy |
| `./start.sh n8n` | Automation platform + its Postgres |
| `./start.sh all` | Every stack at once |

See `docs/QUICKSTART.md` for full setup, backup, and SSL guides.
