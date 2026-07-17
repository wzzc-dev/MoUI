# 0014: Core owns value types; domain packages are facades only

- **Date**: 2026-07-16
- **Status**: Accepted
- **Deciders**: Goal-mode architecture correction
- **Related**: [0003-domain-sugar-and-root-facade.md](0003-domain-sugar-and-root-facade.md),
  `docs/moui-app-package-boundary.md`, `docs/architecture-map.md`

## Context

A no-compatibility goal briefly explored making
`moui/{geometry,graphics,animation,text,state}` the **type owners**, with
`moui/core` importing them for protocol composition. That inverts ADR 0003 and
violates the standing constraint that **`core` must not depend on domain
packages**.

MoonBit cannot give both of these at once without a third package layer:

1. domain packages own `Point` / `Color` / … as the sole definitions, and
2. `core` protocols use those same types while **never** importing domain packages.

## Decision

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

## Rejected alternative

**Domain-owned types with `core → domain`** (temporary experiment): improves
“ownership purity” wording but breaks the `core`-as-foundation invariant and
forces domain DAGs (`text → graphics`, `state → animation`, …). Rejected.

## Consequences

- Domain packages may remain thin alias facades; that is intentional under MoonBit
  re-export limits, not incomplete work.
- Extending a domain package still means curated `pub using` plus API surface
  guard updates (ADR 0003).
- Any future “true ownership split” requires an explicit third layer (e.g.
  `moui/values`) or a formal RFC to allow `core → domain`.

## Follow-up

- Keep API surface guards on required/forbidden facade tokens.
- Prefer mechanical checks that `moui/core/moon.pkg` never lists domain packages.
