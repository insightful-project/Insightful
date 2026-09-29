# Developer Security Checklist

## Secret Handling

- [ ] No hardcoded secrets, API keys, tokens, or passwords in source code
- [ ] All secrets stored in `.env` files (gitignored) or Docker secrets
- [ ] `.env` added to `.gitignore` at project root
- [ ] `.env.example` committed with placeholder values and documentation
- [ ] Secrets passed to containers via `--env-file` or Docker secrets, never in compose files
- [ ] JWT tokens, API tokens stored as bcrypt hashes in the database
- [ ] `JWT_SECRET` rotated on compromise

## Container Security

- [ ] Containers run as non-root (`USER` directive in Dockerfile)
- [ ] `cap_drop: [ALL]` in compose files, only add required capabilities
- [ ] Services bind to `127.0.0.1` (host) or internal Docker network, never `0.0.0.0` unless proxied
- [ ] No privileged containers unless absolutely necessary
- [ ] Read-only root filesystem where feasible (`read_only: true`)
- [ ] Container images pinned to specific tags (not `latest`)

## API Security

- [ ] All authenticated routes require JWT Bearer token via `@nestjs/passport` guard
- [ ] Rate limiting active on all endpoints via `@nestjs/throttler` with Redis store
- [ ] CORS restricted to known origins — no wildcard in production
- [ ] Helmet middleware configured for security headers (CSP, HSTS, X-Frame-Options)
- [ ] Request body validation using Zod schemas on all DTOs
- [ ] Row-Level Security (RLS) via `RlsInterceptor` — `SET LOCAL app.device_id` / `app.user_id` per request
- [ ] No sensitive data in error responses (use generic messages, log details server-side)

## Dependency Management

- [ ] Dependabot configured for npm and Docker dependencies (`.github/dependabot.yml`)
- [ ] `npm audit` run regularly; critical/high vulnerabilities addressed promptly
- [ ] Lock files committed (`package-lock.json`) for reproducible builds
- [ ] Unused dependencies removed — YAGNI enforced
- [ ] Dev dependencies not promoted to production
- [ ] Dependency licenses reviewed for compatibility

## Deployment Checklist

- [ ] Health checks configured for every service in compose files (`healthcheck:`)
- [ ] Resource limits set (`cpus:`, `memory:`) — no unbounded containers
- [ ] Restart policies configured (`unless-stopped` for services, `no` for one-off tasks)
- [ ] Logging configured with log rotation (Docker json-file with max-size/max-file)
- [ ] Reverse proxy (Nginx Proxy Manager) handles TLS termination
- [ ] Secrets rotated on deploy if compromised
- [ ] Database migrations run before app start (Drizzle migrate)
- [ ] Monitoring dashboard (Grafana) connected for production observability
- [ ] Sentry DSN configured for error tracking (optional but recommended)
- [ ] Backup strategy in place for Postgres and Volume data

## Incident Response

- [ ] Vulnerabilities reported via SECURITY.md process
- [ ] Security patches deployed within SLA (critical: 14 days)
- [ ] Post-mortem documented for any security incident
