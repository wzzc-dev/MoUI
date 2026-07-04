# 0003: Domain sugar packages and root app-loop facade

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
high-frequency types into domain sugar subpackages. The implemented shape combines
both ideas.

## Decision

1. **`@core` remains the type source of truth.** Direct `import "wzzc-dev/moui/core"`
   is valid for advanced kernel types; sugar packages only shorten prefixes for
   curated high-frequency sets.

2. **Root facade `wzzc-dev/moui` (`@moui.*`)** forwards **app-loop only**:
   `View`, `Program`, `Effect`, `Subscription`, `Theme`, `Environment`,
   `ViewEnvironment`. It does **not** replace domain sugar.

3. **Four domain sugar packages** (each imports only `wzzc-dev/moui/core`, no
   cross-import):
   - `moui/geometry` — layout geometry
   - `moui/graphics` — color/brush/border/shadow
   - `moui/text` — font and text alignment (extended with `FontFamilyStack`, `TextRun` where app-facing)
   - `moui/state` — reactive state and `ColorScheme` / `LayoutDirection`

4. **Command/menu types** and extra draw/theme helpers used by apps are re-exported
   from `moui/views` (`menu_commands.mbt`, `kernel_types.mbt`, `theme.mbt`) so
   shared apps can avoid runtime `@core` for those symbols.

5. **Shared app default**: `wzzc-dev/moui` + `wzzc-dev/moui/views` + domain sugar
   as needed. **Prefer** `@moui` / `@geometry` / `@graphics` / `@text` / `@state` /
   `@views` in app **source**; keep `wzzc-dev/moui/core` in `moon.pkg` only for
   `for "test"` / `for "wbtest"` when tests need `DrawCommand`, `AppEvent`, etc.

6. **Alias syntax**: only `pub using @core {type X}` in sugar and facades; not
   `pub type X = @core.X`.

7. **API surface guard** enforces per-sugar `required_tokens` / `forbidden_tokens`
   and shared-app core import budget (see `validate_api_surface`).

## Options Considered

### Option A: Single narrowed root facade (~30 types)

- Pros: one import for apps.
- Cons: still incomplete vs `core`; mixes geometry/graphics/text in one package;
  conflicts with `@app` alias if everything lived in root.

### Option B: Delete root facade; only `moui/app` sugar

- Pros: clear separation.
- Cons: `moon.mod` / workspace expectations for a root package; breaking `@moui`
  prefix used across examples.

### Option C: Root app-loop facade + domain sugar (chosen)

- Pros: matches MoonBit constraints; clear tiers; guardable budgets; aligns with
  Iced *intent* (sugar as main entry) without wildcard re-export.
- Cons: more `moon.pkg` lines; must document `ColorScheme` under `@state` not
  `@graphics`.

## Rationale

Domain sugar keeps packages small and prevents one facade from growing back into
a partial copy of `core`. Keeping `@moui` for app-loop types preserves the
`@app` vs `@moui` distinction in example packages.

## Consequences

- Examples and `website/app` were migrated to sugar/`@views` prefixes; tests may
  still use `@core` via `for "test"` imports.
- Extending sugar or `@views` re-exports requires `moon info`, guard token updates,
  and boundary doc updates.
- Supersedes the task lists in archived Kilo plans; do not delete root facade
  without revisiting this ADR.

## Follow-up

- Keep `docs/moui-app-package-boundary.md` as the operational spec.
- Run `node scripts/sync-website-docs.mjs` after doc edits.