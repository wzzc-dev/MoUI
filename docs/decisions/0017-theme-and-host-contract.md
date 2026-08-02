# ADR 0017-0018: Theme and Host Contract (merged)

> 原编号保留为小节锚点: 0017-theme-layering-and-control-theme-set,0018-host-contract-split-and-runtime-render-ownership

---

## 0017: Theme layering and views-owned ControlThemeSet

- **Date**: 2026-07-28
- **Status**: Accepted
- **Deciders**: Agent-assisted (AtomCode GLM-5.2)
- **Related**: supersedes the default "S1 schema stay" path of
  `docs/plans/done/core-component-theme-to-views.md`; ADR 0014 (core owns
  value types); ADR 0015 (public ViewNode trait); invariants P3/P6/P7

### Context

`core.Theme` currently embeds `components : ComponentThemes`, a struct whose
fields are concrete control themes (`ButtonTheme`, `TextFieldTheme`,
`SliderTheme`, `PickerTheme`, `ChoiceControlTheme`, `ProgressTheme`,
`FeedbackTheme`, `BadgeTheme`, `SurfaceTheme`, `FormValidationTheme`). These
types plus their supporting tokens (`ControlStateTokens`, `ControlStateStyle`,
`StateLayerTokens`, `ButtonVariantToken`, `ChoiceControlShape`,
`CheckMarkStyle`, `TextFieldAppearance`, `ThumbShape`, `InteractionState`,
`ToneTokens`) all live on `core`'s public surface.

