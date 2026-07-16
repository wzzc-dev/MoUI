# Agent harness entry (2026-07)

- Cold start: `AGENTS.md` (map) → `docs/INDEX.md` → task pages only.
- One-page packages: `docs/architecture-map.md` before full `architecture.md`.
- Sole constraints: `docs/invariants.md`. Sole validation policy: `docs/testing.md`.
- Taste / residue: `docs/golden-principles.md`.
- Multi-package work: `docs/plans/active/`. Batch1 plan: `docs/plans/done/harness-mechanize-invariants-batch1.md`.
- Do not grow `AGENTS.md` into an encyclopedia; link instead of duplicating tables.
- A6 window pins: `node scripts/validate-window-dependency.mjs` (four consumers + no `./window` in moon.work).
- M5 Harmony shell: `node scripts/validate-harmonyos-shell.mjs` (no `.onTouch`; XComponent only).
- P1/P2/R3/G1: `node scripts/validate-harness-invariants.mjs` (`--json` for machine summary).
