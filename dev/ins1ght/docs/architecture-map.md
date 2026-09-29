# Architecture Map — Insightful

This document is the single source of truth for how Insightful projects fit together.
Read this first. Every agent reads this first.

## Hub and Spokes

```
Insightful (monorepo root)
│
├── dev/ins1ght/              ← ARCHITECTURE FOLDER — specs, products, infra
│
├── dev/insightful-hub/       ← BACKEND HUB — shared packages, AI framework
│
├── odysseus/                 ← AI WORKSPACE — Python, standalone
│
├── compose/                  ← CENTRALIZED COMPOSE FILES — 12 stacks
│
│
└── .opencode/                ← AGENT CONFIG — skills, commands, memory
```

## Spoke Roles

### `dev/ins1ght/` — The Architecture

This is where the architecture lives. Specs, standards, and all products.

| Path | Role | Stack |
|------|------|-------|
| `docs/` | Architecture specs (this + 4 others) | Markdown |
| `products/life-os-v2/` | Life OS v2 — main full-stack PWA | Vue 3 + NestJS + Postgres |
| `products/ins1ght-platform/` | n8n automation platform | n8n, Postgres |
| `clients/` | Client projects | Various |

### `dev/insightful-hub/` — The Backend Hub

Shared packages and submodules that multiple products consume.

| Path | Role | Stack |
|------|------|-------|
| `packages/@insightful/codeSpace/` | Shared types + entity contracts + service interfaces for all products | TypeScript |
| `packages/@insightful/codeSpace/models/` | Self-describing entity classes (field codes, token gen, Zod schema) | TypeScript |
| `packages/@insightful/base/` | Base superclasses — Facelet, AppException, DomainEntity (Foundation used by Java codeSpace only) | TypeScript (CommonJS) |
| `ai-framework/` | Architecture memory (decisions, system map, infra map, etc.) | Markdown |
| `ai-framework/ai-memory/system-map.md` | Current system boundaries, actors, trust zones, failure points | — |
| `ai-framework/ai-memory/infra-map.md` | Runtime environment, exposure, secrets, isolation | — |
| `ai-framework/ai-memory/integration-map.md` | External systems, auth, retry, data flow | — |
| `ai-framework/ai-memory/service-map.md` | Service responsibilities, business rules, entities | — |
| `ai-framework/ai-memory/data-map.md` | Data models, repositories, indexing, consistency | — |
| `ai-framework/ai-memory/decision-log.md` | All architectural decisions with reasoning | — |
| `ai-framework/ai-memory/implementation-plan.md` | Gap analysis, pending phases, effort estimates | — |
| `ai-framework/ai-memory/codespace-architecture.md` | codeSpace entity-based RPC architecture spec | — |
| `Valentines-Web` | Submodule — Valentines microsite | HTML/JS |
| `encrypt` | Submodule — encryption tool | HTML/JS |
| `insight-web` | Submodule — static site | HTML/CSS |

> `@insightful/domain` → `@insightful/codeSpace` — renamed. Contains shared types, domain object interfaces (Task, Transaction, Routine, UserProfile, FinanceTx, etc.), business rules (finance, fitness, nutrition calculations).

### `odysseus/` — AI Workspace

Standalone Python AI workspace. Connects to the backend via REST once cloud-deployed.

| Role | Stack |
|------|-------|
| LLM proxy (localhost:7000/v1) | Python, FastAPI |
| Web UI (localhost:7000) | Vanilla JS, HTML/CSS |
| Data service (todos, email, calendar, memory) | Python, SQLite |
| Agent integrations (Claude, Codex) | REST API at `/api/codex/*` |

### `compose/` — Centralized Compose Files

All stacks managed via `podman compose -f compose/*.yml` from repo root.

| File | Stack | Containers |
|------|-------|------------|
| `redis.yml` | Redis cache | insightful-redis |
| `observability.yml` | Log aggregation | insightful-loki + insightful-grafana |
| `lifeos.yml` | Life OS v2 | lifeos-db + lifeos-api-nest + lifeos-vue-app |
| `odysseus.yml` | Odysseus AI | odysseus + chromadb + searxng + ntfy |
| `n8n.yml` | n8n automation | n8n + n8n-db |
| `npm.yml` | Reverse proxy | npm |
| `insightful-hub.yml` | Backend hub | insightful-hub (PHP dashboard, port 3003) |
| `code-server.yml` | VS Code IDE | insightful-code-server |
| `ollama.yml` | Local LLM | insightful-ollama |
| `codespace.yml` | codeSpace RPC | codespace-db + codespace-java |
| `cloudbeaver.yml` | DB GUI | lifeos-cloudbeaver |
| `oauth2.yml` | Google SSO | 6 sidecar proxies (opt-in) |
| `insightful.yml` | Aggregate | (includes all 12 stacks via `include:`) |