This couples the neutral cross-runtime contract package (`moui/core`) to
concrete control vocabulary. Adding a control or its tokens requires editing
`core`, violating invariant P3 ("core holds cross-runtime protocol + neutral
value types") and the open-extension principle in invariant P2/P6. The
existing plan `core-component-theme-to-views.md` identified this coupling and
deliberately deferred the split under "S1 schema stay" until an explicit RFC.

Forces:

- `core` must not depend on `moui/views` (B-model dependency direction).
- `moui_theme/*` and ambient theme resolution must keep working; branded
  component themes project into the same surface apps consume.
- App control **styles** (`ButtonStyle`, `TextFieldStyle`, …) already live in
  `moui/views`; the move is about the **token layer** below them.
- MoonBit package visibility forbids a views-only type on `core.Theme`'s
  fields without circular import.

### Decision

Split `Theme` into two layers.

1. **`core.Theme` = neutral theme base.** Keep `scheme`, `palette`,
   `spacing_scale`, `radius_scale`, `typography`, `shadow_scale`, `motion`,
   `surfaces`. **Remove** `components` and `with_components`. The neutral
   base has no control vocabulary.
2. **`moui/views` owns `ControlThemeSet`.** A new views-public struct holds
   all concrete control themes (`ButtonTheme`, `TextFieldTheme`,
   `SliderTheme`, `PickerTheme`, …) and their tokens
   (`ControlStateTokens`, `ControlStateStyle`, `StateLayerTokens`,
   `ButtonVariantToken`, `InteractionState`, `ToneTokens`, shape enums).
   Views constructs the default `ControlThemeSet` from a neutral `core.Theme`
   + `core.ColorPalette`/`core.ColorScheme` (resolve helpers move to views).
3. **Attachment surface.** `ViewStyle::from_theme` and component host lookup
   consume `ControlThemeSet` via the view environment, not `Theme.components`.
   The ambient theme pipeline resolves a neutral `Theme` (core) and then a
   views-owned `ControlThemeSet`; branded `moui_theme/*` projects into both.
4. **Kernel schema carve-out.** `core` keeps only genuinely cross-package
   neutral tokens that views still needs without forcing views to duplicate:
   none of the concrete control themes qualify, so all control token structs
   move. `InteractionState` (a generic interaction state machine used by
   core's own gesture/semantics layer) stays as a core **neutral** enum.
   `PressableState` (the three-state pointer gesture enum
   `Normal`/`Hovered`/`Pressed`, formerly named `ButtonState`) also stays in
   `core`: it is consumed by `core`'s own `gesture.mbt` and `view_tree.mbt`
   as the neutral click/hover state machine for any tappable element, not
   button-specific vocabulary. The original draft of this ADR classified
   `ButtonState` as control-only and proposed moving it to views; that
   classification was incorrect — the type is replayed by core's gesture
   state machine and read by core's view-tree slot reconciliation, so it is
   neutral like `InteractionState`. It has been renamed to `PressableState`
   to reflect its neutral role (any pressable element, not just buttons).
   Only the concrete control **theme token** structs (`ButtonTheme`,
   `ControlStateTokens`, `ComponentThemes`, …) move to views.

### Options Considered

### Option A: S2 — split Theme, views owns ControlThemeSet (chosen)

- Pros: core has zero control vocabulary; open extension (new control adds a
  field to `ControlThemeSet` in views, never touches core); matches ADR 0014
  and the requested `ControlThemeSet` abstraction; ambient/branded theme
  pipelines keep working with a two-stage resolve.
- Cons: breaks `Theme.components`/`with_components` consumers in one migration
  (`moui_theme/*`, `moui/views`, root facade, examples, docs); two-stage
  resolve adds one indirection.

### Option B: S1 — schema stay (prior default)

- Pros: zero migration; `ComponentThemes` stays as "kernel theme schema".
- Cons: core keeps control vocabulary; adding controls still edits core;
  does not satisfy the invariant or the requested convergence.

### Option C: S3 — opaque views-owned bag on `Theme` field

- Pros: `Theme` keeps a single bag slot; branded projects into bag.
- Cons: MoonBit package visibility makes a typed-but-opaque bag impractical
  without views→core dependency or runtime dyn-typed maps; loses static
  resolve and `derive(Eq, ToJson)` on the theme.

### Rationale

S2 is the only option that satisfies "core never holds control vocabulary"
(open extension + invariant P3) while preserving static typing and the
`derive(Eq, ToJson)` theme pipeline. The migration cost is bounded and
mechanical: every consumer of `Theme.components.*` already lives in
`moui/views` or `moui_theme/*`, both of which are allowed to depend on a
views-owned `ControlThemeSet`.

`InteractionState` and `PressableState` (formerly `ButtonState`) both stay
in core as **neutral** gesture/interaction state machines (they are
consumed by `core`'s own gesture, semantics, and view-state machinery —
`gesture.mbt`, `view_tree.mbt` — not by any control's vocabulary).
`ButtonState` was renamed to `PressableState` to make its neutral role
clear (any pressable element, not just buttons). Only the concrete control
**theme token** structs move to views.

### Consequences

- `core.Theme` public surface shrinks: removes `components` field, the
  per-control theme structs, `ComponentThemes`, `with_components`, control
  shape/appearance enums. `moon info` baseline drops.
- `moui/views` gains `ControlThemeSet` + migrated token structs + resolve
  helpers (`resolve_minimal_control_theme`, branded control theme defaults).
- `moui_theme/*` projects branded component tokens into `ControlThemeSet`
  (views), not `ComponentThemes` (core).
- Ambient theme resolver produces `(Theme, ControlThemeSet)`; root facade
  and examples update.
- Invariants P3 updated to forbid control vocabulary on `core.Theme`.
- New validator: `scripts/validate-core-theme-no-control-surface.mjs`
  enforces that no control-only type appears on `core`'s `pkg.generated.mbti`.

### Agent Notes

- **Session context**: MoUI core/views/host/renderer/platform architecture
  convergence task; sub-task 2 (Theme 分层).
- **Agent model**: AtomCode (GLM-5.2).
- **Key prompt or instruction**: "消除 `core.Theme` 对具体控件主题的泄漏…
  引入由 views 拥有的 `ControlThemeSet`… `core.Theme` 只保留 palette、
  typography、spacing、motion、environment 等中立主题基础。"
- **Validation**: `moon info moui/core` shows no control-only types;
  `moon test moui/core moui/views moui_theme --target native`;
  `sh scripts/check.sh --profile theme`; new validator green.

### References

- `docs/invariants.md` P3/P6
- `docs/plans/done/core-component-theme-to-views.md` (supersedes S1 default)
- `moui/core/theme.mbt`, `moui/core/theme_components.mbt`,
  `moui/core/theme_resolver.mbt`
- `moui/views/style/control_style.mbt`, `moui/views/style_api.mbt`,
  `moui/views/theme.mbt`

---

## 0018: Host contract split — runtime/render ownership leaves `backend/host`

- **Date**: 2026-07-28
- **Status**: Accepted
- **Deciders**: Agent-assisted (AtomCode GLM-5.2)
- **Related**: ADR 0005 (mobile host channel ownership), ADR 0006 (mobile GPU
  surface and render thread ownership), ADR 0011 (platform product class),
  invariants P4/P5/P6

### Context

`moui/backend/host` is currently a thick package. Its `moon.pkg` directly
imports `wzzc-dev/moui/runtime` and `wzzc-dev/moui/render`, and the package
contains implementation that is not host-contract work:

- `host_runtime_driver.mbt` — runtime orchestration / lifecycle driver
- `renderer.mbt` — renderer completion wiring
- `host_surface.mbt` + `image_repaint.mbt` — surface attach/detach, GPU
  recovery, image snapshot repaint tracking
- `wall_clock.mbt` + `redraw_scheduler.mbt` — frame/wall-clock scheduling
- async image loader, completion source, layer cache glue

This bundles three distinct ownerships into one package: (a) platform-neutral
**host contracts** (`HostEvent`, `HostCmd`, services facade,
`EmbedderHostChannel`, capability summary), (b) **runtime lifecycle
orchestration**, (c) **render completion / GPU recovery / image snapshot /
layer cache**. Invariants P4 (runtime lifecycle → `moui/runtime`) and P6
(renderer implementation → `moui/render/*`) are violated by the import edges
`host → runtime` and `host → render`.

Forces:

- Mobile sessions (`android`/`ios`/`harmonyos`) share `EmbedderHostChannel`;
  that contract must stay in `backend/host` and remain platform-neutral.
- Platform adapters translate native callbacks into `HostCmd`/`HostEvent`
  only (invariant M6); they must not need to import runtime or render impl.
- Native Skia mainline and Native WGPU diagnostic both render through host;
  the host surface glue is render-result plumbing, not host contract.

### Decision

Split `backend/host` into three ownerships.

1. **`backend/host` = platform-neutral host contracts only.** Keep
   `HostEvent`, `HostCmd`, `HostService` facade, `EmbedderHostChannel`,
   `HostPlatformChannel`, capability summary, text-input session contract,
   window lifecycle **contracts**, window request **contracts**. The package
   imports only `moui/core` (neutral value types) and `wzzc-dev/window/core`
   (window handle contract). **Remove** direct imports of `moui/runtime` and
   `moui/render`.
2. **`moui/runtime` owns `HostRuntimeDriver` and runtime orchestration.**
   `host_runtime_driver.mbt`, `wall_clock.mbt`, `redraw_scheduler.mbt`, and
   the runtime-side subscription source adapters move to `moui/runtime`
   (or a `moui/runtime/host_driver` sub-package). Runtime owns lifecycle,
   frame pacing, redraw scheduling, subscription routing.
3. **`moui/render/*` owns renderer completion, GPU recovery, image snapshot,
   layer cache.** `host_surface.mbt`'s render-completion half,
   `image_repaint.mbt`, `renderer.mbt` completion glue, async image loader
   completion, and layer-cache indexing move to `moui/render` (render
   surface contract) or the specific renderer provider package that owns the
   resource. Window event **translation** (native → `HostEvent`) stays in
   platform adapters or a dedicated adapter helper, not host.

Allowed `backend/host` import set after the split:

```text
wzzc-dev/moui/core
wzzc-dev/window/core        # window handle contract only
wzzc-dev/window/dpi          # scale normalization contract
Milky2018/moon_accesskit     # accessibility bridge contract (neutral)
moonbitlang/core/encoding/utf8
# for "test" only: wzzc-dev/moui/views
```

Forbidden after the split:

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/render` (any)
- concrete platform backends (`backend/<platform>`)
- concrete renderer providers (`moui_skia`, `render/skia`, `render/wgpu`, …)

### Options Considered

### Option A: three-way ownership split (chosen)

- Pros: each ownership lands in the package named for it; import edges match
  invariants P4/P5/P6; platform adapters import only host contracts; new
  renderers/runtimes do not require editing host.
- Cons: one-time migration of ~10 files; need a render-surface contract type
  to bridge host surface attach/detach → render completion without host
  importing render.

### Option B: keep host thick, document the leak as "necessary"

- Pros: zero migration.
- Cons: invariant P4/P6 stay violated; platform adapters keep transitive
  runtime/render deps; blocks the renderer provider model (ADR 0019) because
  host would need to know each renderer.

### Option C: split runtime out, leave render glue in host

- Pros: smaller migration; runtime ownership clarified.
- Cons: render completion/GPU recovery/image snapshot still leak host; host
  still imports `moui/render`; does not satisfy the invariant or the
  requested "renderer completion, GPU recovery, image snapshot, layer cache
  均位于职责匹配的包".

### Rationale

Option A is the only choice that makes the import graph match the
ownership cheat sheet in `docs/architecture-map.md`. The render-surface
bridge is a small neutral contract (`RenderSurfaceRequest` /
`RenderCompletion` value types) that can live in `moui/render` and be
referenced by runtime + providers without host owning it. Mobile
`EmbedderHostChannel` is unaffected — it is a host contract, not runtime
orchestration.

### Consequences

- `backend/host/moon.pkg` no longer imports `moui/runtime` or
  `moui/render`. `moon info moui/backend/host` surface shrinks.
- New `moui/runtime/host_driver` (or files in `moui/runtime`) owns
  `HostRuntimeDriver`, wall clock, redraw scheduler.
- New render-surface contract in `moui/render` owns completion, recovery,
  image snapshot, layer cache glue; providers implement the surface.
- Platform adapters import only `backend/host` (+ their renderer provider);
  no transitive runtime/render deps.
- Invariants P5 tightened to "host contracts only"; P4/P6 reinforced.
- New validator: `scripts/validate-host-import-baseline.mjs` enforces that
  `backend/host/moon.pkg` imports neither `moui/runtime` nor `moui/render`.

### Agent Notes

- **Session context**: MoUI core/views/host/renderer/platform architecture
  convergence task; sub-task 3 (host 拆分).
- **Agent model**: AtomCode (GLM-5.2).
- **Key prompt or instruction**: "收缩 `moui/backend/host` 为平台中立的
  host contracts…拆出 `HostRuntimeDriver` 与 runtime orchestration…目标
  依赖图中 `backend/host` 不再直接依赖 `moui/runtime`、`moui/render/*` 或
  window 实现包。"
- **Validation**: `moon info moui/backend/host` shows no runtime/render
  symbols; `moon test moui/backend/host moui/runtime moui/render --target
  native`; new validator green; daily profile green.

### References

- `docs/invariants.md` P4/P5/P6/M6
- `docs/architecture-map.md` ownership cheat sheet
- `moui/backend/host/host_runtime_driver.mbt`, `renderer.mbt`,
  `host_surface.mbt`, `image_repaint.mbt`, `wall_clock.mbt`,
  `redraw_scheduler.mbt`
- ADR 0005, ADR 0006, ADR 0011

