# MoUI Application Package Boundary Specification

This document defines the packages on which MoUI applications may depend; the
boundary of `wzzc-dev/moui/core` as the foundational protocol layer / abstract UI
kernel; how the root facade, `wzzc-dev/moui` (app-loop convenience API), and
domain facades (`moui/geometry`, `moui/graphics`, `moui/animation`,
`moui/text`, and `moui/state`) expose app-facing kernel types by domain; and how
`wzzc-dev/moui/views` owns standard view constructors, control semantics, and
low-level control implementations.

## Core Role

`wzzc-dev/moui/core` is the **foundational protocol layer / abstract UI kernel**.
It defines UI protocols and value types that remain stable across runtimes,
backends, and renderers, enabling apps, views, runtimes, backends, and renderers
to interoperate over a shared abstraction.

`core` should contain:

- Foundational value types: geometry, color, brush, font, event, keyboard, text
  range, and similar types.
- Abstract UI protocols: `View` and layout/paint/event/semantics/focus/text-input
  contracts.
- App-loop contracts: platform-neutral execution protocols such as `Program`,
  `Effect`, and `Subscription`.
- Renderer-neutral drawing, text, and accessibility contracts: drawing commands,
  text-measurement protocols, and semantics-tree protocols.
- The neutral token surface for themes: it is not coupled to a specific design
  system brand and contains no platform or renderer implementation.

`core` must not become:

- A control catalog: concrete control APIs for buttons, forms, pickers, rich-text
  editors, and similar controls belong in `moui/views`, not in the kernel.
- A runtime implementation: the element tree, dirty state, runtime lifecycle,
  component storage, and actual task/subscription scheduling belong in
  `moui/runtime`.
- An app-service implementation: app-facing file, clipboard, URL, settings,
  appearance, menu, timer, and route contracts belong in `moui/services`;
  host wire protocols belong in `moui/backend` or an independent platform addon
  such as `moui_webview`.
- A renderer implementation: Skia, WGPU, and browser WebGPU details belong in
  `moui/render/*`.
- A design-system addon: Material, Fluent, Carbon, Primer, and their component
  tokens belong in `moui_theme/*` or an app-facing style facade in `moui/views`.

Dependencies follow Iced-style one-way layering: `core` is the foundation, and
domain facades, `views`, `runtime`, `backend`, and `render` may depend on and
extend it. `core` must never depend on `geometry`, `graphics`, `animation`,
`text`, `state`, `views`, `runtime`, `backend`, `render`, or addon packages.

## Minimal-Package Strategy

MoUI package boundaries should remain few and clear. Do not split every feature
name into a separate top-level public package. Unless an existing layer cannot
naturally own the responsibility, do not add fragmented packages such as
`moui/style`, `moui/forms`, `moui/rich_text`, `moui/routing`, `moui/platform`, or
`moui/diagnostics`.

**The root `wzzc-dev/moui` package** re-exports only frequently used app-loop
types (`View`, `Program`, `Effect`, and so on). Use them as `@moui.*` to avoid a
collision with the default `@app` alias of `examples/*/app` packages.

**Domain facades** (see “Domain Facade Exposure Rules” below) are
`moui/geometry`, `moui/graphics`, `moui/animation`, `moui/text`, and
`moui/state`. They are app-facing facades/extensions over `core`. Initially,
they primarily expose frequently used types through `pub using @core {type X}`.
Later, they may own lightweight domain helpers that do not belong in `core`, but
they must not depend on `views`, `runtime`, `backend`, `render`, or another
domain facade, and `core` must not depend on them. A new domain facade must state
its re-export set, extension responsibility, and why neither the root facade nor
an existing domain facade can own it.

The current target placement is:

- App-facing capabilities and concrete control behavior belong in `moui/views`:
  control styles, form helpers, routing/history, picker items, the rich-text
  facade that ordinary apps need to see, and low-level custom-view
  implementations for buttons, text fields, pickers, and similar controls.
  WebView constructors and bridge types belong to `moui_webview/views` and
  `moui_webview/host`.
