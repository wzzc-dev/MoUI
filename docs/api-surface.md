# API Surface

MoUI is still a prototype, so backward compatibility is not the first priority.
The project should still keep a readable public shape: application code should
start from the root `moui` app-loop facade, domain facades, and `moui/views`;
runtime construction should go through `moui/runtime`, and host/renderer
packages expose narrower contracts for platform and renderer integration.

## Surface Tiers

- App-facing API: `moui` (app-loop sugar only), domain facade packages
  (`moui/geometry`, `moui/graphics`, `moui/animation`, `moui/text`,
  `moui/state`), and `moui/views`. Command/menu facade types, control styles,
  theme builders, and the temporary `DateValue` facade live in `moui/views`;
  drawing/paint value types live in `moui/graphics`, transition/easing types
  live in `moui/animation`, and focus-scope types live in `moui/state`.
  Runtime handles such as `AppRuntime` stay in `moui/runtime`; reactive and
  geometry types are available through domain facades where listed in
  `docs/moui-app-package-boundary.md`.
  Shared apps should minimize default `moui/core` imports; the API surface guard
  tracks shared-app core import budget (see `validate_api_surface`).
  Diagnostics, draw commands, renderer details, semantics/runtime ids, and
  lower-level kernel protocols stay in `moui/core` or their owning packages.
  `moui/views` exposes constructor helpers that return opaque `@moui.View[Msg]`
  values plus control-specific app-facing contracts such as
  `@views.ActionCommand`, `@views.WebViewEvent`, and
  `@views.SheetPresentationMode`.
- Runtime API: `moui/runtime`. This is the app/host runtime entrypoint package.
  Runtime consumers should type and construct runtimes through
  `@runtime.AppRuntime`, `@runtime.new_view`, `@runtime.new_program`, or the
  width/height entrypoint helper `@runtime.new_program_with_dimensions`. Core
  no longer exposes `@core.AppRuntime`, `RuntimeKernel`, or `RuntimeState`;
  runtime owns program execution, runtime state, tree/layout/paint, event
  dispatch, and consumes opaque views through `View[Msg]`.
- Core framework API: `moui/core`. This owns `View[Msg]`, `Program`, `Effect`,
  `Subscription`, layout, input, semantics, draw-command protocols,
  renderer-neutral platform-view contracts, and the `View::node` callback
  surface used by concrete controls in `moui/views`. New controls should not add core
  enum variants, `@core.View::primitive_*_view` constructors, `ViewLoweringSink`,
  or runtime lowering arms. `core` must not depend on `geometry`, `graphics`,
  `animation`, `text`, `state`, `views`, `runtime`, `backend`, `render`, or addon
  packages. It does not expose `RuntimeKernel`, `RuntimeState`, `ViewSpec`,
  `ElementNode`, or `ElementTree`, and concrete control semantics such as
  `SheetPresentationMode` stay out of `core`. Component-facing contracts such as
  `ComponentContext` keep runtime/effect storage fields private and expose behavior
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
- required domain facade tokens for geometry, graphics, animation, text, and
  state/focus packages, plus cross-domain forbidden aliases;
- `moui/views` staying app-facing by exposing constructors, command/menu/theme
  helpers, and `DateValue` while rejecting low-level drawing, animation,
  focus-scope, semantics, runtime-id, and component-kernel re-exports;
- `moui/runtime` existence, an opaque `AppRuntime` with bounded runtime methods,
  runtime source not wrapping `@core.AppRuntime` or `@core.RuntimeKernel`, and
  app/host source usage of `@runtime.AppRuntime`;
- final core/runtime boundary tokens: `RuntimeKernel`, `RuntimeState`,
  public `ViewNode`, `ViewSpec`, `ElementNode`, `ElementTree`, `ViewLoweringSink`,
  and `@core.View::primitive_*_view` must not appear in the core generated public API;
- backend generated interfaces exposing `@runtime.AppRuntime` rather than the
  old `@core.AppRuntime` path, plus a zero-budget guard that prevents shared
  app packages from default-importing `moui/runtime`;
- shared app package default `moui/core` import budget plus an explicit
  advanced-app allowlist, so new ordinary apps stay on `moui + views`;
- app, host, smoke, and cross-package tests using `moui/views` for view
  construction and control-level helpers instead of direct `@moui.View::*`
  constructors;
- required app-facing re-exports such as `View`, `Program`, `State`, `Binding`,
  `Effect`, `Subscription`, `Theme`, graphics, animation, and state/focus
  facade tokens, while keeping runtime bridges, diagnostic descriptors, and draw
  command types out of the root facade and `@views`;
- `moui/views` constructors returning `@moui.View[Msg]`;
- host/render/package boundary tokens staying in their owning packages.

Budget failures are review prompts, not compatibility promises. If a deliberate
API expansion is worth keeping, update the budget and explain the reason in the
same change.
