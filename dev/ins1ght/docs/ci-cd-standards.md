# CI/CD Standards

> **⚠️ Target Architecture**: This section describes the **intended** CI/CD pipeline.
> Current state below each recipe shows what's actually deployed.
>
> **Current CI (2026-08-06)**: The three live repos each have their own `.github/`.
> - **life-os-v2** (the product, own git repo): `.github/workflows/ci.yml` (push dev/stable/live + PR → `npm run lint` + `npm run build` + `npm test` on `/server`, `npm run build` on `/vue`), `.github/workflows/security.yml` (weekly CodeQL + Trivy), `.github/dependabot.yml` (npm `/server` + `/vue`). All verified green (lint 0 errors, tsc clean, 7/7 vitest, vue build ok).
> - **Insightful** (root infra repo): `.github/workflows/ci.yml` (validate all `compose/*.yml` via `docker compose config` + `bash -n` on all `*.sh`), `.github/dependabot.yml` (docker/`/compose`).
> - **insightful-hub**: no CI — PHP dashboard + submodules, no toolchain (composer/test) to gate. Add when a build target exists.

Every project in the monorepo follows the same CI/CD patterns. This document
defines the exact GitHub Actions workflows each project type should have.

## Current Workflow

```
life-os-v2/.github/workflows/
├── ci.yml               — ✅ lint + build + test (server) / build (vue) on push/PR
├── security.yml         — ✅ CodeQL + Trivy (weekly + on push)
└── dependabot.yml       — ✅ npm (server + vue)

Insightful/.github/workflows/
├── ci.yml               — ✅ compose config validation + bash -n on scripts
└── dependabot.yml       — ✅ docker (compose)
```

## Target Workflow Layout

These are the **planned** additions (not yet needed):
```
life-os-v2/.github/workflows/
└── deploy.yml           — ⬜ Planned (build → deploy on push to stable/live; no stable/live target exists yet)
```

## Workflow Recipes

### 1. TypeScript Package (`@insightful/*`, shared libraries)

```yaml
# pr-check.yml
name: PR Check
on: pull_request

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm test -- --coverage

  build:
    runs-on: ubuntu-latest
    needs: [lint, typecheck, test]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run build
```

### 2. NestJS Service (Life OS v2 backend)

```yaml
# pr-check.yml
name: PR Check
on: pull_request

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: lifeos_test
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm test -- --coverage
      - run: npm run test:e2e

  build:
    runs-on: ubuntu-latest
    needs: [lint, typecheck, test]
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t ${{ env.SERVICE_NAME }}:${{ github.sha }} .
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'image'
          image-ref: ${{ env.SERVICE_NAME }}:${{ github.sha }}
          severity: 'HIGH,CRITICAL'
```

### 3. Vue SPA (Life OS v2 frontend, ins1ght-dash)

```yaml
# pr-check.yml
name: PR Check
on: pull_request

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm test -- --coverage

  build:
    runs-on: ubuntu-latest
    needs: [lint, typecheck, test]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run build
```

### 4. Python Service (Odysseus)

```yaml
# pr-check.yml
name: PR Check
on: pull_request

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install ruff
      - run: ruff check .

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install mypy
      - run: mypy src/

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install -e ".[dev]"
      - run: pytest --cov=src/ --cov-report=term-missing

  build:
    runs-on: ubuntu-latest
    needs: [lint, typecheck, test]
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t ${{ env.SERVICE_NAME }}:${{ github.sha }} .
```

### 5. Java Service (codeSpace)

```yaml
# pr-check.yml
name: PR Check
on: pull_request

jobs:
  compile:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '21' }
      - run: mvn compile -B

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '21' }
      - run: mvn test -B

  build:
    runs-on: ubuntu-latest
    needs: [compile, test]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '21' }
      - run: mvn package -DskipTests -B
```

## Security Workflow (every project)

```yaml
# security.yml
name: Security Scan
on:
  schedule:
    - cron: '0 6 * * 1'   # Every Monday 6am
  push:
    branches: [dev, stable, live]

jobs:
  dependabot:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Dependabot runs automatically via .github/dependabot.yml"

  codeql:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with: { languages: javascript-typescript }
      - uses: github/codeql-action/analyze@v3

  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'HIGH,CRITICAL'
```

## Deploy Workflow

```yaml
# deploy.yml
name: Deploy
on:
  push:
    branches: [stable, live]

jobs:
  deploy:
    if: github.ref == 'refs/heads/stable'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy to staging"

  deploy-live:
    if: github.ref == 'refs/heads/live'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - run: docker compose -f docker-compose.prod.yml up -d --wait
      - run: echo "Smoke test: curl -f http://localhost:4001/health"
```

## Quality Gates (Summary)

| Gate | dev | stable | live |
|------|-----|--------|------|
| Lint | Required | Required | Required |
| Type check | Required | Required | Required |
| Unit tests | Required | Required | Required |
| Coverage | — | >= 60% | >= 80% |
| Build | Required | Required | Required |
| Security scan | — | Required | Required |
| Docker build | — | Required | Required |
| Docker scan | — | — | Required |
| Integration tests | — | Required | Required |
| Smoke test | — | — | Required |
| Reviews | 1 | — | 2 |

## Dependabot Configuration

Place this in every project:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
    groups:
      development-dependencies:
        dependency-type: "development"
      production-dependencies:
        dependency-type: "production"

  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
```

## Agent Instruction

When setting up CI for a new project:
1. Copy the appropriate workflow recipe from above
2. Place it in `.github/workflows/pr-check.yml`
3. Ensure `package.json` (or equivalent) has the required npm scripts
4. Add `Dockerfile` if the project is a deployable service
5. Add `.github/dependabot.yml`
6. Verify workflows run on first PR

## Next Steps

- [x] Add ESLint + Prettier to every TypeScript project (life-os-v2 server + vue)
- [ ] Add Ruff + Black/mypy to Odysseus (Python repo)
- [x] Add test scripts to server package.json (vitest preset)
- [x] Create `.github/workflows/` in life-os-v2 + Insightful root
- [x] Add `.github/dependabot.yml` to life-os-v2 + Insightful root
- [ ] Implement coverage thresholds in CI (enforce >= 60% test / >= 80% live in coverage gate)
- [ ] Set up branch protection rules matching quality gates
- [ ] Add `deploy.yml` once a stable/live deployment target exists (currently local podman / no VPS)
