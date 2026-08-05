# API Surface Audit

This audit records the current public API surface by semantic category. It is a
review aid for future API changes, not a promise that every listed declaration
is stable forever. The guard in `tools/moui/validate_api_surface` enforces these
counts against generated `pkg.generated.mbti` files.

## Current Snapshot

The canonical numeric snapshot is generated in
[Repository Facts](repository-facts.md#api-surface) from the API validator's
structured report. Semantic category budgets remain executable policy in
`tools/moui/validate_api_surface`; this narrative deliberately does not copy
their current counts.

## Growth Policy

- `app_constructor` may grow only for reusable controls, layouts, or workflow
  surfaces that belong in `moui/views` and have focused tests plus catalog or
  guide coverage.
- `app_state_helper` may grow for small app-owned state helpers, descriptor
  constructors, or validators that reduce repeated app boilerplate without
  moving business policy into the framework.
- `app_style` should grow slowly. Prefer extending existing style structs or
  theme token groups over adding parallel style concepts.
- `advanced_core_protocol` should be mostly frozen. Additions need a clear
  cross-runtime contract reason and must not encode concrete controls, runtime
  state, platform services, renderer implementation details, or diagnostics.
- `runtime_diagnostic`, `host_contract`, and `renderer_contract` can grow when
  the owning package needs a new integration boundary, but new APIs should stay
  package-local and avoid re-exporting through app-facing facades.
- `required_protocol` is current structural exposure. Treat increases as
  review-worthy because they usually expose enum/struct shapes that are harder
  to change later.
- `test_exposure` is budgeted at zero for the tracked packages. Prefer
  package-private helpers and test-only files over public declarations that
  exist only for tests.
- `migration_debt` tracks `moui/views` `pub(all) struct` declarations. The
  completed visibility migration is recorded in ADR 0004.
  `pub(all) enum` is no longer classified as debt: MoonBit requires `pub(all)`
  to expose enum variants for external construction, so enums are treated as
  intentional public API and classified into `app_style` or `app_state_helper`.

## Freeze And Migration Candidates

- Keep `moui/core` closed to new concrete controls, form/routing/WebView
  workflows, runtime snapshots, and design-system defaults. The existing legacy
  family guard should remain at zero occurrences for these families.
- Review any future `moui/views` `pub(all) struct` types first when doing API
  cleanup. `pub(all) enum` types are intentional public API in MoonBit
  (variants need `pub(all)` for external construction); they are not migration
  candidates. Prefer opaque `type` declarations or `pub struct` with
  constructors and `with_xxx` methods; see ADR 0004.
- Avoid adding more low-level paint helpers to `moui/views` unless they are
  necessary for `canvas` and app-facing custom drawing. Domain paint value types
  should stay under `moui/graphics` or direct `moui/core`.
- Keep runtime inspector expansion in `moui/runtime`; do not forward diagnostics
  through `moui`, domain facades, or `moui/views`.
- Keep host async-image, WebView, window, route, text-input, accessibility, and
  redraw contracts in `moui/backend`; concrete platform packages should
  not leak into app packages.

## Update Rule

When a public declaration is added or removed:

1. Run `moon info` if generated interfaces changed.
2. Run `node scripts/validate-api-surface.mjs`.
3. If the semantic classification budget fails, either move the API to the
   owning package or update the category budget with a short rationale in the
   same change.
4. Run `node scripts/generate-repo-docs.mjs --write` and commit the generated
   facts when the intended snapshot changes.