### `k8s/` — Deleted (YAGNI)

`k8s/` directory was deleted 2026-07-13 — no K8s cluster exists.
If K8s provisioning begins, regenerate from compose files using `kompose`.

## Dev Environment

Services are managed via root-level scripts:

```
./start.sh [all|life-os|odysseus|n8n|redis|observability|ollama|code-server|npm|hub|codespace|cloudbeaver|dev] [dev|prod|db]
./stop.sh [all|life-os|odysseus|n8n|redis|observability|ollama|code-server|npm|hub|codespace|cloudbeaver]
./status.sh
./rebuild.sh <product> [service]
```

Key infrastructure:
- **Redis** (`insightful-redis`) — cache, rate limit store, pub/sub, Bull queue backend, port 6379
- **Loki** (`insightful-loki`) — log aggregation storage, port 3100
- **Grafana** (`insightful-grafana`) — dashboards with pre-configured Loki datasource, port 3000
- **Nginx Proxy Manager** (`npm`) — unified reverse proxy with GUI at port 81
- **Postgres (lifeos)** (`lifeos-db`) — primary database, port 5434
- **Postgres (n8n)** (`n8n-db`) — n8n workflow state, port 5435
- **CloudBeaver** (`lifeos-cloudbeaver`) — web-based DB GUI, port 8978
- **NestJS API** (`lifeos-api-nest`) — process layer, port 4001
- **Odysseus** (`odysseus`) — AI workspace + LLM proxy, port 7000

Dev mode (`./start.sh life-os dev`) uses `tsx watch` for hot-reload with volume mounts via the dev compose override. VS Code workspace settings cascade from root `.vscode/settings.json` into per-product overrides.

## Service Architecture

### Service Responsibilities

| Layer | Tech | Role |
|-------|------|------|
| **Presentation** | Vue 3 + PWA (Vite) | UI, offline state (Dexie), sync queue |

| **Contracts** | `@insightful/codeSpace` | Entity classes (field codes, token gen, Zod schema) + service interfaces |
| **Application / Process** | NestJS 11 + Drizzle | Plain @Injectable() stubs + Facelet+Process pattern, domain object management, auth |
| **Auth** | NestJS + Passport | JWT validation, auth guard, password hashing |
| **Automation** | n8n + MCP | Agent workflows, cross-branch automation |
| **Reverse Proxy** | Nginx Proxy Manager | Domain-based routing, SSL termination, GUI-managed config |
| **Memory** | JSON (mem0 MCP server) | Keyword (BM25) agent memory in `dev/.opencode/ai-memory/memories.json` |
| **AI Workspace** | Odysseus (Python) | LLM proxy, RAG (ChromaDB), search (SearXNG), notifications (ntfy) |
| **Infra** | Podman, NPM, Kubernetes | Containers, reverse proxy, orchestration |

### Request Flow

```
PWA (offline-capable — Vue)
  │  HTTP/HTTPS (via NPM proxy or direct port)
  ▼
Nginx Proxy Manager (reverse proxy, GUI-managed)
  │
  └── /api/*    → lifeos-api-nest:4001 (NestJS process layer)

NestJS internal flow:
  CorrelationIdMiddleware → RlsInterceptor (Drizzle tx + SET LOCAL)
    → RateLimiter (Redis-backed) → JwtAuthGuard → Controller → Service
        ↕
  NotificationService → Bull Queue (Redis)
    → Processor → ntfy push / n8n webhook

Logs:
  Pino → pino-loki (if LOKI_URL set) → Loki → Grafana
  Pino → Sentry (if SENTRY_DSN set)
  
Direct access (dev):
  localhost:3002 → Vue SPA
```

### Sync Flow (Offline-First)

```
DEVICE (PWA + Dexie)
  │  Queues writes when offline
  │  Flushes when online + authenticated
  ▼
NestJS (process layer)
  │  Sync merge, conflict resolution
  ▼
Postgres (lifeos-db:5432)
```

## Data Model — Entity Pattern

Every domain entity follows the same shape:

```typescript
// Defined in @insightful/codeSpace
interface DomainEntity {
    id: string;        // UUID v4
    userId: string;    // Owner
    hash: string;      // Unique per user-item (not content-derived)
    data: Record<string, unknown>;  // JSONB (tsvector-indexed for full-text search)
    createdAt: number; // Unix ms timestamp
    updatedAt: number; // Unix ms timestamp
}
```

