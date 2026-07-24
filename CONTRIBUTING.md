# Contributing to Insightful Projects

Welcome. We build internal tools across a monorepo of services — NestJS + Drizzle backends, Vue 3 frontends, a Python AI workspace (Odysseus), a PHP dashboard, and Java Spring Boot services. Every contribution should be **lazy, correct, and minimal** — the ponytail principle.

## Development Setup

The git root is `dev/` — the monorepo root above it is **not** a git repo.

```bash
git clone <url> dev
cd dev/ins1ght/products/life-os-v2/server && npm install
cd dev/ins1ght/products/life-os-v2/vue && npm install
```

All services run via Podman Compose stacks in `compose/`. See `./start.sh dev` to bring up everything.

## Project Layout

| Path | What |
|---|---|
| `dev/ins1ght/products/life-os-v2/server/` | NestJS + Drizzle ORM + Postgres + Redis |
| `dev/ins1ght/products/life-os-v2/vue/` | Vue 3 + Vite + Pinia + Dexie |
| `dev/insightful-hub/packages/@insightful/codeSpace/` | Shared types, models, rules |
| `dev/insightful-hub/packages/@insightful/base/` | NestJS superclasses |
| `odysseus/` | Python AI workspace + LLM proxy |
| `dev/insightful-hub/` | PHP dashboard |
| `compose/` | Podman Compose stacks for all services |
| `dev/ins1ght/docs/` | Build-standard architecture specs |
| `dev/insightful-hub/ai-framework/ai-memory/` | Running-state architecture docs |

## Code Style

See `AGENTS.md` for full conventions. Key rules:

- **Allman braces** — opening brace on its own line
- **Parentheses on all args** — never omit them
- **Ponytail principle** — laziest correct solution. YAGNI → stdlib → native → existing dep → one line. No speculative abstractions.

Pre-commit hooks (Husky + lint-staged) run `eslint --fix` on staged `.ts`/`.js` files. Make sure they pass before pushing.

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new feature
- `fix:` — bug fix
- `chore:` — tooling, dependencies, CI
- `docs:` — documentation
- `infra:` — infrastructure, Docker, Compose, k8s
- `refactor:` — code change with no behavior change

Examples: `feat(server): add metrics endpoint`, `fix(vue): correct date formatting`.

## PR Process

1. Branch from `main` — follow the branch-pipeline docs in `dev/ins1ght/docs/branch-pipeline.md`.
2. Ensure CI (GitHub Actions in `dev/.github/workflows/ci.yml`) passes — lint, typecheck, tests.
3. Pre-commit hooks are enforced — don't skip them.
4. Keep PRs focused. One concern per PR.

## Architecture Docs — Read First

Before making significant changes, read the relevant architecture docs:

- **Build standards**: `dev/ins1ght/docs/` — architecture-map, class-hierarchy, branch-pipeline, ci-cd-standards, ops-standards
- **Running state**: `dev/insightful-hub/ai-framework/ai-memory/` — system-map, service-map, data-map, integration-map, infra-map, decision-log, implementation-plan
- **Shared contracts**: `@insightful/codeSpace` — models, rules, Zod schemas. Domain rules live here, not duplicated in service code.

Understanding the full request flow and trust boundaries before coding prevents expensive rewires.

## Need Help?

Open an issue or reach out: **kyler@insightful-projects.com**