- Runtime and diagnostics belong in `moui/runtime`: runtime inspector,
  program-lifecycle snapshots, view/render-diagnostic snapshots, and
  `ComponentContext` runtime-construction details.
- App-facing platform capabilities belong in `moui/services`. Generic host
  capabilities and host-service protocols stay in `moui/backend`; WebView wire
  commands/events and policies stay in `moui_webview`.
- Renderer and backend implementations remain in `moui/render/*` and
  `moui/backend/*`.

Consider a new addon or more specialized package only when the preceding layers
cannot naturally own a capability and it will be stably reused by multiple
packages. A new package must first explain why the responsibility does not
belong in `views`, `runtime`, or `backend`.

## Current Core Convergence Status

Measured against its role as the “foundational protocol layer / abstract UI
kernel,” `moui/core` has already moved out the following substantial
capabilities. These migrations are the default boundary for future APIs and
must not be reversed by moving them back into `core`.

- **Control-style and picker-model ownership has moved out**: `ButtonStyle`,
  `TextFieldStyle`, `ChoiceControlStyle`, `ProgressStyle`, `SliderStyle`,
  `PickerStyle`, `FeedbackStyle`, `BadgeStyle`, `FormValidationStyle`, and
  `PickerItem` are owned by `moui/views`. `core` retains only foundational
  values such as `Color`, `Brush`, `BorderStyle`, `ShadowStyle`, and `Theme`
  tokens. The picker’s low-level option representation is private implementation
  detail of the `views` package; ordinary apps use `@views.PickerItem` /
  `@views.picker`.
- **Control theming lives in `views` (ADR 0017)**: `Theme` carries only
  neutral palette/spacing/typography — no `components` field. Control tokens
  (`ControlThemeSet`, `ButtonTheme`, `ControlStateTokens`, `ControlStateStyle`)
  live in `moui/views/style/` (`control_theme_tokens.mbt`,
  `control_theme_set.mbt`, `control_style.mbt`). App-side control appearance
  should read `@views.ControlThemeSet` via
  `@style.views_ambient_control_theme(theme)` and use `@views.*Style` /
  `light_theme`/`theme`. See `docs/plans/done/core-component-theme-to-views.md`
  (superseded by ADR 0017).
- **WebView ownership has moved out**: WebView-specific controller, bridge,
  policy, request, and event types are owned by the independent
  `wzzc-dev/moui_webview` addon. `core` retains only renderer-neutral
  `PlatformViewPlacement`, `PlatformViewProperty`, `PlatformViewEvent`, and
  `AppEvent::PlatformView`. Composition roots create `@host.WebViewHost` and
  `@host.WebViewController`; views receive only the controller identity and
  native appearance fields.
- **Form-model ownership has moved out**: `FormFieldState`,
  `FormValidationRule`, `FormController`, `validate_form`, and `required_field`
  are owned by the form-support layer in `moui/views`. `core` no longer carries
  concrete form workflows.
- **Rich-text ownership has moved out**: `RichTextDocument`, tables, images,
  source ranges, and rich-text geometry/paint/selection helpers are owned by the
  `moui_richtext` addon. Ordinary apps use facades such as
  `@moui_richtext.RichTextDocument`, `@moui_richtext.RichTextInputTransform`,
  `@moui_richtext.rich_text_document_height`, `@moui_richtext.markdown_editor`,
  and `@moui_richtext.controlled_markdown_session_editor`. `core` retains only
  `TextRange`, grapheme boundaries, `TextSystem`, the paragraph-layout contract,
  and foundational text-input state. `moui/views` retains only the plain-text
  `text`/`text_field`/`text_area` controls.
- **The `ComponentContext` runtime-construction entrypoint has been narrowed**:
  `ComponentContext` remains a component-facing kernel type in `core` because
  the signatures of `View::from_node` / `views.component` require it and `core`
  cannot depend on `runtime`. The runtime constructs an execution context with
  `ComponentContext::from_runtime(ComponentRuntimeContextInput)`; ordinary
  component APIs do not expose scattered runtime-storage parameters, and domain
  facades do not re-export this construction entrypoint.
