# API Surface

MoUI is still a prototype, so backward compatibility is not the first priority.
The project should still keep a readable public shape: application code should
start from the root `moui` facade plus `moui/views`, runtime construction
should go through `moui/runtime`, and host/renderer packages expose narrower
contracts for platform and renderer integration.

## Surface Tiers

- App-facing API: `moui` and `moui/views`. The root facade re-exports only a
  curated set of common app/theme type aliases from `moui/core`; theme builder
  helpers live in `moui/views`.
  Runtime handles such as `AppRuntime` stay in `moui/runtime`; binding helpers,
  detailed theme palette and scale records stay qualified as `@core.*` types
  rather than root aliases.
  Diagnostics, draw commands, renderer details, and lower-level geometry/style
  records stay in `moui/core` or their owning packages.
  `moui/views` exposes constructor helpers that return opaque `@core.View[Msg]`
  values plus control-specific app-facing contracts such as
  `@views.ActionCommand`, `@views.Color`, and `@views.WebViewEvent`.
- Runtime API: `moui/runtime`. This is the app/host runtime entrypoint package.
  Runtime consumers should type and construct runtimes through
  `@runtime.AppRuntime`, `@runtime.new_view`, `@runtime.new_program`, or the
  width/height entrypoint helper `@runtime.new_program_with_dimensions`. Core
  no longer exposes `@core.AppRuntime` or `RuntimeState`; runtime owns program
  execution and uses only the low-level `RuntimeKernel` contract seam for
  tree, layout, and paint handoff.
- Core framework API: `moui/core`. This owns `View[Msg]`, `Program`, `Effect`,
  `Subscription`, layout, input, semantics, draw-command, diagnostic snapshot,
  and renderer-neutral platform-view contracts, plus private engine state behind
  the `RuntimeKernel` seam used by `moui/runtime`. It may expose diagnostic and
  support records while the prototype matures, but implementation payloads
  should not leak into the root facade. Component-facing contracts such as
  `BuildContext` keep runtime/effect storage fields private and expose behavior
  through methods.
- Integration API: `moui/backend/host`, `moui/render`, and renderer/provider
  packages. These are public because platform backends, renderers, examples,
  and observation tools need them, but they are not the everyday app authoring
  surface.
- Addon API: `moui_theme/*` packages. These remain outside `core`, `views`,
  and the root facade so design-system preview work does not become a required
  dependency for normal MoUI apps.

## Review Rules

Before adding exported declarations, first decide which tier owns the new
symbol. Prefer keeping app ergonomics in `views`, runtime construction and host
runtime handles in `runtime`, neutral contracts in `core`, host routing in
`backend/host`, and concrete renderer details in the renderer package that
implements them.

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
- `moui/runtime` existence, an opaque `AppRuntime` with bounded runtime methods,
  runtime source not wrapping `@core.AppRuntime`, and app/host source usage of
  `@runtime.AppRuntime`;
- backend generated interfaces exposing `@runtime.AppRuntime` rather than the
  old `@core.AppRuntime` path, plus a zero-budget guard that prevents shared
  app packages from default-importing `moui/runtime`;
- shared app package default `moui/core` import budget, currently a ratchet
  while app-facing examples move to `moui + views`;
- app, host, smoke, and cross-package tests using `moui/views` for view
  construction and widget-level controls instead of direct `@core.View::*`
  constructors;
- required app-facing re-exports such as `View`, `Program`, `Effect`,
  `Subscription`, and `Theme`, while keeping runtime bridges, binding helpers,
  diagnostic descriptors, and draw command types out of the root facade;
- `moui/views` constructors returning `@core.View[Msg]`;
- host/render/package boundary tokens staying in their owning packages.

Budget failures are review prompts, not compatibility promises. If a deliberate
API expansion is worth keeping, update the budget and explain the reason in the
same change.
