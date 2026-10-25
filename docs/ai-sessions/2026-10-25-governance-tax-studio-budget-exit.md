# 2026-10-25 — Governance tax: studio budgets exit the main repo, ratchet de-quantized

- Workspace: MoUI, `main` working tree. Nothing committed during the session; the
  previous session's `declaration_*` removal was already carried by `d73524c12`.
- Plan: this session's three items came out of the four-dimension project
  analysis: move MoUI Studio budgets out of the main repo, pay the migration-note
  debt for that removal, and cut the governance tax on source-size bookkeeping.

## The failure mode that justified item one

`scripts/check.sh --profile pr` was red on the maintenance baseline with five
findings, all of them about `moui_studio`. The remedy was not reachable from this
repository, and proving *why* is the durable part:

- `moui_studio` is a gitlink (`160000 commit ef2a56f12`) since `80317ec80`
  (2026-10-09), and `moui_studio/.git` points at `.git/modules/moui-studio`, whose
  `core.worktree` is an absolute path inside a *different* worktree
  (`/Users/zc/Workbuddy/Worktrees/MoUI/main-e3837a04/moui_studio`).
- So the `moui_studio/` directory in this checkout is tracked by no git at all.
  Measuring both copies proved the divergence: `app/app.mbt` is 2686 lines here and
  2682 in the pinned commit, and the four shell counters read 27,531 / 113 / 242
  locally against 27,374 / 111 / 238 in the pinned tree — which are exactly the
  registered `max_count` values.
- Meaning: CI (which checks submodules out recursively) was green, and every local
  maintainer saw a red gate whose fix lives in another repository. The main repo had
  been keeping another repo's ledger for two weeks, in a file
  (`studio_shell_budgets.mbt`) created three days *after* the split and edited 17
  times since.

The same boundary was already written down in `docs/testing.md` for
`checks/source-file-policy.json` ("main repo roots only, studio has parallel CI").
The maintenance baseline was the leak, not the policy. Lesson: when a gate fails in
a way you cannot fix locally, first check whether it is measuring content that git
here does not own — do not "fix" the number.

## Ratchet anatomy, and what got cut

`checks/source-file-policy.json` held 50 `logic` ratchets, and all 50 sat at
`maxLines == measured`. The validator also failed when a registered file got
*smaller*, so the designed behaviour was: any net-negative diff must also edit a
governance file. Measured cost: 52 of 235 commits in the last 30 days touched that
one JSON file (62 of 235 including the maintenance-baseline tool directory).

Chosen cut, in the owner's words, "只拆双向 + 量化余量":

- the shrink failure branch is gone;
- ceilings are now quanta — `logic.budgetStepLines = 25`, every `maxLines` rounded
  up to a multiple of it (612 lines of headroom total, ~12 per file), and the
  validator fails a ceiling that is not on the quantum.

The modulo rule is load-bearing: without it the registry silently re-pins itself to
measured values, which is precisely the state that produced the tax. The rounding is
also its own proof that the shrink branch is gone — all 50 files now sit below their
ceiling and nothing complains.

Explicitly *not* changed: a new `.mbt` file over `hardLimitLines` (1200) still needs
a human to classify or register it. The owner kept that friction on purpose, so
`examples/new_world/app/update.mbt` (1589) and `world_store.mbt` (1330) stay red
until their author registers or splits them. Not touching another session's
in-flight files outranked the wish for a green profile.

## Documentation honesty, cheapest fix first

`docs/invariants.md` cited a "runtime-neutrality validator" and an "app-state
ownership validator" that do not exist as files. They are not missing gates — both
checks live in `tools/moui/validate_runtime_state_render_ownership`, whose own usage
text says so. So the fix was a rename, not a downgrade to "code review". Two real
JS validators (`validate-core-theme-no-control-surface.mjs`,
`validate-host-import-baseline.mjs`) were documented as "every commit" but appeared
zero times in `checks/profiles.json`; both were green when run by hand, so wiring
them into `pr` cost nothing and made the doc true.

Deferred on purpose: `docs/view-catalog.md` claims "57 of the 63 node types
implement `declaration()`". Three measurement methods gave 36 (the P17 gate, `moui/`
only), 39 (same scope, own scan) and 42–47 (wider scopes with different pairing
rules). Until the definition is pinned down, leaving a suspicious number beats
replacing it with a differently wrong one.

## Verification actually run

`moon -C tools test --target native` 106/106; maintenance baseline, source-file
policy, check-profile catalog, guidance consistency, doc references, API surface,
P17 coverage, ecosystem metadata, and both newly wired validators all green
individually. The full `pr` profile could not be used as the closing signal: it
aborts early on `validate-window-dependency`, which is pre-existing — the tracked
`checks/window-dependency-exception.txt` still enables the Provider Phase E
local-window exception while `moon.work` lists no local window members. That file
was left alone deliberately; its remedy touches CI for other work.

## Follow-ups handed off

- Rebuild the four shell counters inside the `moui_studio` repo (counting rules and
  the "no B/C-stage claims before the gate exists" rule are in
  `docs/plans/active/moui-studio-shell-completion.md`); its CI currently runs only
  "Workspace baseline (check + fmt)".
- `checks/compatibility-policy.json` said `0.1.x` while `moui/moon.mod` is at
  `0.2.4`; corrected, but the file's `apiTiers` have no reader
  (`scripts/validate-ecosystem-metadata.mjs` never consults them).
- `view_declaration_auto` covers 2 of ~36 `declaration()` blocks. Widening it is the
  next step if a third control copies a hand-built key block — still no generator.
