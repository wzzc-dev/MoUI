# API Surface

MoUI is still a prototype, so backward compatibility is not the first priority.
The project should still keep a readable public shape: application code should
start from the root `moui` app-loop facade, domain facades, and `moui/views`;
runtime construction should go through `moui/runtime`, and host/renderer
packages expose narrower contracts for platform and renderer integration.

## Surface Tiers

- **Stable app API**: `moui` (app-loop sugar only), domain facade packages
  (`moui/geometry`, `moui/graphics`, `moui/animation`, `moui/text`,
  `moui/state`), and everyday `moui/views` constructors. This is the surface
  ordinary app packages should learn first. `moui/views` exposes constructor
  helpers returning opaque `@moui.View[Msg]` values plus control-specific
  app-facing contracts such as command/menu descriptors, control styles, theme
  builders, and `SheetPresentationMode`.
- **Agent integration API**: `moui_agent` and `moui_agent_mcp`. The default
  contract is the committed semantic surface (`read_semantics` and
  `perform_action`) over runtime generations. Coordinate input, global
  commands, runtime counters, and paint summaries are separate opt-in
  diagnostics and are not inherited by `AgentHost`.
- **Advanced core API**: `moui/core`. This owns `View[Msg]`, `Program`,
  `Effect`, `Subscription`, layout, input, semantics, draw-command protocols,
  renderer-neutral platform-view contracts, the public open `ViewNode` trait,
  and `View::from_node`, which attaches typed children and message adapters to a
  message-independent node. New controls should not add core enum variants,
  `@core.View::primitive_*_view` constructors,
  `ViewLoweringSink`, or runtime lowering arms. Shared apps should minimize
  default `moui/core` imports; the guard tracks a shared-app core import budget.
- **Runtime API**: `moui/runtime`. Runtime consumers should construct runtimes
  through `@runtime.AppRuntime`, `@runtime.new_view`, `@runtime.new_program`, or
  `@runtime.new_program_with_dimensions`. Runtime owns program execution,
  element/layout/render state, effect/subscription lifecycle, inspector
  snapshots, and diagnostics; `core` no longer exposes `AppRuntime`,
  `RuntimeKernel`, or `RuntimeState`.
- **Integration API**: `moui/backend`, `moui/render`, and renderer/provider
  packages. These packages are public for platform backends, renderers,
  examples, and observation tooling, but they are not the normal app authoring
  surface.
- **Diagnostic/addon API**: diagnostic renderer routes such as native WGPU,
  `moui_theme/audit`, source-mapped theme previews, platform scaffolds, and
  opt-in smoke/evidence helpers. These stay outside `core`, `views`, and the
  root facade unless explicitly promoted by tests and docs.

## Review Rules

Before adding exported declarations, first decide which tier owns the new
symbol. Prefer keeping app ergonomics in `views`, runtime construction and host
runtime handles in `runtime`, neutral contracts in `core`, host routing in
`backend`, and concrete renderer details in the renderer package that
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
- semantic classification budgets for the high-risk packages
  `moui/core`, `moui/views`, `moui/runtime`, `moui/backend`, and
  `moui/render`, so new public declarations must be categorized as
  `app_constructor`, `app_state_helper`, `app_style`,
  `advanced_core_protocol`, `runtime_diagnostic`, `host_contract`,
  `renderer_contract`, `required_protocol`, `test_exposure`, or
  `migration_debt`;
- root facade imports and forbidden host/renderer/runtime tokens;
- required domain facade tokens for geometry, graphics, animation, text, and
  state/focus packages, plus cross-domain forbidden aliases;
- `moui/views` staying app-facing by exposing constructors, command/menu/theme
  helpers, and `DateValue` while rejecting low-level drawing, animation,
  focus-scope, semantics, runtime-id, and component-kernel re-exports;
- `moui/runtime` existence, an opaque `AppRuntime` with bounded runtime methods,
  runtime source not wrapping `@core.AppRuntime` or `@core.RuntimeKernel`, and
  app/host source usage of `@runtime.AppRuntime`;
- final core/runtime boundary tokens: public `ViewNode` and `View::from_node`
  must appear in core, while `RuntimeKernel`, `RuntimeState`, `ViewSpec`,
  `ElementNode`, `ElementTree`, `ViewLoweringSink`, `View::node`, and
  `@core.View::primitive_*_view` must not appear in the core generated public API;
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
API expansion is worth keeping, update the numeric and semantic budgets and
explain the owning package reason in the same change. Current counts and
follow-up candidates live in [API surface audit](api-surface-audit.md).
