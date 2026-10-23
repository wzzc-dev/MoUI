# Source-file policy ratchets and the views facade test scope

## Rule

`checks/source-file-policy.json` is a ratchet registry, not a permission slip.
`scripts/check.sh --profile pr` runs `moui/validate_source_file_policy` last, and
it reports three distinct situations:

- A registered file that got **smaller** than its `maxLines` prints `logic ratchet
  can lower from A to B` and fails. The remedy is to lower that entry yourself and
  append the delta plus the reason to its `reason` string (the file records every
  adjustment inline). Tightening needs no approval.
- A file with **no** registry entry that crosses `hardLimitLines` (1200 logic
  lines) prints `classify data/generated or register an existing ratchet`. Do not
  open a new ratchet to park your own growth — split the file into a sibling in
  the same package. MoonBit `priv` items are package-private across files, so a
  split costs nothing structurally.
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
finding as either "lower the ratchet", "split the file", or "pre-existing, say so"
— never as a budget to widen. Related: `docs/testing.md`,
`checks/api-surface-report.json` (generated: `node scripts/generate-repo-docs.mjs
--write`).
