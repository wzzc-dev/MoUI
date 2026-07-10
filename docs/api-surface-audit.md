# API Surface Audit

This audit records the current public API surface by semantic category. It is a
review aid for future API changes, not a promise that every listed declaration
is stable forever. The guard in `tools/moui/validate_api_surface` enforces these
counts against generated `pkg.generated.mbti` files.

## Current Snapshot

| Package | Public declarations | Semantic categories | Primary audience |
| --- | ---: | --- | --- |
| `moui/core` | 503 `pub`, 138 `pub(all)` | 521 `advanced_core_protocol`, 138 `required_protocol` | Framework authors, custom-view authors, render/runtime boundaries |
| `moui/views` | 350 `pub`, 43 `pub(all)` | 134 `app_constructor`, 164 `app_state_helper`, 30 `app_style`, 26 `advanced_core_protocol`, 43 `migration_debt` | App authors and app-facing control authors |
| `moui/runtime` | 261 `pub`, 6 `pub(all)` | 261 `runtime_diagnostic`, 6 `required_protocol` | Host/runtime assembly, diagnostics, devtools |
| `moui/backend/host` | 422 `pub`, 62 `pub(all)` | 422 `host_contract`, 62 `required_protocol` | Platform backends and host-service integrations |
| `moui/render` | 100 `pub`, 25 `pub(all)` | 100 `renderer_contract`, 25 `required_protocol` | Renderer implementers and renderer capability tooling |

The count sum includes generated `type` aliases in addition to `pub` and
`pub(all)` declarations. That is why semantic counts can be higher than the
plain `pub` count printed by the package budget summary.

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
- `migration_debt` tracks `moui/views` `pub(all) struct` declarations (currently
  0 — all 24 structs migrated to `pub struct` or opaque `type` per ADR 0004).
  `pub(all) enum` is no longer classified as debt: MoonBit requires `pub(all)`
  to expose enum variants for external construction, so enums are treated as
  intentional public API and classified into `app_style` or `app_state_helper`.

## Freeze And Migration Candidates

- Keep `moui/core` closed to new concrete controls, form/routing/WebView
  workflows, runtime snapshots, and design-system defaults. The existing legacy
  family guard should remain at zero occurrences for these families.
- Review `moui/views` `pub(all) struct` types first when doing API cleanup
  (currently 0 remaining). `pub(all) enum` types are intentional public API
  in MoonBit (variants need `pub(all)` for external construction); they are
  not migration candidates. Good struct candidates were opaque `type`
  declarations or `pub struct` with constructors and `with_xxx` methods —
  see ADR 0004 for the completed migration.
- Avoid adding more low-level paint helpers to `moui/views` unless they are
  necessary for `canvas` and app-facing custom drawing. Domain paint value types
  should stay under `moui/graphics` or direct `moui/core`.
- Keep runtime inspector expansion in `moui/runtime`; do not forward diagnostics
  through `moui`, domain facades, or `moui/views`.
- Keep host async-image, WebView, window, route, text-input, accessibility, and
  redraw contracts in `moui/backend/host`; concrete platform packages should
  not leak into app packages.

## Update Rule

When a public declaration is added or removed:

1. Run `moon info` if generated interfaces changed.
2. Run `node scripts/validate-api-surface.mjs`.
3. If the semantic classification budget fails, either move the API to the
   owning package or update the category budget with a short rationale in the
   same change.
4. Update this audit when the intended current snapshot changes.
