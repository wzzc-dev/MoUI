# 0012: Showcase consolidation and moui_cli quick start

- **Date**: 2026-07-16
- **Status**: Accepted
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: ADR 0010, ADR 0011, `docs/examples.md`, `docs/showcases.md`

## Context

MoUI had three overlapping learning surfaces (`showcase`, `component_gallery`,
`platform_lab`) plus a `moui_example` submodule used as a clone-based quick
start. That split made discovery harder, duplicated component demos, and left
mobile CI identity mid-migration toward Showcase while gallery trees still
existed.

## Decision

1. **Quick start** is only `moui_cli`:
   ```sh
   moon install wzzc-dev/moui_cli/cmd/moui
   moui new my_app
   ```
   Do not document `git clone …/moui_example`.
2. **Showcase** is the only long-lived comprehensive example.
3. Showcase is one MoonBit module with a root TEA shell over four packages:
   - `app/components` — app-safe component catalog
   - `app/patterns` — application patterns
   - `app/platform` — host recipes / canvas / mobile probe (may use host)
   - `app/diagnostics` — runtime/render diagnostics exception
4. Canonical routes: `components|patterns|platform|diagnostics/<id>`.
   Desktop/Web default `components/welcome`; mobile default
   `platform/mobile-service-probe`. Keep bare aliases for
   `advanced-rendering` and `runtime-renderer`.
5. Mobile identity is Showcase-only (`dev.wzzc.moui.showcase`). No permanent
   compatibility aliases for deleted gallery wrappers.
6. Delete `examples/component_gallery`, `examples/platform_lab`, and the
   `examples/moui_example` gitlink/checkout.

## Options Considered

### Option A: Keep three examples and only re-link docs

- Pros: less code churn
- Cons: continued duplication and mixed mobile identity

### Option B: Merge into Showcase with four isolated packages (chosen)

- Pros: one catalog, clear copy-paste boundaries, single mobile identity
- Cons: larger one-time refactor; diagnostics still needs ongoing section trim

## Rationale

Users need one place to learn and one mobile proof app. Package isolation keeps
copy-paste guidance honest: ordinary apps should not depend on diagnostics'
core/runtime/render imports.

## Consequences

- Framework public API unchanged; Showcase routes and mobile IDs are the
  outward-facing example contract.
- Historical Component Gallery runtime artifacts remain labeled historical and
  are not Showcase evidence.
- Fresh Android/iOS/HarmonyOS Showcase device evidence is still pending and does
  not block packaging/tooling green.

## Agent Notes

- **Session context**: finish mid-flight Showcase consolidation
- **Validation**: `moon test examples/showcase/app --target native`; entrypoint
  `moon check` for desktop/mobile session packages

## References

- `examples/showcase/app/`
- `examples/catalog.json`
- `docs/getting-started.md`