- **Date-picker control semantics have moved out**: `DateValue` is a neutral
  data model and remains in `core`; `DatePickerMode` is concrete control
  semantics and belongs in `moui/views`. The low-level display-mode
  representation is private implementation detail of `views`; the ordinary
  constructor performs the conversion.
- **Sheet control semantics have moved out**: `SheetPresentationMode` is sheet
  control semantics and belongs in `moui/views`. `core` does not export it;
  sheet / sheet_host constructors use `@views.SheetPresentationMode` directly.
- **The theme schema and default aesthetics are separated**: `core.Theme` /
  `core.Environment` retain the token schema and `neutral()` fallback/testing
  values; app-facing default aesthetics such as `default_theme()`,
  `light_theme()`, and `dark_theme()` belong in `moui/views`.
- **Diagnostics/Inspector structures are runtime/devtools-oriented**:
  `RuntimeInspectorSnapshot`, `ProgramRuntimeSnapshot`,
  `ViewTreeInspectorSnapshot`, `RenderInspectorSnapshot`, and related APIs are
  valuable diagnostic APIs, but not foundational UI-kernel protocols.
  `EffectPlanSummary`, `SubscriptionPlanSummary`, and runtime snapshots are
  owned by `moui/runtime`; `core` no longer exports diagnostics summaries or
  runtime operation lists and must not own new diagnostics APIs. Domain facades
  do not re-export them; devtools/overlays should build views from
  `@runtime.*` diagnostic types.
- **Routing/history ownership has moved out**: `RouteLocation`,
  `RouteDescriptor`, `RouterSnapshot`, `RouteHistoryState`, `RouteFocusStore`,
  `RouterState`, and `resolve_route` are owned by navigation support in
  `moui/views`. `core` retains only foundational state holders such as
  `NavigationState`. Route events use `@services.RouteLocation`; ordinary
  apps convert them to `@views.RouteLocation` when integrating navigation
  history.

New APIs default to the more specific owning package. Add an API to `core` only
after confirming that it is a cross-runtime abstract protocol or foundational
value type.

## Target Boundary Declaration

This specification describes the target boundary of the current API. Place new
dependencies or public APIs directly in their owning packages; do not retain
compatibility aliases or deprecated transition entrypoints.

- App-facing controls, control semantics, default themes, form/routing/rich-text
  facades, and concrete custom-view control behavior belong in `moui/views`.
  WebView views and controller/bridge types belong in the independent
  `moui_webview` addon.
- Runtime lifecycle, component-runtime input, effect/subscription diagnostic
  summaries, and inspector snapshots belong in `moui/runtime`.
- App-facing service protocols belong in `moui/services`; host wire protocols
  belong in `moui/backend` or a concrete backend.
- `core` retains only protocols and value types that remain stable across
  runtimes, backends, renderers, and views.

Showcase runtime/renderer diagnostics live in the Showcase module-root
integration package and enter the pure app as neutral DTOs. Extra imports under test targets
(`for "test"` / `for "wbtest"`) do not count toward the production boundary.

## Ordinary Shared App Packages

An ordinary shared app package is a platform-neutral business-logic package such
as `examples/*/app`, as well as similarly structured `website/app` and
`examples/agent_counter`, which places its shared app at the example root. They
should depend by default on:

- `wzzc-dev/moui` — app-loop convenience API (`@moui.View`,
  `@moui.Program`, `@moui.Effect`, `Subscription`, `Theme`, `Environment`, and
  `ViewEnvironment`). This stays distinct from the `@app` alias for the shared
  app package’s business module.

