# Plan: Package cohesion, governance hygiene, and structure triggers

- **Status**: active
- **Goal**: Land the second-round maintainability findings (2026-11-01) as four workstreams:
  (A) in-package cohesion of oversized core/views files and duplicated helpers,
  (B) non-breaking `ViewSemanticsInfo` construction ergonomics, (C) governance hygiene
  (plan archival, session knowledge deposit, budget-catalog review cadence), (D) pre-written
  structure triggers (core split threshold, backend/common runtime-import allowlist,
  MoonBit-blocker reopen checklist) so future growth carries its own review signals.
- **Non-goals**: no package-level split of `moui/core` (trigger-gated, see D1); no removal of
  the `views/style` pass-through layer (documented backward-compat surface, ADR 0017 era);
  no `embedded/` directory move (I2 decision stands); no `HostRuntimeDriver` redesign
  (D2 mechanizes the review trigger instead); no breaking public API changes.

## Background

Post-convergence follow-up to
[hot-path-invalidation-boilerplate-convergence](hot-path-invalidation-boilerplate-convergence.md)
(moved to done/ in this plan's C1). Evidence at HEAD:

1. `moui/core/gesture.mbt` (1058 lines) mixes gesture recognizer state machines (lines
   ~2-415) with the command system (`CommandIntent`/`ActionCommand`/`KeyboardShortcut`/
   `ActionCommandMap`, lines ~416-1058); `text_editing.mbt` (819 lines) mixes caret
   motion, undo/redo history, word/grapheme boundaries, IME composition, and shortcut
   predicates. File-level domain splits, no package changes.
2. Duplicated views helpers survive at HEAD: `max_view_double`/`min_view_double`
   (`views/common/control_helpers.mbt:24-40`) vs `view_max_double`/`view_min_double`
   (`views/common/view_control_helpers.mbt:195-219`); 8 `resolve_*` Option-fallback
   variants across control files. The `views/style` pass-through layer (971 lines) is a
   documented compat surface and stays.
3. `ButtonTransitionState` + `view_button_next_state`
   (`views/common/view_control_helpers.mbt:275-374`) is generic pressable-transition
   infrastructure used only by `button.mbt`; checkbox/toggle/slider have no transitions
   and each new animated control rewrites ViewStateValue encode/decode boilerplate.
4. `ViewSemanticsInfo` carries 26 mostly-Option fields; construction is the daily cost
   (every control), comparison is derived. A breaking regroup is not justified without
   profile evidence; grouped constructor helpers are the non-breaking 80%.
5. Governance: 8 of 29 `docs/plans/active/` plans are fully checked but not archived
   (measured 2026-11-01); this session's lessons (P17 per-file pairing hole, benchmark
   noise methodology under ±40% run variance, multi-slice commit organization) are not
   yet deposited to `memories/repo/` / `docs/ai-sessions/`; `line_budget_catalog.mbt`
   has grown to ~190 hand-curated entries with no review cadence.

## Acceptance

- [x] A1: command system (`CommandIntent`/`ActionCommand`/`KeyboardShortcut`/bindings/map)
      moves from `gesture.mbt` to `core/command.mbt`; no public API change (same package);
      core tests green
- [x] A2: `text_editing.mbt` split into caret-motion / undo-redo history / word-boundary
      files; no public API change; core tests green
- [x] A3: one min/max helper set remains in `moui/views/common` (the other deleted, call
      sites updated); the 8 `resolve_*` variants collapse onto shared helpers; views tests
      green; no pub API removal beyond intra-package helpers
- [x] A4: pressable-transition infrastructure extracted to a shared slot/helper; button
      migrated with byte-identical behavior (existing button transition tests pass);
      checkbox/toggle wiring optional and behavior-tested if landed
- [x] B1: grouped `ViewSemanticsInfo` constructor helpers land (non-breaking; flat struct
      retained); at least the control/semantics construction sites in `moui/views` with 8+
      field spreads adopt them; core/views/runtime/agent tests green; mbti delta reviewed
      with `moon info`
- [x] C1: all fully-checked active plans archived to `done/` with README table moves
      (including hot-path-invalidation-boilerplate-convergence); plan index consistent
- [x] C2: this session's durable lessons deposited: `memories/repo/` entries
      (P17 package-level pairing, benchmark noise methodology, ratchet-in-same-commit
      practice) + `docs/ai-sessions/` entry for the two-slice convergence execution
- [x] C3: budget-catalog review cadence recorded in `docs/maintenance.md` (the ratchet
      authority): catalogs are re-reviewed at release review, stale entries (paths gone,
      budgets untouched for N releases) flagged
- [x] D1: structure trigger table added to `docs/golden-principles.md`: core package split
      threshold (mbti > ~3.5k or 8th domain), `HostRuntimeDriver` seam review condition,
      MoonBit toolchain upgrade checklist (reopen debt notes: viewnode-trait
      decomposition blockers, manual Eq+Hash keys), new-renderer touchpoint pointer
- [x] D2: `checks/backend-common-ownership.json` gains an explicit allowlist of
      backend/common packages/files that may import `wzzc-dev/moui/runtime` (enumerating
      the current production set); the validator fails on new entries with a message
      pointing at the D1 review trigger; validator green at HEAD

## Slices