### Entity Linking (No FK Cascades)

```
linking_table:
  parent_id   | child_id    | parent_hash | child_hash | joined_at
  ────────────────────────────────────────────────────────────────
  uuid        | uuid        | hash        | hash       | timestamp
```

- Entities exist independently (no FK cascade deletes)
- Links are managed via Foundation.add/remove (Java codeSpace JSONB entities) or direct Drizzle (flat-table NestJS stubs)
- Hash prevents duplicates across sync boundaries
- Groups hold "manys" via linking table, not array columns
- Same name can exist with different links (different hash per user-item)

### Why Hash-Based Identity?

- Resolves conflicts across devices (same item = same hash)
- Sync-friendly — no ID collision between offline creates
- Links can merge independently of entity data
- No cascade-delete surprises across sync boundaries

## Query Access Patterns

```
┌────────────────────────────────────────────────────────────┐
│  NESTJS (process layer)                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  fitnessStub.add({ name, type, userId })             │  │
│  │  fitnessStub.link(parentId, childId)                 │  │
│  │  — Foundation operations, domain logic               │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

## REST Contract

Every service in the Insightful ecosystem speaks the same REST language.

### Request Envelope

```
POST /v1/resource
Authorization: Bearer <jwt>
Content-Type: application/json
X-Correlation-Id: <uuid>

{ "data": { ... } }
```

### Response Envelope (success)

```json
{
    "status": "ok",
    "data": { ... },
    "meta": {
        "correlationId": "uuid",
        "timestamp": "2026-06-25T12:00:00Z"
    }
}
```

### Response Envelope (error)

```json
{
    "status": "error",
    "error": {
        "code": "VALIDATION_ERROR",
        "message": "Human-readable message",
        "details": { "field": "email", "reason": "invalid format" }
    },
    "meta": {
        "correlationId": "uuid",
        "timestamp": "2026-06-25T12:00:00Z"
    }
}
```

### Pagination

```
GET /v1/resource?page=2&limit=20
```

```json
{
    "status": "ok",
    "data": [ ... ],
    "meta": {
        "page": 2,
        "limit": 20,
        "total": 150,
        "totalPages": 8,
        "correlationId": "uuid",
        "timestamp": "2026-06-25T12:00:00Z"
    }
}
```

> **Default pagination limit:** 40. Reports return all results (no pagination).

### Error Codes

| Code | HTTP Status | Meaning |
|------|-------------|---------|
| `VALIDATION_ERROR` | 400 | Input failed validation |
| `AUTH_ERROR` | 401 | Missing or invalid credentials |
| `FORBIDDEN` | 403 | Authenticated but not authorized |
| `NOT_FOUND` | 404 | Resource does not exist |
| `CONFLICT` | 409 | Resource already exists or state conflict |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Unexpected server error |
| `SERVICE_UNAVAILABLE` | 503 | Downstream dependency unavailable |

## Auth Flow

```
Offline path:
    PWA → reads/writes Dexie → syncs when online

Online path (email + JWT):
    PWA / Agent
        │
        ▼
    NestJS (AuthModule)
        │  Issues JWT + refresh token
        ▼
    Postgres (lifeos-db)

Auth Gateway path (ins1ght-dash — future):
    ins1ght-dash (Java)
        │  Validates JWT, enforces RBAC
        ▼
    NestJS (process layer)
        │  Reads JWT claims, checks permissions
        ▼
    Postgres (lifeos-db)