- `wzzc-dev/moui/<领域>` — other frequently used domain facades, imported as
  needed:

  - `wzzc-dev/moui/geometry`: `Point`, `Size`, `Rect`, `Insets`, `Constraints`, `Axis`, `Alignment`.
  - `wzzc-dev/moui/graphics`: `Color`, `Brush`, `BorderStyle`, `ShadowStyle`,
    `RoundedRect`, `PathSpec`, `PathVerb`, `ImageRun`, `ImageFit`, `BlendMode`,
    `LayerSpec`, `LayerMask`, `FilterEffect`, `ShadowSpec`, `Transform2D`,
    `ShaderEffectSpec`.
  - `wzzc-dev/moui/animation`: `Easing`, `TransitionSpec`, `TransitionStyle`.
  - `wzzc-dev/moui/text`: `FontSpec`, `FontFamily`, `TextRange`, `TextAlign`,
    `FontFamilyStack`, `TextRun` (the latter two are frequently used in examples
    and drawing helpers).
  - `wzzc-dev/moui/state`: `State`, `Binding`, `DerivedState`, `ScrollState`,
    `FocusState`, `NavigationState`, `ColorScheme`, `LayoutDirection`,
    `FocusScope`, `FocusScopeItem`.

  Domain facades currently depend only on `core` and primarily forward types
  through `pub using @core {type X}`; a domain-prefixed type and `@core.X` are
  the same type. An app should use one prefix consistently in each source file
  and avoid two prefixes for the same type in that file (see the former Showcase
  issue where `@moui.View` and `@core.Point` coexisted). References to business
  APIs across example packages remain `@app.ShowcaseModel` and similar paths.

- `wzzc-dev/moui/views` — the entrypoint for app-facing UI constructors. The
  application layer should preferentially use its functions to compose buttons,
  text, layouts, forms, lists, dialogs, theme helpers, and so on. WebView
  wrappers use `wzzc-dev/moui_webview/views`. It also forwards command/menu types (`ActionCommand`, `CommandIntent`,
  `KeyboardShortcut`, and others), default-theme helpers, control styles, and
  form/navigation/data helpers through its facade. `DateValue` temporarily
  remains available through the `@views.DateValue` facade because the date-picker
  public API is already exposed; drawing, animation, focus-scope, and low-level
  runtime/semantics IDs are no longer catch-all exports from `@views`.

- `wzzc-dev/moui/services` — app-facing file, clipboard, URL, settings,
  appearance, menu, timer, and route capabilities. One-shot operations return
  typed `ServiceTask[T]`; sources emit core `Subscription` values. Neither API
  exposes a host bridge, request id, or completion queue.

- `wzzc-dev/moui_i18n` — an **optional localization addon**. It provides locale
  normalization, static catalog lookup, fallback, named interpolation, and
  limited count-message rules; the app still owns its product catalog and locale
  selection. It is not re-exported by the root facade or `views`, and it does
  not add JSON, resource loading, or platform-locale detection to `core`. See
  `docs/internationalization.md` for the complete workflow.

- `wzzc-dev/moui/core` — the **source of truth for types**. At **runtime**, a
  shared app should preferentially use `@moui` / domain convenience APIs /
  `@views`, so its default `moon.pkg` **does not** import `core`
  (`validate_api_surface` enforces a core-import budget for shared apps). Import
  `wzzc-dev/moui/core` (and `runtime` as needed) under `for "test"` /
  `for "wbtest"` for infrequent kernel use, custom `ViewNode` implementations,
  or **tests** that simulate `AppEvent` / `DrawCommand`; test targets do not
  count toward the default runtime boundary.

The `wzzc-dev/moui` root package re-exports **only** app-loop convenience APIs;
geometry, graphics, animation, text, and state remain available through their
corresponding domain facades. Other infrequently used kernel types are used
directly through `@core`.

