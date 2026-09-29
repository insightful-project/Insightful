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
| `integration-map.md` (Auth Flow) | `auth-flow` | sequence |
| `data-map.md` | `data-map.erd` (planned) | dataflow |
| `branch-pipeline.md` + `ci-cd-standards.md` | `branch-pipeline` (planned) | workflow |
| `decision-log.md` | `decision-log.timeline` (planned) | lifecycle |
| `class-hierarchy.md` | `class-hierarchy` (planned) | architecture |

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
- Additional drill-downs: hub/codespace, ollama, infra-utilities