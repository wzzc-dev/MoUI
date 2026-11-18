# Docs publication set and line budget

## Publication set

- `website/docs-catalog.json` `entries` is the authoritative published set: only
  get-started (5), guides (12), and examples (5) slugs, 22 total.
- zh-Hans parity is enforced over that set only. A published slug without a
  locale entry, a locale entry without a translation, and a locale entry for an
  unpublished slug all fail. Pages that are English-only live in `excluded` with
  a one-line reason and must still exist on disk.
- `docs/moui-readme.md` and `docs/moui-skia-readme.md` are virtual catalog paths
  (they map to `README.md` / `moui_skia/README.mbt.md`) and cannot be excluded.
- `scripts/package-website-site.sh --verify` sentinels are
  `docs/getting-started.md` and its zh-Hans twin; `docs/architecture.md` is no
  longer published.
- After moving a published page, run `node scripts/sync-website-docs.mjs` and
  `node scripts/check-website-docs.mjs`.

## Line budget

- `checks/doc-budget.json` counts tracked `docs/**/*.md` only (not the generated
  website mirror, not `memories/repo`). Ceiling is 40,000 lines, gated by
  `node scripts/validate-doc-budget.mjs` in the `pr-static` profile.
- `docs/plans/done/INDEX.md` is the archive: one row per retired plan (stem,
  outcome, commit sha + date). `docs/ai-sessions/` keeps six themed summaries
  (renderer/GPU, text/editors, platform readiness, TUI/input,
  toolchain/CI/release, examples/harness/cadence), not per-date logs.
