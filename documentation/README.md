# Documentation — Archify Diagram Store

Committed artifact store for architecture diagramming in Insightful.

Generated with the **archify** skill (install: `~/.config/opencode/skills/archify`).
Sources are typed JSON; delivered artifacts are self-contained HTML. This
directory is the single source of truth — Obsidian, Google Workspace, and
n8n consume copies pushed from here.

## Layout

| Path | Purpose |
|------|---------|
| `architecture/` | system-map / infra-map / class-hierarchy family |
| `sequence/` | integration-map interaction flows (auth, request, sync) |
| `workflow/` | branch-pipeline, ci-cd gates, task automation |
| `dataflow/` | data-map ERD, pipelies, lineage |
| `lifecycle/` | decision-log chronologies, state machines |
| `README.md` | this manifest |

Each diagram is a pair: `<name>.<type>.json` (source) + `<name>.<type>.html`
(delivered). PNG/SVG exports are committed when produced (manual viewer export).

## Doc → Diagram map

| Source doc | Diagram | Type |
|---|---|---|
| `system-map.md` + `infra-map.md` | `system-overview` | architecture |
| `infra-map.md` (lifeos drill-down) | `life-os.runtime` | architecture |
| `infra-map.md` (utility layer) | `infra-utilities` | architecture |
| `system-map.md` (hub module) | `insightful-hub` | architecture |
| `codespace-architecture.md` | `class-hierarchy` | architecture |
| `redaction-contract.md` + `Decision.ts` | `jev-decision` | architecture |
| `integration-map.md` (Auth Flow) | `auth-flow` | sequence |
| `data-map.md` | `data-map.erd` | dataflow |
| `branch-pipeline.md` + `ci-cd-standards.md` | `branch-pipeline` | workflow |
| `ins1ght-platform` n8n exports | `whatsapp-finance` | workflow |
| `decision-log.md` | `decision-log.timeline` | lifecycle |

## Coverage

Every module and platform in the repo now has at least one diagram.

| Module / platform | Covered by |
|---|---|
| Full stack, 20 containers | `system-overview` |
| Life OS v2 runtime | `life-os.runtime` |
| Hub, codeSpace, codespace-java, MCP | `insightful-hub`, `class-hierarchy` |
| NPM, oauth2-proxy, Redis, Loki, Ollama | `infra-utilities` |
| Jev decision service | `jev-decision` |
| ins1ght-platform n8n flows | `whatsapp-finance` |
| Repo process | `branch-pipeline` |
| Data layer | `data-map.erd`, `auth-flow` |
| Decisions | `decision-log.timeline` |

Not yet diagrammed: the three static submodules (`encrypt`, `insight-web`,
`Valentines-Web`) — no compose file references them, so they have no runtime
topology to draw.

## Workflow

1. **Edit the source doc first** — the markdown is ground truth.
2. **Regenerate affected diagrams**: author JSON, then
   ```
   node ~/.config/opencode/skills/archify/bin/archify.mjs validate <type> <candidate.json> --quality showcase --json
   node ~/.config/opencode/skills/archify/bin/archify.mjs deliver  <type> <candidate.json> <name>.<type>.html --quality showcase --json
   ```
3. **Quality gate**: showcase acceptance = all 9 artifact checks pass, 0
   composition errors, 0 warnings. Basic 4-check pass is never acceptance.
   Apply only the `diagnostics[].supportedFixes` listed in the receipt.
4. PNG export is a manual viewer step (Export menu) — the running HTML opens
   with `--open` after delivery.

## Sync

One-way idempotent copy, canonical → mirrors:

```
./scripts/archify-sync.sh                     # → default Obsidian vault
./scripts/archify-sync.sh --target <dir>      # → arbitrary mirror (Phase 2: Google Workspace / n8n)
```

Never write back to this directory from a mirror.

## Phase 2 hooks (parked)

- Google Workspace sync of the mirrored artifacts for client sharing
- n8n workflow that re-runs `archify-sync.sh` on doc change
- PNG/SVG export of the four newest diagrams for client decks

## Verification status

All ten diagrams pass the showcase gate: 9/9 artifact checks, 0 composition
errors, 0 warnings. `deliver` receipts (spec + artifact SHA-256) are in each
commit that added a diagram.

`visual-check` has **not** run on any diagram in this store. Windows Chrome
exists at `/mnt/c/Program Files/Google/Chrome/Application/chrome.exe` but its
DevTools pipe cannot cross the WSL boundary — `read ECONNRESET`, "Remote
debugging pipe file descriptors are not open". Browser evidence and perceptual
visual review are therefore both outstanding, and no claim is made about them.