```

- **Offline:** deviceId + local state (Dexie). No auth needed for local ops.
- **Online (sync):** email + JWT. Email confirmed via verification link or WhatsApp.
- **Dual path:** deviceId if client not synced; JWT if authenticated; both fail → unauthenticated.
- JWT format: `{ sub, roles, scope, exp, iat }`
- Token propagated via `Authorization: Bearer` header
- `X-Correlation-Id` forwarded through every hop for tracing

## Data Ownership

| Data | Owned By | Stored In |
|------|----------|-----------|
| User profiles | Life OS v2 | Postgres (lifeos-db) |
| Finance transactions | Life OS v2 | Postgres (lifeos-db) |
| Fitness data | Life OS v2 | Postgres (lifeos-db) |
| Tasks & schedule | Life OS v2 | Postgres (lifeos-db) |
| Secrets & credentials | ins1ght-dash | Encrypted vault |
| System config | ins1ght-dash | Postgres (ins1ght) |
| Todos, email, calendar | Odysseus | SQLite (odysseus) |
| Agent memory | mem0 | JSON (dev/.opencode/ai-memory/memories.json) |
| Odysseus RAG vectors | Odysseus | ChromaDB (odysseus-chromadb) |
| Architecture decisions | insightful-hub | Git (markdown) |



## Code Standards

- **Allman braces** — opening brace on new line for every block
- **No nested if** — prefer `switch` / `case` or ternary operators
- **Readable over clever** — explicit wins over concise
- Enforced via `.editorconfig` + ESLint + Prettier

## Package Layout

| Path | Content |
|------|---------|
| `dev/insightful-hub/packages/@insightful/codeSpace/` | Shared types, domain objects, enums, contracts for all products |
| `dev/insightful-hub/packages/@insightful/base/` | Base superclasses — Facelet, AppException, DomainEntity (CommonJS); Foundation used by Java codeSpace |
| `dev/ins1ght/products/life-os-v2/server/` | NestJS 11 + Drizzle (process layer) |
| `dev/ins1ght/products/life-os-v2/` | Vue 3 PWA |

## Completed Milestones

- [x] Phase 0: Linting, formatting, testing infra, npm scripts, pre-commit hooks, Docker/CI
- [x] Dev scripts: start.sh, stop.sh, status.sh, rebuild.sh with per-product compose dispatch
- [x] Root .vscode/settings.json cascade for format-on-save + ESLint + Prettier
- [x] Rename `@insightful/domain` → `@insightful/codeSpace`
- [x] Create `@insightful/base` with NestJS superclasses (Facelet, AppException, DomainEntity; Foundation for Java codeSpace JSONB entities)
- [x] Methods layer removed — superseded by simplified Stub→Facelet→Process pattern
- [x] NestJS migration — full architecture refactor complete (6 Process modules, all routes migrated)
- [x] Express API removed — NestJS is the sole API layer
- [x] Centralized compose files in `compose/*.yml`
- [x] Nginx Proxy Manager replaces manual ingress config
- [x] n8n local instance integrated into dev environment (DNS collision fixed)
- [x] Full stack verified — 20 containers, 12 compose stacks (+ `insightful.yml` aggregate), shared `insightful` network
- [x] Correlation ID middleware — UUID per request, injected into Pino log context
- [x] Redis — cache, rate limit store, Bull queue backend (`compose/redis.yml`, RedisThrottlerStorage)
- [x] Row-Level Security — RlsInterceptor wraps requests in Drizzle tx with `SET LOCAL app.device_id`/`app.user_id`, 13 table policies
- [x] Async job queue — Bull + Redis notification processor (ntfy push + n8n webhook dispatch)
- [x] Sentry error tracking — optional init in main.ts
- [x] Loki + Grafana log aggregation — `compose/observability.yml`, pino-loki transport from NestJS

## Completed & Next Steps

All 4 security/observability phases are complete:

- [x] Phase 1: Critical security fixes — JWT guard, rate limiting (`@nestjs/throttler`), CORS lock, Zod validation
- [x] Phase 2: Auth hardening — JWT refresh rotation, TTL enforcement, logout filter, password change, error codes
- [x] Phase 3: Architecture improvements — Pino structured logging, Helmet CSP, domain rules co-located
- [x] Phase 4: Polish & observability — Docker health checks, `.env.example`, error tracking, full Vue screen porting
- [x] Cross-platform container runtime abstraction (`$PODMAN` auto-detection)
- [x] Centralized compose files, bind-mounted data (`data/`)

### Forward Look

- [x] Correlation ID middleware — UUID per request, injected into Pino log context, set as response header
- [x] Redis cache + rate limit store + Bull queue backend — `compose/redis.yml`, RedisThrottlerStorage, NotificationService
- [x] Row-Level Security — RlsInterceptor wraps requests in Drizzle tx with `SET LOCAL app.device_id`/`app.user_id`, 13 tables with policies
- [x] Async job queue — Bull + Redis, processor for ntfy push and n8n webhook dispatch
- [x] Sentry error tracking — optional via `SENTRY_DSN` env var
- [x] Loki + Grafana log aggregation — `compose/observability.yml`, `pino-loki` transport ships directly from NestJS
- [ ] Add tsvector GIN indexes on JSONB columns (future perf optimization)
- [ ] Deploy to production with Nginx Proxy Manager
- [ ] RBAC roles/permissions system (future — ins1ght-dash auth gateway)

> codeSpace entity-RPC implementation phases tracked in `ai-framework/ai-memory/implementation-plan.md`.