Ordinary apps must not directly depend on:

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/backend`
- `wzzc-dev/moui/render/*`
- `wzzc-dev/moui/backend/{web,macos,windows,linux}`
- concrete renderer packages; renderer providers belong in platform composition
  roots and are not dependencies of shared app packages.
- `moui_theme/*`, unless the app itself is a design-system addon or preview app.

There are no production exceptions for `examples/*/app`; integration-only
packages may depend on runtime, host, or render and pass neutral DTOs into apps.

## App-Private Subpackages

In addition to a shared app package, some apps include their own private support
packages, such as `pdfium_adapter`, `pdflite_adapter`, and `pdflite_service_*`
in `examples/pdf_workbench`. These packages are neither ordinary shared app
packages nor platform entrypoint packages; they are adapters, service
implementations, or interprocess protocols specific to one app.

Placement rules:

- They serve only their host app and must not be depended on by another app or a
  framework layer.
- They may depend on `@core`, `@backend`, `@views`, and the app’s own shared
  app package according to their specific responsibility, but an ordinary shared
  app package must not depend on them in the reverse direction.
- They do not participate in domain facades and do not add app-specific types to
  `@core` / `@views`.
- During review, treat them as implementation details of the app, not as part of
  the framework API surface.

If an abstraction in an app-private subpackage gradually becomes reused by
multiple apps, consider promoting it to `moui/views`, `moui/core`, or an
independent addon package instead of retaining it as a private subpackage of one
app.

## Domain Facade Exposure Rules

Platform-neutral foundational types in `wzzc-dev/moui/core` are selectively
re-exported by the root `wzzc-dev/moui` package (app loop) and domain facades so
ordinary apps need less `@core` prefix boilerplate. Domain facades follow these
principles:

- **`core` is the source of truth; domain facades own app-facing prefixes**. A
  domain facade’s primary responsibility is to shorten frequently used type
  prefixes; it **does not seek complete coverage** of the `core` public surface.
  `@core.X` and `@<domain>.X` are the same type. A future domain helper must be a
  lightweight app-facing extension over `core` and must not cause `core` to
  depend back on the domain package.
- **Each type belongs to exactly one domain facade**. Assign types crossing
  collection boundaries such as layout and state by semantics (for example,
  `ColorScheme` belongs to `state` because it participates in theme resolution,
  not to `graphics`), rather than placing the same type in multiple domain
  facades based on how often apps use it.
- **Dependencies are one-way; facades do not import one another**. A domain
  facade imports only `wzzc-dev/moui/core`; it does not depend on another domain
  facade or re-export types from `views`/`runtime`/`backend`/`render`/`host`.
- **Forward only app-safe neutral types**. Do not forward runtime trees,
  renderers, backends, inspectors, debug payloads, private view-implementation
  details, control modes/styles/default themes, form helpers, WebView
  commands/events, routing/history controllers, or rich-text documents.

### Domain Facade Inventory

**`wzzc-dev/moui` (root facade, `moui/moui.mbt`)** — `@moui.*`
```
View  Program  Effect  Subscription  Theme  Environment  ViewEnvironment
```

**`moui/geometry`** (import `@core`)
```
Point  Size  Rect  Insets  Constraints  Axis  Alignment
MainAxisAlignment  CrossAxisAlignment
```

**`moui/graphics`** (import `@core`)
```
Color  Brush  BorderStyle  ShadowStyle  RoundedRect  PathSpec  PathVerb
ImageRun  ImageFit  BlendMode  LayerSpec  LayerMask  FilterEffect
ShadowSpec  Transform2D  ShaderEffectSpec
```

**`moui/animation`** (import `@core`)
```
Easing  TransitionSpec  TransitionStyle
```

**`moui/text`** (import `@core`)
```
FontSpec  FontFamily  TextRange  TextAlign  FontFamilyStack  TextRun
```

**`moui/state`** (import `@core`)
```
State  Binding  DerivedState  ScrollState  FocusState  NavigationState
ColorScheme  LayoutDirection  FocusScope  FocusScopeItem
```

### `@views` Forwarding (constructor / control facade; not a kernel catch-all)

**Allowed** (control-workflow surface):

- Commands and menus: `ActionCommand`, `ActionCommandMap`, `CommandBinding`,
  `CommandIntent`, `KeyModifiers`, `KeyboardShortcut` (`menu_commands.mbt`).
- Date-picker data: `DateValue` temporarily remains `@views.DateValue` (the
  date-picker public API is already exposed; no independent domain facade
  exists).
- Theme-construction helpers: `ColorPalette`, `TypographyScale` (`theme.mbt`).
- Control-style bridge: `ControlStateStyle` (`control_style.mbt`; the source of
  truth is `core`).

**Disallowed** (domain value types; use a domain facade rather than re-exporting
from `@views`):

- `@graphics.Color` / paint value types — **do not** use `@views.Color`
- `@state.ColorScheme` — **do not** use `@views.ColorScheme`
- Other geometry, animation, text, and state value types — use their
  corresponding domain facade

Drawing, animation, focus, and low-level runtime-ID paths:

- Use `@graphics.Color`, `@graphics.RoundedRect`, `@graphics.PathSpec`,
  `@graphics.ImageFit`, `@graphics.LayerSpec`, `@graphics.Transform2D`, and so
  on for drawing and low-level paint types.
- Use `@animation.TransitionSpec`, `@animation.TransitionStyle`, and
  `@animation.Easing` for animation types.
- Use `@state.FocusScope`, `@state.FocusScopeItem`, and `@state.ColorScheme`
  for focus / scheme types.
- When required, use diagnostics/kernel-only types such as
  `@core.SemanticsRole` and `@core.ComponentContext` directly, and restrict
  this to Showcase/diagnostics/custom-kernel or test contexts. Element
  identity is runtime-private; no app or diagnostic package receives an
  `@core.ElementId`.

### No Convenience API / Test-Only or Framework Direct `@core`

The following remain kernel types and have **no domain facade**. Shared-app main
code should avoid an `@core` prefix; tests may import `core` under `for "test"` /
`for "wbtest"` and use it there:

`AccessibilityContrast`, `ContentSizeCategory`;
`AppEvent`, `KeyboardEvent`, `PointerEvent`, `DrawCommand`, `CompositionUpdate`,
and other event and drawing protocols (runtime tests and capability
presentations).

Historical plans listed `CommandIntent` and similar types as “`@core` only”; the
current rule is the **`@views` re-export**.

### Alias Syntax Rule

Domain facades must uniformly expose `core` types with the modern
`pub using @core {type X}` syntax:

```moonbit
pub using @core {type View}
```

**The legacy `pub type X = @core.X` syntax is prohibited.** When MoonBit tools
regenerate `pkg.generated.mbti` with `moon info`, both forms normalize to
`pub using @core {type X}`. The modern syntax is therefore jointly maintained by
review and the API-surface guard’s `required_tokens`; handwritten legacy aliases
are not valid under this specification.

The owning package for diagnostics types is `wzzc-dev/moui/runtime`. `core` no
longer exports diagnostics/runtime types such as `EffectPlanSummary`,
`SubscriptionPlanSummary`, `EffectRuntimeOp`, `InspectorSnapshot`,
`ProgramRuntimeSnapshot`, or `RenderInspectorSnapshot`, and domain facades do
not re-export them.

The owning package for WebView types is the independent
`wzzc-dev/moui_webview` addon. `core` no longer exports WebView-specific
controller, bridge, policy, or event types, nor does it provide WebView
helpers such as `PlatformViewPlacement::web_view`; domain facades do not
re-export them.

### Extending a Domain Facade

Extending domain facades (adding a type to an existing domain facade or adding a
new domain facade) must also:

- Update `pkg.generated.mbti` (run `moon info <pkg>`).
- Update the corresponding domain facade’s `sugar_<domain>_tokens()` and budget
  in `tools/moui/validate_api_surface/main.mbt`.
- Confirm in review that the new type is a platform-neutral, app-safe,
  frequently used kernel type, or a lightweight extension naturally owned by
  that domain; and that it does not overlap an existing domain facade or the
  “No Convenience API” list.

Expanding the public surface of `@core` does not require a simultaneous domain-
facade update. Domain facades own only the collection of “frequently used
app-facing prefixes”; a new kernel type defaults to direct `@core` use until it
is explicitly added to a domain-facade inventory.

## `moui/views` Low-Level Custom-View Rules

`wzzc-dev/moui/views` serves both ordinary apps and MoUI built-in control
implementers. Ordinary apps use app-facing constructors such as `button`,
`text_field`, and `picker`; framework and control implementations may use
private `*_control` / `*_layout` / `*_surface` helpers within the `views` package
to implement `@core.ViewNode` and construct typed views with
`@core.View::from_node`.

Add a low-level helper only when implementing a new reusable control that must
customize one of the following behaviors:

- layout
- paint
- event handling
- text-input state / text commands
- semantics
- focus

If merely composing existing controls such as buttons, forms, lists, layouts,
dialogs, or menus, the application layer should use the app-facing constructors
in `wzzc-dev/moui/views`. WebView composition uses the corresponding
`wzzc-dev/moui_webview/views` constructors and host controller tasks.

Place a new control as follows:

- Put public app-facing constructors in `moui/views`.
- Put the concrete custom-view behavior implementation in `moui/views` as well;
  helper names should describe behavior, such as `button_control`,
  `text_field_control`, or `scroll_container`.
- Implement the message-independent `@core.ViewNode` protocol with types such as
  `ViewLayoutContext` and `ViewPaintContext`, then attach typed children,
  `ViewEventContext` handlers, and text commands through
  `@core.View::from_node`.
- Ordinary apps see only `@views.some_control(...) -> View[Msg]`.

Third-party addon packages may import `wzzc-dev/moui/core`, implement the open
`ViewNode` trait for their own concrete node types, and call `View::from_node`.
They cannot implement methods for MoUI-owned node types, access runtime trees,
or bypass typed `View[Msg]` message delivery.

In other words, Iced’s control layer is both the built-in-control and
custom-control entrypoint. MoUI currently unifies those entrypoints in
`moui/views`: ordinary apps use high-level constructors, while control authors
reuse private control/layout helpers in the same package. This does not alter the
ordinary-app default-dependency rule of `moui/<领域>` (as needed) and
`moui/views`; the low-level extension surface is `@core.ViewNode` plus
`@core.View::from_node(...)`, and it is intentionally not re-exported by the
root `moui` facade.

## Platform Entrypoint Packages

Platform entrypoint packages are executable packages such as
`examples/*/{web_wasm,macos_skia,windows_skia,linux_skia,android_window_hosted,ios_window_hosted,harmonyos_window_hosted}`.
They create the runtime, connect a platform backend, and select a renderer.
Desktop/Web/Wechat roots import `wzzc-dev/moui/runtime`, one concrete renderer package,
and one platform backend, then use
`@runtime.run_app(...)`, `.render(...)` or `.render_all(...)`, and
`.backend(...).run()`. Platform options are
captured by `backend/<platform>.entry(...)`; renderer options and native-handle
policy are captured by the renderer provider. A composition root never imports a renderer-specific
backend subpackage.

Moon `0.1.20260724` does not turn `pub using` aliases into wasm exports: the
linker exports public definitions owned by the executable package only. A Web
or WeChat entrypoint may therefore use `abi.mbt` as its second production file.
That file contains only the fixed callbacks which delegate directly to
`backend/web` or `backend/wechat`; it must not contain app state, routing,
service, renderer, or lifecycle logic. `validate-harness-invariants.mjs`
enforces the closed shim surface, while Web handoff validation inspects the
compiled wasm exports.

The three embedded runtime routes use the matching `wzzc-dev/window` template and a
`*_window_hosted` entrypoint. Their `main.mbt` files construct the program and
compose renderer providers with the platform `entry()` through `AppBuilder`.
`HostCmd` and `ApplicationHandler` remain the only path for lifecycle, surface,
and input callbacks; mobile executable roots do not export or forward a second
embedding ABI.

Android, iOS, and HarmonyOS templates own their native lifecycle and surface
bridges. `AndroidEmbeddedRuntimeBackend`, `IosEmbeddedRuntimeBackend`, and
`HarmonyOSEmbeddedRuntimeBackend` assemble the MoUI runtime session after the window
event loop creates a surface. HarmonyOS XComponent callbacks remain the sole
source for surface, pointer, resize, and detach events.

Platform entrypoint packages may depend on:

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/backend/web`
- `wzzc-dev/moui/backend`
- `wzzc-dev/moui/backend/{macos,windows,linux,android,ios,harmonyos}`
- one of `wzzc-dev/moui/render/{skia,wgpu,sun,canvas2d,webgpu_adapter}`
- `wzzc-dev/window/{android,ios,harmonyos}` in the matching mobile entrypoint
- The corresponding shared app package, such as `examples/showcase/app`

WGPU-related renderer packages are for experimental or diagnostic
entrypoints only; they are not recommended dependencies for ordinary apps or
default platform entrypoints.

A platform entrypoint package must not contain business UI. Business views,
models, and updates remain in the shared app package; the platform entrypoint is
responsible only for runtime + backend + renderer wiring.

## Framework and Control Implementation Packages

Framework internals, control implementations, and renderer/backend integrations
may use lower-level packages.

- `moui/core`: the foundational protocol layer / abstract UI kernel, containing
  platform-neutral protocols and value types such as `View`, event, layout,
  paint, semantics, and text contracts.
- `moui/views`: app-facing constructors and concrete custom-view control-behavior
  implementations.
- `moui/runtime`: runtime state, element tree, layout/paint/event dispatch, and
  program execution.
- `moui/services`: app-facing services and timer/route sources.
- `moui/backend`: host wire, window, event, bridge, and queue protocols.
- `moui/backend/*`: platform backends.
- `moui/render/*`: renderer facades and concrete renderer implementations.
- `moui_richtext`: an addon for rich-text/Markdown documents, editing, commands,
  input, paste, tables, and source mapping. Rich-editing apps such as
  `examples/markdown_editor`, `examples/mo_workbench`, and `examples/showcase`
  may depend on it directly as needed; it is not a default dependency of
  `core`, `views`, or domain facades.
- `moui_agent` / `moui_agent_mcp`: addons for agent protocols, schemas, host
  runtimes, and MCP router support. Agent-controllable apps such as
  `examples/agent_counter` may depend on them directly as needed; they are not
  default dependencies of `core`, `views`, or domain facades.
- `moui_theme/*`: design-system addons; they are not default dependencies of
  `core`, `views`, or domain facades.

Ordinary apps depend by default on `moui/<domain>` (as needed), `moui/views`,
and `moui/services` when they need platform capabilities. Direct dependencies on addons such as `moui_richtext`,
`moui_agent*`, and `moui_theme/*` are allowed only when an app explicitly needs
that capability. `moui/core` is reserved for advanced kernel types; production
imports of runtime, backend, or render packages are rejected without an app
allowlist.

## Review Checklist

Before adding a dependency or public API, answer these questions:

- Is this package an ordinary shared app, a platform entrypoint, a test, or a
  framework/control implementation?
- Does an ordinary shared app depend on `wzzc-dev/moui`,
  `wzzc-dev/moui/<domain>` (as needed), and `wzzc-dev/moui/views`?
- If an ordinary app imports `wzzc-dev/moui/core`, does it truly need a kernel
  type that a domain facade does not cover (a first-class use case)?
- Does an ordinary app use `wzzc-dev/moui/services` instead of importing a host
  bridge or queue?
- Does an ordinary app incorrectly depend on `runtime`, `render/*`, or a
  platform backend?
- Is a new domain-facade alias a platform-neutral, app-safe, frequently used
  type, and has the API-surface guard been updated?
- Does a new low-level custom-view helper also provide an app-facing constructor
  in `moui/views`?
- Does a new control avoid adding a concrete control enum variant, primitive
  constructor, or runtime-lowering branch to `core`?
- Is a new `core` API truly a cross-runtime foundational protocol / abstract UI
  kernel capability?
- Would a new style, form, WebView, routing, rich-text editor, or diagnostics
  API fit better in `views`, `runtime`, `backend`, `moui_devtools`, or an
  addon?
- Does `moui_theme/*` remain an addon/preview dependency rather than a default
  dependency of ordinary apps?

If a change must break these rules, it must state its rationale in the same
change and explain why the responsibility does not fit better in `views`,
`runtime`, `backend`, or `render`.
