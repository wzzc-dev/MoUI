# Source-file policy ratchets and the views facade test scope

## Rule

`checks/source-file-policy.json` is a ratchet registry, not a permission slip.
`scripts/check.sh --profile pr` runs `moui/validate_source_file_policy` last, and
it reports three distinct situations:

- Every `logic` ceiling is a **quantum**, not a snapshot: `maxLines` must be a
  multiple of `logic.budgetStepLines` (25 lines), and a file that grows inside its
  quantum needs no registry edit. Shrinking a file no longer fails either — the
  old `logic ratchet can lower from A to B` error was removed on 2026-10-25 because
  it made every net-negative change pay a governance-file commit. Re-quantizing a
  ceiling downward is a courtesy for the next time you touch that file, with the
  delta and reason recorded in its `reason` string as before.
- A file with **no** registry entry that crosses `hardLimitLines` (1200 logic
  lines) prints `classify data/generated or register an existing ratchet`. Do not
  open a new ratchet to park your own growth — split the file into a sibling in
  the same package. MoonBit `priv` items are package-private across files, so a
  split costs nothing structurally. The two files that crossed the hard limit on
  main (`examples/new_world/app/update.mbt` at 1589 lines and `world_store.mbt`
  at 1330) were split this way on 2026-10-25 into `model_accessors.mbt`,
  `update_helpers.mbt`, and `world_store_parse.mbt`. Do not pre-register another
  session's in-flight growth on their behalf.
- Entries whose `maxLines` is already exceeded by an **unmodified** file are
  pre-existing debt on main. Prove it with `git diff --stat -- <path>` (empty
  means HEAD produces the same count) and report it instead of quietly raising
  the budget.

Second trap: `moui/views` is a facade package. `moon test moui/views --target
native` runs only the facade's own tests; controls/text/layout/form/... are
separate packages with their own `moon.pkg` and `pkg.generated.mbti`. Scroll-view
tests live in `moui/views/controls`, not the facade, so a green `moui/views` run
says nothing about them. Enumerate the subpackage list when a change spans them.

The API budget table caps only `moui/views/pkg.generated.mbti` (the facade). A
shared private helper therefore cannot cross subpackages; the established pattern
is a small `pub fn` in `moui/views/common` (e.g. `view_max_double`) rather than
widening the facade.

## Why

Both traps silently understate verification: a ratchet entry can be raised to
swallow growth exactly like a skipped test, and a facade-only test run looks green
while the changed subpackage never ran.

## How to apply

Run the affected subpackages explicitly, and treat any `validate_source_file_policy`
finding as either "re-quantize the ceiling", "split the file", or "pre-existing,
say so" — never as a budget to widen. Related: `docs/testing.md`,
`checks/api-surface-report.json` (generated: `node scripts/generate-repo-docs.mjs
--write`).
