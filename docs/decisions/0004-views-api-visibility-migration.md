# 0004: Views public API visibility migration — from pub(all) to structured exposure

- **Date**: 2026-07-10
- **Status**: Accepted
- **Deciders**: Agent-assisted (GLM-5.2)
- **Related**: `docs/api-surface.md`, `docs/api-surface-audit.md`,
  `docs/button-styling-guide.md`, `tools/moui/validate_api_surface/`,
  `tools/moui/validate_maintenance_baseline/`

## Context

The `moui/views` package has 43 `pub(all)` types that the API surface
auditor mechanically classifies as `migration_debt` (budget 43, pinned to
the exact current count). `pub(all)` exposes both the type and all its
fields/variants, allowing external packages to construct values via struct
literals and depend on internal storage representation.

Mature GUI frameworks (Flutter, SwiftUI, Jetpack Compose, Qt, Iced) do not
pursue "zero public representation." They公开 value types and enums but
hide runtime state and drawing contexts. Value objects are modified through
constructors and `copyWith`-style methods rather than direct field access.
Enums expose variants for `match` while providing stable string contracts
(Flutter `enum.name`, Swift `String`-backed enums).

MoUI already has proven patterns for both `pub struct` (field-private) and
opaque `type`:
- `DataSortState`, `PaginationState`, `ColumnWidthState` use `pub struct` +
  `::new()` + getter + `Self`-returning update methods.
- `FormController`, `FormValidationRule`, `RouteFocusStore`, `RouterState`
  were previously migrated from `pub(all)` to opaque `type`.

The auditor's one-size-fits-all `pub(all)` → `migration_debt` classification
(line 224-229 of `api_surface_classification.mbt`) short-circuits before the
existing semantic categories (`app_style`, `app_state_helper`,
`advanced_core_protocol`) can apply, so even intentionally-public style types
are labeled as debt.

## Decision

Adopt a three-tier migration strategy mirroring mature framework exposure
patterns:

1. **Runtime state → opaque `type`** (2 types): `PaintContext`,
   `FormFieldState`. Hide command buffers and mutable state storage.

2. **Value objects → `pub struct` + `new()` + getter + `with_xxx()`** (22
   types): 12 style structs, 3 form value objects, 7 route value objects.
   Flutter `copyWith` pattern — external code constructs via `::new()` and
   modifies via `with_xxx()` returning `Self`.

3. **Enums → keep `pub(all) enum` + `to_string()`** (19 types): 16
   control/display enums + 3 form enums. MoonBit requires `pub(all)` for
   external variant construction (`pub enum` without `(all)` hides variants
   from external packages). `to_string()` provides a stable string contract
   (Flutter `enum.name` pattern). Missing `derive(Eq, Debug)` added to
   `PopoverPlacement` and `FileImportAvailability`. The auditor reclassifies
   `pub(all) enum` from `migration_debt` to `app_style`/`app_state_helper`.

After migration, views `.mbti` has 0 `pub(all) struct` lines and 19
`pub(all) enum` lines (intentional). The auditor's `migration_debt` budget
drops to 0 (only `pub(all) struct` is debt; `pub(all) enum` falls through to
semantic classification). `views_style_tokens()` gains two additions
(`ChipVariant`, `DatePickerMode`). A new `pub fn new_control_state_style()`
was added so external packages can construct `ControlStateStyle` without
importing `@core` directly.

## Options Considered

### Option A: All opaque

- Pros: Maximum hiding of internal representation.
- Cons: Breaks struct-spread and derive for value objects; over-hides types
  that mature frameworks intentionally公开 (Flutter `ButtonStyle`, Iced
  `button::Style`).

### Option B: Keep pub(all), only fix auditor classification

- Pros: Zero breaking changes.
- Cons: Does not tighten representation exposure; `migration_debt` count
  unchanged; style structs still vulnerable to external field-level coupling.

### Option C: Three-tier structured migration (chosen)

- Pros: Matches mature framework practices; value objects get controlled
  construction; runtime state hidden; auditor classification becomes accurate.
- Cons: One-time breaking change requiring example migration; larger PR.

## Rationale

The three-tier approach distinguishes between types that mature frameworks
intentionally公开 (value objects, enums) and types they hide (runtime state,
drawing contexts). This is more nuanced than "make everything opaque" and
more substantive than "only fix the auditor." The `with_xxx()` method pattern
reuses MoUI's existing `DataSortState`/`PaginationState` convention rather
than inventing new abstractions.

## Consequences

- `moui/views/pkg.generated.mbti`: `pub(all) struct` lines 24 → 0;
  `pub(all) enum` lines 19 → 19 (intentional, MoonBit requires `pub(all)`
  for external variant construction).
- Three budget systems synchronized: API surface classification
  (`migration_debt` 43→0; `pub(all) enum` reclassified to `app_style`/
  `app_state_helper`), package-level (`max_pub_all_lines` 45→19),
  maintenance baseline ratchet (`pub(all)` count 82→19).
- Examples and `moui_theme` migrated: literal construction → `::new()`,
  struct-spread → `with_xxx()`, field access → getter calls.
- `ControlStateStyle` (in `moui/core`) remains `pub(all)` — not in scope.
  New `pub fn new_control_state_style()` added to views for external
  construction without `@core` import.
- `RouteQueryParam`/`RouteParam` field duplication preserved — semantic
  refactor deferred to a separate change.
- Future style struct field changes are no longer breaking for external code
  (fields are private; only `::new()` signature matters).

## Agent Notes

- **Session context**: API surface audit analysis — 43 `pub(all)` types in
  `moui/views` classified as `migration_debt`; user requested comparison with
  mature GUI frameworks and a migration plan.
- **Agent model**: GLM-5.2
- **Key prompt**: "参考其他成熟 GUI 框架 分析这个应该如何修改优化" →
  "根据上面的继续制定计划"
- **Validation**: `moon check moui/views`, `moon test moui/views`,
  `moon info --sort Output`, `moon check --all`,
  `moon test tools/moui/validate_api_surface`,
  `moon test tools/moui/validate_maintenance_baseline`,
  `node scripts/check.mjs --profile daily`.

## References

- `docs/api-surface-audit.md` — migration_debt policy and budget
- `docs/button-styling-guide.md` — ButtonStyle construction pipeline
- `tools/moui/validate_api_surface/api_surface_classification.mbt` —
  classification logic (line 224-229 short-circuit)
- `moui/views/data_sort_pagination.mbt` — `pub struct` pattern reference
- ADR 0003 — domain facade and root app-loop facade
