# ADR 0003-0014: Core Package and API (merged)

> 原编号保留为小节锚点: 0003-domain-sugar-and-root-facade,0004-views-api-visibility-migration,0014-core-owns-domain-facades

---

## 0003: Domain facade packages and root app-loop facade

- **Date**: 2026-07-04
- **Status**: Accepted
- **Deciders**: Agent-assisted (facade refactor planning and implementation)
- **Related**: `docs/moui-app-package-boundary.md`, `tools/moui/validate_api_surface/`,
  `.kilo/plans/` (archived to `docs/plans/archived/`)

### Context

The root package `wzzc-dev/moui` historically forwarded ~39 kernel types with
hand-written `pub type X = @core.X`, while `moui/views` already used
`pub using @core {type X}`. Apps mixed `@moui.*` and `@core.*` for the same
types. MoonBit has no `pub use *` wildcard (unlike Rust Iced’s `pub use iced_core::*`),
so a single facade cannot re-export all of `moui/core` (~500+ public items).

Two planning documents explored (1) narrowing the root facade only, and (2) splitting
high-frequency types into domain facade subpackages. The implemented shape combines
both ideas and keeps `moui/core` as a one-way foundation package.

### Decision

1. **`@core` remains the type source of truth.** Direct `import "wzzc-dev/moui/core"`
   is valid for advanced kernel types. Domain facades shorten prefixes for
   curated high-frequency sets and may later host light domain extensions that
   do not belong in `core`. `core` must not depend on those facades.

2. **Root facade `wzzc-dev/moui` (`@moui.*`)** forwards **app-loop only**:
   `View`, `Program`, `Effect`, `Subscription`, `Theme`, `Environment`,
   `ViewEnvironment`. It does **not** replace domain facades.

3. **Five domain facade packages** (each imports only `wzzc-dev/moui/core`, no
   cross-import):
   - `moui/geometry` — layout geometry
   - `moui/graphics` — paint and drawing value types such as color, brush,
     rounded rect, path, image, layer, filter, transform, and shader specs
   - `moui/animation` — transition/easing value types
   - `moui/text` — font and text alignment (extended with `FontFamilyStack`, `TextRun` where app-facing)
   - `moui/state` — reactive state, focus state/scope, `ColorScheme`, and
     `LayoutDirection`

4. **`moui/views` is not a low-level kernel catch-all.** It re-exports
   command/menu facade types and theme helpers for app ergonomics, keeps
   `DateValue` as a temporary facade because datepicker already exposed it, and
   owns view constructors, control styles, form/navigation/data helpers, default
   themes, and control semantics such as `SheetPresentationMode`. Drawing,
   animation, focus-scope, semantics, runtime-id, and component-kernel types are
   reached through their owning domain facade or `@core`.

5. **Shared app default**: `wzzc-dev/moui` + `wzzc-dev/moui/views` + domain
   facades as needed. **Prefer** `@moui` / `@geometry` / `@graphics` /
   `@animation` / `@text` / `@state` / `@views` in app **source**; keep
   `wzzc-dev/moui/core` in `moon.pkg` only for advanced kernel/diagnostics or
   `for "test"` / `for "wbtest"` when tests need `DrawCommand`, `AppEvent`, etc.

6. **Alias syntax**: only `pub using @core {type X}` in domain facades; not
   `pub type X = @core.X`.

7. **API surface guard** enforces per-facade `required_tokens` /
   `forbidden_tokens`, `@views` forbidden low-level aliases, and shared-app core
   import budget (see `validate_api_surface`).

### Options Considered

### Option A: Single narrowed root facade (~30 types)

- Pros: one import for apps.
- Cons: still incomplete vs `core`; mixes geometry/graphics/text in one package;
  conflicts with `@app` alias if everything lived in root.

### Option B: Delete root facade; only `moui/app` sugar

- Pros: clear separation.
- Cons: `moon.mod` / workspace expectations for a root package; breaking `@moui`
  prefix used across examples.

### Option C: Root app-loop facade + domain facades (chosen)

- Pros: matches MoonBit constraints; clear tiers; guardable budgets; aligns with
  Iced *intent* (curated facades as app-facing entrypoints) without wildcard
  re-export.
- Cons: more `moon.pkg` lines; must document `ColorScheme` under `@state` not
  `@graphics`.

### Rationale

Domain facades keep packages small and prevent one facade from growing back into
a partial copy of `core`, while still giving drawing, animation, text, geometry,
and state a stable app-facing home. Keeping `@moui` for app-loop types preserves
the `@app` vs `@moui` distinction in example packages.

