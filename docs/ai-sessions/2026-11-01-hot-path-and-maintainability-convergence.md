# 2026-11-01: Hot-path convergence execution + maintainability second round

- **Agent**: GLM-5.3-Flash via ZCode
- **Goal**: Execute the 2026-10-31 architecture analysis plan
  (`hot-path-invalidation-boilerplate-convergence`, 10 workstreams / 24
  acceptance items), organize slice-by-slice commits, analyze module
  dependencies, fix the momark breakage, then land the second-round
  maintainability plan (`cohesion-governance-convergence`).
- **Outcome**: Success. All 24 items landed and verified (`pr` profile
  twice); 16 slice commits + momark fix; dependency sweep clean; second
  plan created and executing.

## Summary

Three exploration tracks (core/runtime, backend/render, views/examples)
fed a ten-workstream plan executed over one session with parallel
subagents per package group. Key structural finds fixed along the way:
theme/environment scope modifiers declared Constant channels (subtree
theme switching never invalidated), the P17 declaration gate paired
structs/impls per file and scanned nothing after codegen, and PlanOp
lowering was a pure per-frame DTO copy. Governance follow-ups: 8 stale
active plans archived, structure triggers pre-written, session lessons
deposited.

## Key Decisions

- D1 fingerprinting must cover message identity via latest-commands
  indirection, not ActionCommand equality — commands' messages may depend
  on the model while their ActionCommand fields do not.
- D3 diagnostics gate became a single-traversal fold
  (`EffectPlanRunSummary`) instead of an on/off knob: zero extra walk,
  diagnostics values unchanged, no API surface.
- `View::theme`/`View::environment` scopes key their declarations on the
  scoped value (new `environment_scope_declaration`) — without it the
  examples' ambient-theme migration had no valid mechanism.
- F1 whole-subtree skip and cross-rebuild wrapper reuse were rejected with
  evidence (children are fresh values; stale closures); landed the
  Exact-semantics-channel shortcut + identity snapshot instead.
- F3 stayed FullSurface for 4/5 scenarios on evidence (force-full rebuild
  classes, sibling resizes outside the dirty set); narrowing lever
  documented for a future slice.
- E2 deleted PlanOp outright (zero production diagnostics consumers);
  renderers match `@core.DrawCommand` directly.
- Commit organization: dependency-ordered slices; inseparable
  file-level changes merged into one slice commit; generated
  interfaces/snapshots/ratchets in a trailing chore commit with inline
  reasons.

## Discoveries

- full_cycle benchmarks on this host class swing ±40% between runs;
  warm second-run + stash comparison is the only usable method
  (→ `memories/repo/benchmark-variance.md`).
- A green validator can hide a scanned=0 hole: P17 needed an end-to-end
  delete-a-field drill (→ `memories/repo/declaration-gate-pairing.md`).
- moon.pkg `for "test"`/`for "wbtest"` sections must be excluded when
  auditing production dependency edges; three "forbidden edge" hits were
  all test-section imports.
- `find -name A -o -name B` on BSD find drops matches without explicit
  grouping — a dependency scan that reports 394 vs 1153 files is a
  find-precedence bug, not reality.
- momark (standalone submodule, not a workspace member) pins registry
  versions; after the parent moved text providers, its module-wide solve
  failed. Fix is manifest-path swap with unchanged aliases; provider
  constructor names were identical across the move.
- Module-level dependency edges hide package-level truth: the framework
  module's only module edge is `wzzc-dev/moui -> window`, but the
  package graph (core zero-dep, views production-zero runtime, backend
  root core-only) is what actually carries the invariants.
