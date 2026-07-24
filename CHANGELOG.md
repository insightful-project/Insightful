# Changelog

All notable changes to Insightful Projects are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### [Added]
- RBAC roles/permissions system (planned — ins1ght-dash auth gateway)
- tsvector GIN indexes on JSONB columns (future perf optimization)
- Production deployment via Nginx Proxy Manager

## [0.4.0] — 2026-07-15

### [Infrastructure]
- Phase 8: Loki + Grafana log aggregation via `compose/observability.yml` with pino-loki transport

### [Added]
- Phase 7: Sentry error tracking — optional init via `SENTRY_DSN` env var

### [Changed]
- Phase 6: Async job queue — Bull + Redis processor for ntfy push and n8n webhook dispatch

### [Infrastructure]
- Phase 5: Correlation ID middleware (UUID per request, Pino context, response header)
- Phase 5: Redis cache + rate limit store + Bull queue backend (`compose/redis.yml`, RedisThrottlerStorage)
- Phase 5: Row-Level Security — RlsInterceptor wrapping Drizzle tx with `SET LOCAL app.device_id`/`app.user_id`, 13 table policies
- Cross-platform container runtime abstraction (`$PODMAN` auto-detection)
- Centralized compose files, bind-mounted data (`data/`)

## [0.3.0] — 2026-07-01

### [Changed]
- Phase 4: Polish & observability — Docker health checks, `.env.example`, error tracking, full Vue screen porting

### [Infrastructure]
- Phase 3: Pino structured logging, Helmet CSP, domain rules co-located in `@insightful/codeSpace/rules`
- Phase 3: Removed Methods layer — simplified to Stub → Facelet → Process pattern
- Phase 3: NestJS migration — full architecture refactor, 6 Process modules, all routes migrated
- Phase 3: Express API removed — NestJS is the sole API layer

## [0.2.0] — 2026-06-15

### [Infrastructure]
- Phase 2: Auth hardening — JWT refresh rotation, TTL enforcement, logout filter, password change, error codes

## [0.1.0] — 2026-06-01

### [Added]
- Phase 1: Critical security fixes — JWT guard, rate limiting, CORS lock, Zod validation

## [0.0.1] — 2026-05-15

### [Added]
- Phase 0: Linting, formatting, testing infra, npm scripts, pre-commit hooks, Docker/CI
- Dev scripts: start.sh, stop.sh, status.sh, rebuild.sh with per-product compose dispatch
- Root .vscode/settings.json cascade for format-on-save + ESLint + Prettier
- Rename `@insightful/domain` → `@insightful/codeSpace`
- Create `@insightful/base` with NestJS superclasses (Facelet, AppException, DomainEntity)
- Centralized compose files in `compose/*.yml`
- Nginx Proxy Manager replaces manual ingress config
- n8n local instance integrated into dev environment
- Full stack verified — 20 containers, 12 compose stacks, shared `insightful` network
