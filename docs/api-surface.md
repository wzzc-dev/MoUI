# API Surface

MoUI is still a prototype, so backward compatibility is not the first priority.
The project should still keep a readable public shape: application code should
start from the root `moui` facade plus `moui/views`, while host and renderer
packages expose narrower contracts for platform and renderer integration.

## Surface Tiers

- App-facing API: `moui` and `moui/views`. The root facade re-exports common
  app types from `moui/core` and theme builders. `moui/views` exposes
  constructor helpers that return opaque `@core.View[Msg]` values.
- Core framework API: `moui/core`. This owns `View[Msg]`, `Program`, `Effect`,
  `Subscription`, state, layout, input, semantics, draw commands, diagnostics,
  and renderer-neutral platform-view contracts. It may expose diagnostic and
  support records while the prototype matures, but implementation payloads
  should not leak into the root facade.
- Integration API: `moui/backend/host`, `moui/render`, and renderer/provider
  packages. These are public because platform backends, renderers, examples,
  and observation tools need them, but they are not the everyday app authoring
  surface.
- Addon API: `moui_theme/*` packages. These remain outside `core`, `views`,
  and the root facade so design-system preview work does not become a required
  dependency for normal MoUI apps.

## Review Rules

Before adding exported declarations, first decide which tier owns the new
symbol. Prefer keeping app ergonomics in `views`, neutral contracts in `core`,
host routing in `backend/host`, and concrete renderer details in the renderer
package that implements them.

Run `moon info` after public API changes and review generated
`pkg.generated.mbti` diffs. For no-API-change work, those files should stay
unchanged.

Run the API surface guard after `moon info` when public shape may have changed:

```sh
node scripts/validate-api-surface.mjs
```

The guard is implemented in MoonBit at
`tools/moui/validate_api_surface/`. The Node script is only a thin build/run
entrypoint. It checks current generated interface files for:

- line and exported-declaration budgets on key packages;
- root facade imports and forbidden host/renderer/runtime tokens;
- required app-facing re-exports such as `View`, `Program`, `Effect`,
  `Subscription`, `Theme`, `AppRuntime`, and `Binding`;
- `moui/views` constructors returning `@core.View[Msg]`;
- host/render/package boundary tokens staying in their owning packages.

Budget failures are review prompts, not compatibility promises. If a deliberate
API expansion is worth keeping, update the budget and explain the reason in the
same change.
