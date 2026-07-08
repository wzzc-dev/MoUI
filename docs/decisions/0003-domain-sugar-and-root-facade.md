# 0003: Domain facade packages and root app-loop facade

- **Date**: 2026-07-04
- **Status**: Accepted
- **Deciders**: Agent-assisted (facade refactor planning and implementation)
- **Related**: `docs/moui-app-package-boundary.md`, `tools/moui/validate_api_surface/`,
  `.kilo/plans/` (archived to `docs/plans/archived/`)

## Context

The root package `wzzc-dev/moui` historically forwarded ~39 kernel types with
hand-written `pub type X = @core.X`, while `moui/views` already used
`pub using @core {type X}`. Apps mixed `@moui.*` and `@core.*` for the same
types. MoonBit has no `pub use *` wildcard (unlike Rust Iced’s `pub use iced_core::*`),
so a single facade cannot re-export all of `moui/core` (~500+ public items).

Two planning documents explored (1) narrowing the root facade only, and (2) splitting
high-frequency types into domain facade subpackages. The implemented shape combines
both ideas and keeps `moui/core` as a one-way foundation package.

## Decision

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

## Options Considered

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

## Rationale

Domain facades keep packages small and prevent one facade from growing back into
a partial copy of `core`, while still giving drawing, animation, text, geometry,
and state a stable app-facing home. Keeping `@moui` for app-loop types preserves
the `@app` vs `@moui` distinction in example packages.

## Consequences

- Examples and `website/app` were migrated to domain facade, `@views`, or
  advanced `@core` prefixes as appropriate; tests may still use `@core` via
  `for "test"` imports.
- Extending a domain facade or `@views` re-exports requires `moon info`, guard token updates,
  and boundary doc updates.
- Supersedes the task lists in archived Kilo plans; do not delete root facade
  without revisiting this ADR.

## Follow-up

- Keep `docs/moui-app-package-boundary.md` as the operational spec.
- Run `node scripts/sync-website-docs.mjs` after doc edits.
