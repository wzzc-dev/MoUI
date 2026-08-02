# Architecture Map

One-page map for agents and humans. Deep narrative: `docs/architecture.md`.
Constraints: `docs/invariants.md`. App imports: `docs/moui-app-package-boundary.md`.

## Runtime pipeline

```text
ViewDeclaration -> ElementTree
                       |-> LayoutTree -> RenderTree -> DrawCommand -> renderer
                       |-> SemanticsTree -> committed snapshot / Agent / accessibility
                       `-> PlatformTree -> platform-view host
```

## Package layers (dependency direction)

```text
examples/<app>/app          # platform-neutral product logic
        │
        ▼
wzzc-dev/moui  +  geometry/graphics/animation/text/state  +  views
        │
        ├──────────────►  moui/core          # contracts & value types only
        │
platform entrypoints        moui/runtime     # trees, dispatch, effects
(web_wasm, *_skia, …)              │
thin wiring only                   ▼
        │                   moui/backend/host   # HostEvent, services, EmbedderHostChannel
        │                          │
        └────────────►     backend/<platform>  (+ /skia, /wgpu providers)
                                   │
                                   ▼
                           moui/render/*  ──►  moui_skia / webgpu_adapter / wgpu
```

**Domain facades (ADR 0003 / 0014):** `geometry`/`graphics`/`animation`/`text`/`state` re-export curated `@core` types only; `core` never imports them.

**Allowed direction:** app and views depend inward on facades/core; platforms
normalize lifecycle facts through `backend/platform_bridge` into host contracts;
renderers consume `DrawCommand` only.

**Forbidden (high frequency):**

| From | Must not depend on |
|---|---|
| `examples/*/app` | `moui/runtime`, `moui/render/*`, concrete backends, providers |
| `moui/core` | `views`, runtime, backends, renderers |
| view constructors | renderer fallback decisions, platform hosts |
| platform backends | mutating element/render trees directly |

## Ownership cheat sheet

| Area | Owner path |
|---|---|
| Public controls / themes helpers | `moui/views` |
| Cross-runtime protocols | `moui/core` |
| AppRuntime / trees / effects | `moui/runtime` |
| Host services & embedder channel | `moui/backend/host` |
| Neutral platform lifecycle bridge | `moui/backend/platform_bridge` |
| Window host coordination (shared) | `moui/runtime/window_host_coordinator.mbt` |
| Shared embedded-runtime host shell | `moui/backend/internal/embedded_runtime_backend` |
| Native host backends | `moui/backend/{macos,windows,linux}` |
| Embedded runtime backends | `moui/backend/{android,ios,harmonyos}` |
| Web host backend | `moui/backend/web` |
| Skia mainline providers | `moui/backend/<platform>/skia` |
| WGPU diagnostic providers | `moui/backend/<platform>/wgpu` |
| Renderer facades and provider bindings | `moui/render`, `render/skia`, `render/wgpu`, `render/webgpu_adapter`, `render/sun`, `render/canvas2d` |
| Skia FFI / native capability | `moui_skia` |
| Embedded-runtime templates and event loops | `wzzc-dev/window/{android,ios,harmonyos}` |
| Rich text domain | `moui_richtext` |
| Design-system addons | `moui_theme` (not an app default dep) |
| Repo validators | `tools/moui/*` via `scripts/*.mjs` shells |

## Product classification (short)

| Track | Status |
|---|---|
| Native Skia | **Mainline** |
| Native WGPU | **Experimental** (engineering gate: `diagnostic` — runnable and testable, no product commitment) |
| Web `wasm-gc` + browser WebGPU imports | Main web path, with Canvas2D provider fallback |
| Embedded runtime backend route | `experimental` — code paths compile; no usability/product commitment without matching-device evidence |
| Product `auto` renderer | Prefer `SkiaGpuNative` when host GPU surface exists; `SkiaRasterNative` explicit/recovery |

## Workspace note

- Active members: `moon.work` (see generated `docs/repository-facts.md`).
- Do not list `./openseek` in `moon.work` by default.
- Local `./window/modules/window*` members: enable local source only when
  intentionally editing `window` (`sh scripts/window-dev-mode.sh on`).
  Outside that window, keep `./window` out of `moon.work`.
  `checks/window-dependency-exception.txt` gates committed local-window forms.

## Where to go next

| Need | Doc |
|---|---|
| Full package narrative | `docs/architecture.md` |
| Invariants table | `docs/invariants.md` |
| Validation commands | `docs/testing.md` |
| Embedded-runtime route | `docs/window-hosted-moui.md` |
| Doc catalog | `docs/INDEX.md` |
