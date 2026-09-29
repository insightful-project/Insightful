# Branch Pipeline — dev → stable → live

> **⚠️ Target Architecture**: This describes the intended branching model and CI gates.
> `dev`, `stable`, and `live` branches exist (created 2026-08-17 from dev HEAD, all repos).
> Branch protection and full CI pipeline are planned.

Every project follows the same three-branch flow. This is how code moves from
development to production, with CI gates at every step.

## The Three Branches

```
dev (default branch)
  │
  │  Purpose: Daily development
  │  Base branch: always the starting point
  │  CI gates: lint → typecheck → test
  │  Auto-deploy: optional (dev server)
  │  Who pushes: all developers
  │
  ▼
stable
  │
  │  Purpose: Integration + QA + staging
  │  Base branch: created from dev
  │  CI gates: lint → typecheck → test → build → security scan
  │  Auto-deploy: staging environment
  │  Who merges: PR from dev, reviewed
  │
  ▼
live
  │
  │  Purpose: Production
  │  Base branch: created from stable
  │  CI gates: lint → typecheck → test → build → docker build → docker scan → smoke test → deploy
  │  Deploy strategy: rolling update (zero-downtime)
  │  Who merges: PR from stable, reviewed + approved
  │
  ▼
  Production
```

## PR Flow

### dev → stable

```yaml
# .github/workflows/pr-dev-to-stable.yml
on:
  pull_request:
    branches: [stable]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test -- --coverage

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
```

### stable → live

Everything from dev → stable, plus:

```yaml
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'HIGH,CRITICAL'
          format: 'sarif'

  docker-build:
    needs: [lint, typecheck, test, build, security-scan]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t ${{ env.IMAGE }}:${{ github.sha }} .
      - name: Trivy Docker scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'image'
          image-ref: ${{ env.IMAGE }}:${{ github.sha }}
          severity: 'HIGH,CRITICAL'

  deploy:
    needs: [docker-build]
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy to production"
```

## Hotfix Path

For urgent production fixes that cannot wait for the normal pipeline:

```
Fixed on dev → cherry-pick to live → hotfix PR on live
                       │
                       ▼
              CI: lint → typecheck → test → build → docker → deploy
                       │
                       ▼
              After hotfix: merge live back to dev
```

- Hotfix PRs bypass the stable branch but still run all CI gates
- Every hotfix must be merged back to dev after deployment
- Limit: max 3 hotfixes per week before a full stable→live cycle is required

## Branch Protection Rules

### dev

- Require pull request before merging
- Require status checks: lint, typecheck, test
- Require branches to be up to date

### stable

- Require pull request before merging
- Require status checks: lint, typecheck, test, build, security-scan
- Require at least 1 review
- Require branches to be up to date
- Do not allow bypass

### live

- Require pull request before merging
- Require status checks: all (lint, typecheck, test, build, security-scan, docker-build)
- Require at least 2 reviews
- Require branches to be up to date
- Do not allow bypass
- Include administrators

## Real-Time Patching

When deploying to live, zero-downtime is enforced by:

1. Rolling update in Docker Compose
2. Healthcheck endpoint on every service
3. Graceful shutdown (SIGTERM → drain connections → exit)
4. At least 2 replicas during deployment

```yaml
# docker-compose.yml (production)
services:
  api:
    image: ${IMAGE}:${TAG}
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://localhost:4001/health')"]
      interval: 15s
      timeout: 5s
      retries: 3
    stop_grace_period: 30s
```

## Environment Mapping

| Branch | Environment | URL | Database |
|--------|-------------|-----|----------|
| dev | Development | dev.insightful.local | dev-postgres |
| stable | Staging | stable.insightful.local | stable-postgres |
| live | Production | app.insightful.local | prod-postgres |

## Agent Instruction

When starting new work:
1. Branch from `dev`
2. Create a feature branch: `feat/your-feature-name`
3. Open PR to `dev` — CI runs lint → typecheck → test
4. Once merged to dev, open PR to `stable` — full CI runs
5. Once merged to stable, open PR to `live` — full CI + security + deploy
6. Hotfix? Branch from dev, cherry-pick fix, PR directly to live

## Next Steps

- [ ] Create `.github/workflows/` in every project with the above patterns
- [ ] Configure branch protection rules on GitHub
- [x] Add healthcheck endpoints to every service (2026-07-13: all 11 compose files / 17 services hardened)
- [ ] Add graceful shutdown handlers to every service
- [ ] Set up rolling update config in production compose files
- [ ] Document the hotfix process for the team
