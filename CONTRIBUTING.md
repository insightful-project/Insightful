# Contributing to Insightful Projects

Welcome. Insightful is an infrastructure and platform repository — Podman Compose stacks, stack-management scripts, environment templates, and architecture documentation. Application code lives in sibling repositories (see below). Every contribution should be **lazy, correct, and minimal** — the ponytail principle.

## Development Setup

The git root is the repository root. There is no `dev/` monorepo root.

```bash
git clone https://github.com/insightful-project/Insightful.git
cd Insightful
cp compose/.env.example compose/.env
```

All services run via Podman Compose stacks in `compose/`. See `./start.sh` for the available stacks and `./status.sh` for health checks.

## Project Layout

| Path | What |
|---|---|
| `compose/` | Podman Compose stacks for all services |
| `lib/` | Shared shell helpers (mode, notify, health URLs, banner) |
| `bin/` | One-off setup scripts |
| `documentation/` | Archify architecture diagrams (JSON + generated HTML) |
| `dev/ins1ght/docs/` | Build-standard architecture specs (gitignored, private) |
| `dev/insightful-hub/ai-framework/ai-memory/` | Running-state architecture docs (gitignored, private) |

Sibling repositories, each with its own git history:

| Repository | What |
|---|---|
| `dev/ins1ght/products/life-os-v2/` | Life OS — NestJS + Drizzle + Postgres API, Vue 3 frontend |
| `dev/insightful-hub/` | Hub dashboard, `@insightful/codeSpace` shared types, `@insightful/base` |
| `encrypt/` | Encryption service |

## Code Style

See `AGENTS.md` for full conventions. Key rules:

- **Allman braces** — opening brace on its own line
- **Parentheses on all args** — never omit them
- **Ponytail principle** — laziest correct solution. YAGNI → stdlib → native → existing dep → one line. No speculative abstractions.

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new feature
- `fix:` — bug fix
- `chore:` — tooling, dependencies, CI
- `docs:` — documentation
- `infra:` — infrastructure, Docker, Compose, k8s
- `refactor:` — code change with no behavior change

Examples: `feat(stack): add ollama profile`, `fix(mode): reject invalid INSIGHTFUL_MODE`.

## Branches

This project uses three long-lived branches and no `main`:

| Branch | Purpose |
|---|---|
| `dev` | Integration branch — all work lands here first |
| `stable` | Released and verified — promoted from `dev` |
| `live` | Production — promoted from `stable` |

Never commit directly to `stable` or `live`. Work goes `dev → stable → live` via pull request.

## PR Process

1. Branch from `dev`.
2. Ensure CI passes. CI validates every compose file and runs `bash -n` over all tracked shell scripts — see `.github/workflows/ci.yml`.
3. Keep PRs focused. One concern per PR.

The Husky + lint-staged pre-commit hooks live in the Life-OS repository, not here. This repository has no enforced hooks.

## Architecture Docs — Read First

Before making significant changes, read the relevant architecture docs:

- **Build standards**: `dev/ins1ght/docs/` — architecture-map, class-hierarchy, branch-pipeline, ci-cd-standards, ops-standards
- **Running state**: `dev/insightful-hub/ai-framework/ai-memory/` — system-map, service-map, data-map, integration-map, infra-map, decision-log, implementation-plan
- **Shared contracts**: `@insightful/codeSpace` — models, rules, Zod schemas. Domain rules live here, not duplicated in service code.

Understanding the full request flow and trust boundaries before coding prevents expensive rewires.

## Need Help?

Open an issue or reach out: **kyler@insightful-projects.com**