### Consequences

- Examples and `website/app` were migrated to domain facade, `@views`, or
  advanced `@core` prefixes as appropriate; tests may still use `@core` via
  `for "test"` imports.
- Extending a domain facade or `@views` re-exports requires `moon info`, guard token updates,
  and boundary doc updates.
- Supersedes the task lists in archived Kilo plans; do not delete root facade
  without revisiting this ADR.

### Follow-up

- Keep `docs/moui-app-package-boundary.md` as the operational spec.
- Run `node scripts/sync-website-docs.mjs` after doc edits.

---

## 0004: Views public API visibility migration — from pub(all) to structured exposure

- **Date**: 2026-07-10
- **Status**: Accepted
- **Deciders**: Agent-assisted (GLM-5.2)
- **Related**: `docs/api-surface.md`, `docs/api-surface-audit.md`,
  `docs/button-styling-guide.md`, `tools/moui/validate_api_surface/`,
  `tools/moui/validate_maintenance_baseline/`

### Context

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

### Decision

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

### Options Considered

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

### Rationale

The three-tier approach distinguishes between types that mature frameworks
intentionally公开 (value objects, enums) and types they hide (runtime state,
drawing contexts). This is more nuanced than "make everything opaque" and
more substantive than "only fix the auditor." The `with_xxx()` method pattern
reuses MoUI's existing `DataSortState`/`PaginationState` convention rather
than inventing new abstractions.

### Consequences

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

### Agent Notes

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

### References

- `docs/api-surface-audit.md` — migration_debt policy and budget
- `docs/button-styling-guide.md` — ButtonStyle construction pipeline
- `tools/moui/validate_api_surface/api_surface_classification.mbt` —
  classification logic (line 224-229 short-circuit)
- `moui/views/data_sort_pagination.mbt` — `pub struct` pattern reference
- ADR 0003 — domain facade and root app-loop facade

---

## 0014: Core owns value types; domain packages are facades only

- **Date**: 2026-07-16
- **Status**: Accepted
- **Deciders**: Goal-mode architecture correction
- **Related**: [0003-domain-sugar-and-root-facade.md](0003-domain-sugar-and-root-facade.md),
  `docs/moui-app-package-boundary.md`, `docs/architecture-map.md`

### Context

A no-compatibility goal briefly explored making
`moui/{geometry,graphics,animation,text,state}` the **type owners**, with
`moui/core` importing them for protocol composition. That inverts ADR 0003 and
violates the standing constraint that **`core` must not depend on domain
packages**.

MoonBit cannot give both of these at once without a third package layer:

1. domain packages own `Point` / `Color` / … as the sole definitions, and
2. `core` protocols use those same types while **never** importing domain packages.

### Decision

**Keep model B (ADR 0003):**

1. **`moui/core` is the type source of truth** for geometry, graphics, animation,
   text, and state value types used by the UI kernel/protocol.
2. **Domain packages are app-facing facades** over `core` via
   `pub using @core {type X}` (and may later host light helpers that only depend
   on `core`).
3. **Dependency direction:**

   ```text
   core                         # owns value types + protocols
     ▲
   geometry / graphics / animation / text / state
     # each imports only core; no domain cross-imports
     ▲
   views / apps / runtime / host / render
   ```

4. **`core` must not import** `moui/geometry`, `moui/graphics`, `moui/animation`,
   `moui/text`, or `moui/state`.
5. **Domain packages must not cross-import each other.**
6. Root `wzzc-dev/moui` remains app-loop only; ordinary apps use
   `moui` + `views` + domain facades as needed and avoid main-code
   `runtime` / `render/*` / platform backends.

### Rejected alternative

**Domain-owned types with `core → domain`** (temporary experiment): improves
“ownership purity” wording but breaks the `core`-as-foundation invariant and
forces domain DAGs (`text → graphics`, `state → animation`, …). Rejected.

### Consequences

- Domain packages may remain thin alias facades; that is intentional under MoonBit
  re-export limits, not incomplete work.
- Extending a domain package still means curated `pub using` plus API surface
  guard updates (ADR 0003).
- Any future “true ownership split” requires an explicit third layer (e.g.
  `moui/values`) or a formal RFC to allow `core → domain`.

### Follow-up

- Keep API surface guards on required/forbidden facade tokens.
- Prefer mechanical checks that `moui/core/moon.pkg` never lists domain packages.

