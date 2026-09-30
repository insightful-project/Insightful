#!/usr/bin/env bash
# One-way canonical → mirror sync for archify diagrams.
# Canonical source: documentation/ (git). Mirrors: Obsidian, phase-2 targets.
# Idempotent: rerunning copies new/changed files; copy-only by design — files
# deleted from the canonical store are kept in the mirror (no deletes).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/documentation"
VAULT=""
for cand in "${HOME}/Documents/Obsidian Vault" "/mnt/c/Users/${USER:-kyler}/Documents/Obsidian Vault"; do
  if [[ -d "${cand}" ]]; then VAULT="${cand}"; break; fi
done
[[ -n "${VAULT}" ]] || { echo "Obsidian vault not found; pass --target <dir>" >&2; exit 1; }
TARGET="${VAULT}/10-Projects/Insightful/Diagrams"

usage() { local code="${1:-1}"; echo "usage: $0 [--target <mirror-dir>]"; exit "$code"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
   ( --target) TARGET="${2:?missing arg}"; shift 2 ;;
   ( -h|--help) usage 0 ;;
   (*) usage 1 ;;
  esac
done

[[ -d "$SRC" ]] || { echo "source missing: $SRC" >&2; exit 1; }
mkdir -p "$TARGET"

if command -v rsync >/dev/null 2>&1; then
  rsync -a "$SRC/" "$TARGET/"
else
  cp -a "$SRC/." "$TARGET/"
fi

echo "archify diagrams synced -> $TARGET"
echo "source: $SRC"
echo "html: $(find "$TARGET" -name '*.html' | wc -l)  json: $(find "$TARGET" -name '*.json' | wc -l)"