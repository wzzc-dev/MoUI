# Plan: All-target diagnostics cleanup

- **Status**: active
- **Goal**: Restore `moon check --target all` and remove compiler warnings outside `window/` packages.
- **Non-goals**: Changing warnings emitted from `window/` packages or altering renderer/product behavior beyond the reported diagnostics.

## Acceptance

- [x] `moon check --target all` has no errors.
- [x] All compiler warnings outside `window/` packages are resolved.
- [x] Focused affected-package checks and formatting pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-29 | Exclude `window/` package warnings exactly as requested. |
| 2026-08-02 | Wbtest-only functions (`process_exec_shell`, `process_exec_with_inherit`, `kebab_name`, `file_plan_digest`) deleted together with their tests; `moon check` does not compile `_wbtest.mbt` usage into its unused analysis. Same for derive impls used only by wbtests (`Device: Debug/Eq`). |

## Progress

| Date | Note |
|------|------|
| 2026-07-29 | Plan created; collecting the current diagnostic baseline. |
| 2026-08-02 | 68 warnings resolved (0 errors, 0 warnings for `moon check --target all`). Deprecated APIs migrated (`not()`→`!`, `substring`/StringView `to_string`→slices/`to_owned`, `Map::default`→`Default::default`, `to_repr`→`Repr`, Show-based `inspect`→`debug_inspect`, `derive(Show)` removed). Dead code deleted in `moui_cli` (unused functions, struct fields, derive impls, `@x/crypto` import) and `tools/moui` (refresh_evidence_table). Removed dead `moui verify --filter` option and dead `MobileApp`/`MobileIos`/`MobileHarmonyos` fields (JSON validation kept). Pre-existing gate debt left untouched: `moui/backend/*` fmt drift, stale `checks/api-surface-report.json`, `validate_source_file_policy` budgets, `validate_api_surface` budget wbtest (447 vs 451). |