| Slice | Content | Key files |
|-------|---------|-----------|
| A1 | Split command system out of gesture.mbt | moui/core/gesture.mbt, moui/core/command.mbt (new) |
| A2 | Split text_editing.mbt by domain | moui/core/text_editing.mbt (+2 new files) |
| A3 | Unify min/max and resolve_* helpers | moui/views/common/{control_helpers,view_control_helpers}.mbt, control files |
| A4 | Shared pressable-transition slot | moui/views/common/view_control_helpers.mbt, moui/views/button/button.mbt (+optional checkbox/toggle) |
| B1 | Grouped semantics constructors | moui/core (ViewSemanticsInfo), moui/views construction sites |
| C1 | Archive fully-checked plans | docs/plans/{active,done}/, docs/plans/README.md |
| C2 | Deposit session knowledge | memories/repo/, docs/ai-sessions/ |
| C3 | Budget-catalog review cadence | docs/maintenance.md |
| D1 | Structure trigger table | docs/golden-principles.md |
| D2 | runtime-import allowlist for backend/common | checks/backend-common-ownership.json, validator |

Execution order: C1 → C2 → D2 → D1 → A1 → A2 → A3 → A4 → B1. Governance first (it
closes the previous plan cleanly and defines the triggers the rest must respect);
A/B slices are independent and can interleave.

| 2026-11-01 | Governance slices landed. C1: 8 fully-checked plans archived to done/ (status lines rewritten, README rows moved, 7 live docs re-pointed from plans/active to plans/done, RFC 0007 reference fixed); 21 active plans remain. C2: `memories/repo/benchmark-variance.md` + `memories/repo/declaration-gate-pairing.md` + `docs/ai-sessions/2026-11-01-hot-path-and-maintainability-convergence.md`. D2: backend-common-ownership.json now pins runtime importers as required (common root, lifecycle, input, embedded) and forbids runtime in 8 sibling packages (frame/image/image-native/host_modal/services family) — the existing boundary validator enforces the allowlist with zero new validator code; 22 rules, validator green. D1: structure triggers 18-21 added to golden-principles (core split threshold, HostRuntimeDriver seam review + allowlist pointer, MoonBit upgrade reopen checklist, renderer touchpoints). C3: budget-catalog review cadence paragraph in maintenance.md. |

| 2026-11-01 | A1-A4 done (two parallel agents). A1: command system moved to `core/command.mbt` (286 lines) — actual layout had types at 415-467 interleaved with methods 827-1058, no private gesture↔command coupling; gesture.mbt 1058→772. A2: caret(226)/word(260)/composition(331) split; plan correction — undo/redo history already lived in `text_history.mbt`, renamed `text_editing_history.mbt` (git 100% rename). Byte-exact move proof, core mbti byte-identical, 137/137. A3: kept the `view_*` min/max set (105/13/15 references vs 16/7/0), deleted 2 dupes + 6 of 8 resolve_* (stdlib `unwrap_or`/`unwrap_or_else` carry the Option-fallback pattern; kept resolve_frame_size/resolve_route as semantically distinct); 3 pub items removed from views surface, ~21 call sites updated. A4: `PressableTransition` in `views/common/pressable_transition.mbt` (slot key per control, byte-compatible encoding, button keeps its exact slot key); button migrated at 4 call sites, behavior byte-identical; checkbox/toggle/slider NOT wired — the choice-control theme has no pressed/hovered visual tokens, so wiring would be a design decision, not infra adoption (documented). views 39/39 + subpackage sweep, api-surface/maintenance green, control_helpers budget tightened 45→15 in the same change. |
| 2026-11-01 | B1 done. Census of all 92 real-source `ViewSemanticsInfo::new` call sites (views/runtime/core/backend/examples, `.mooncakes` excluded) clustered into five shapes: transparent-only (16), Boundary+role+label(+value) leaf (12+), stateful leaf (+checked/numeric/selected), explicit/dynamic-composition container (7), hidden (4); MergeDescendants+expanded (semantic_action_control) is a cluster of 1. Five helpers added next to the struct in `core/view_protocol.mbt`: `hidden()`, `transparent()`, `leaf(role~, label?, value?, selected?, checked?, numeric?)`, `container(composition~, role?, label?, value?)`, `text_field(label?, value?, multiline~=false, editable~=true)` — all pure additions spreading over the all-default `new()`; struct/`new`/per-field metadata modifiers unchanged, `overlaying` composition verified by test (explicit wins, unset passes through, composition/text never inherited). Migrated 40 call sites: 39/40 views production sites (views `::new` 40→1) including both spread≥6 sites (text_input_node/text_area_node, 6 fields each — the only ≥6 sites at HEAD, so the acceptance's "8+" bar was vacuous and the binding bar is ≥6); runtime root-boundary synthesis 1. Kept on `new`: semantic_action_control (MergeDescendants shape), core's per-field overlay modifiers (they are the overlay machinery itself), all `*_test`/`_wbtest` fixtures (keep exercising the base constructor), examples/momark (app-level, out of slice). Core budget 2529→2534 lines, 1120→1125 pub with inline reason. core 142/142, views 39/39, runtime 180/180, examples/new_world/app green; moon info + api-surface + maintenance-baseline + guidance/renderer/doc-references validators green (doc-references had 2 pre-existing A2-renamed `text_editing.mbt` references, repointed to `text_editing_composition.mbt`); `moon fmt` clean. |

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-01 | Plan created from the second-round maintainability review; first-round perf findings are closed in the hot-path plan (moved to done/ by C1). |
| 2026-11-01 | B1 is constructor-grouping, not a breaking regroup of the 26-field struct: comparison cost is derived and machine-handled; construction ergonomics is the human cost; a breaking regroup waits for profile evidence (same bar as view-state-slot-storage). |
| 2026-11-01 | `views/style` pass-through stays: documented backward-compat surface (button-styling-guide), removal belongs to a compatibility-policy release, not a cohesion slice. |
| 2026-11-01 | D2 enumerates the current production importers of runtime from backend/common as the allowlist baseline; desktop-core's runtime types (I1) are the first explicitly listed entry. |

## Progress

| Date | Note |
|------|------|
| 2026-11-01 | Plan created. No slices started. |
