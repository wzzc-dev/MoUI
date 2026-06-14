# API Surface

MoUI is still a prototype, so backward compatibility is not the first priority.
The project should still keep a readable public shape: application code should
start from the root `moui` facade plus `moui/views`, runtime construction
should go through `moui/runtime`, and host/renderer packages expose narrower
contracts for platform and renderer integration.

## Surface Tiers

- App-facing API: `moui` and `moui/views`. The root facade re-exports a small
  curated set of common app/theme aliases from `moui/core` plus theme builders.
  Runtime bridges such as `AppRuntime`, binding helpers, detailed theme palette
  and scale records stay qualified as `@core.*` types rather than root aliases.
  Diagnostics, draw commands, renderer details, and lower-level geometry/style
  records stay in `moui/core` or their owning packages.
  `moui/views` exposes constructor helpers that return opaque `@core.View[Msg]`
  values.
- Runtime API: `moui/runtime`. This is the app/host runtime entrypoint package.
  Runtime consumers should type and construct runtimes through
  `@runtime.AppRuntime`, `@runtime.new_view`, or `@runtime.new_program` rather
  than reaching through `@core.AppRuntime`. During the package split it exposes
  an opaque wrapper over the existing core runtime kernel so app, host, smoke,
  and tooling signatures no longer leak the core runtime type.
- Core framework API: `moui/core`. This owns `View[Msg]`, `Program`, `Effect`,
  `Subscription`, state, layout, input, semantics, draw commands, diagnostics,
  and renderer-neutral platform-view contracts. It may expose diagnostic and
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
- `moui/runtime` existence, an opaque `AppRuntime` wrapper with bounded runtime
  methods, and app/host source usage of `@runtime.AppRuntime` instead of direct
  `@core.AppRuntime`;
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
