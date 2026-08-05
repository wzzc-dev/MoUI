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
examples/<app>/app          # platform-neutral product logic, strict TEA
        │
        ▼
wzzc-dev/moui + geometry/graphics/animation/text/state + views + services
        │
        ▼
moui/core                      # contracts & value types only
                               # (no control vocab, no runtime, no renderer)
        │
        ├──────────────────────┬────────────────────────┐
        ▼                      ▼                        ▼
moui/runtime             moui/backend              moui/render
trees, effects,          neutral event/window/     surface/frame/image/provider
HostRuntimeDriver        input/service protocols   protocols and DTOs
        │                      │                        │
        └──────────┬───────────┘                        ▼
                   ▼                            moui/render/common
          moui/backend/common                  selection, fallback, mailbox,
          registry, lifecycle core,            GPU worker, image lifecycle,
          frame coordination, input state       shared drawing algorithms
                   │                                   │
          ┌────────┼────────┐                          │
          ▼        ▼        ▼                          │
       desktop  embedded  native                       │
          │        │        │                          │
          └────────┴────────┘                          │
                   │                                   │
                   ▼                                   │
          backend/<platform>                           │
          native decode, presenter, I/O                 │
                   │ supplies SurfaceContext            │
                   └──────────────────┬─────────────────┘
                                      ▼
                              renderer negotiation
                                      │
        │
        ├────────────┬────────────┬────────────┬──────────────┐
        ▼            ▼            ▼            ▼              ▼
render/skia   render/wgpu  render/sun  render/canvas2d  render/webgpu_adapter
        │            │            │            │              │
        ▼            ▼            ▼            ▼              ▼
   moui_skia      wgpu_mbt    moui_sun     browser         browser WebGPU
                (diagnostic) (experimental) canvas2d           host
```

Composition: an executable entrypoint builds an `AppBuilder` with
`@runtime.run_app`, supplies ordered `RendererFactory` values with
`.render`/`.render_all`, supplies a platform `PlatformEntry` with `.backend`,
and calls `.run`. The backend creates a neutral `SurfaceContext` after its
window exists; renderer factories bind and negotiate against that kit. No
backend imports or constructs a concrete renderer. Renderer selection is
**provider negotiation** (`@render_common.resolve_renderer`), never a central switch.
`RendererBackendKind` is diagnostic metadata only (ADR 0019, invariant P6).
Extension cost (2026-08-03 audit): `moui/core` has ~210 enum variants of
which ~2 are platform-related (~1%); adding a renderer costs one
`RendererBackendKind` diagnostic variant plus a provider package — no core
or host contract changes. New platform types extend via the open
`NativePlatformSurface` trait; renderer preference (`NativeRendererMode`)
stays a closed enum by design.

**Cross-layer edges (imports, beyond the tree above):**

- `moui/runtime` → `moui/backend` (`HostRuntimeDriver::dispatch` takes `@host.Event`) and `moui/render` (`HostRuntimeDriver::apply_render_frame_result` takes `@render.RenderFrameResult`)
- `moui/backend/common` → root `backend`, `core`, `services`, `runtime`, neutral `render`, and `render/common`; root `backend` never imports common
- `moui/render/common` → root `render` + `core`; root `render` never imports common
- `backend/<platform>` → root/common backend layers, runtime, services, neutral render layers, and its matching `wzzc-dev/window` package; never a concrete renderer

**Domain facades (ADR 0003 / 0014):** `geometry`/`graphics`/`animation`/`text`/`state` re-export curated `@core` types only; `core` never imports them.

**Allowed direction:** app and views depend inward on facades/core; platform
backends normalize lifecycle facts through `backend/common` into
host contracts and expose neutral surfaces; application entrypoints compose
renderer factories with platform entries;
renderers consume `DrawCommand` only.

**Forbidden (high frequency):**

| From | Must not depend on |
|---|---|
| `examples/*/app` | `moui/runtime`, `moui/backend/*`, `moui/render/*`, concrete backends, providers |
| `moui/core` | `views`, runtime, backends, renderers |
| `moui/backend` (root) | `moui/runtime`, `moui/render`, or `moui/backend/common` |
| `moui/backend` | `moui/backend/common` (no reverse dependency, Phase F gate) |
| `moui/render` | `moui/backend` (renderers consume `DrawCommand` only) |
| view constructors | renderer fallback decisions, platform hosts |
| platform backends | mutating element/render trees directly |
| platform backends | duplicating lifecycle transforms (must go through `backend/common`) |
| platform backends | concrete renderer packages, renderer FFI/native libraries, decode logic, or provider construction |

## Ownership cheat sheet

| Area | Owner path |
|---|---|
| Public controls / themes helpers | `moui/views` |
| App-facing files/clipboard/URL/settings/menu tasks and timer/route sources | `moui/services` |
| Cross-runtime protocols | `moui/core` |
| AppRuntime / trees / effects / HostRuntimeDriver / RedrawScheduler / HostWallClock | `moui/runtime` |
| Window host coordination (shared) | `moui/backend/common` (`WindowCoordinator`, `EmbeddedWindowCoordinator`, `FrameCoordinator`) |
| Backend protocols and DTOs (Event/HostCmd/HostServiceBridge/WindowRequests/platform channel) | `moui/backend` |
| Shared backend state (registry/queue/lifecycle/frame/input/service adapters) | `moui/backend/common` |
| Shared desktop host-service routing | `moui/backend/common/desktop` |
| Shared native filesystem handlers and raw image-byte source | `moui/backend/common/native` |
| Shared embedded callback service queue (`Pending(id)` + completion/cancel) | `moui/backend/common/embedded/services` |
| Neutral platform lifecycle bridge | `moui/backend/common` |
| Shared mobile session services (renderer, IME, semantics, platform-view, transport) | `moui/backend/common/embedded` |
| Physical Android/iOS/HarmonyOS callback dispatch | `wzzc-dev/window/internal/embedded_dispatch` |
| Native host backends (native decode + capability decl + neutral presenter/surface kit) | `moui/backend/{macos,windows,linux}` |
| Embedded runtime backends | `moui/backend/{android,ios,harmonyos}` |
| Web host backend | `moui/backend/web` |
| SurfaceContext + renderer provider/factory/image protocols | `moui/render` |
| Provider selection, fallback, workers, image lifecycle, shared drawing algorithms | `moui/render/common` |
| Renderer implementations and factories | `moui/render/{skia,wgpu,sun,canvas2d,webgpu_adapter}` |
| Application/platform composition | `examples/*/<platform>/main.mbt` through `@runtime.run_app` |
| Skia FFI / native capability | `moui_skia` |
| CPU raster stack (experimental) | `moui_sun` |
| Embedded-runtime templates, native payload adapters, and nominal event loops/windows | `wzzc-dev/window/{android,ios,harmonyos}` |
| Rich text domain | `moui_richtext` |
| Design-system addons | `moui_theme` (not an app default dep) |
| Repo validators | `tools/moui/*` via `scripts/*.mjs` shells |

## Product classification (short)

| Track | Status |
|---|---|
| Native Skia | **Mainline** |
| Native WGPU | **Experimental** (engineering gate: `diagnostic` — runnable and testable, no product commitment) |
| Sun CPU raster (`render/sun` + `moui_sun`) | **Experimental** (ADR 0023) — no product commitment, not on default composition roots, capability freeze by default |
| Web `wasm-gc` + browser WebGPU imports | Main web path, with Canvas2D provider fallback |
| Embedded runtime backend route | `experimental` — code paths compile; no usability/product commitment without matching-device evidence |
| Product `auto` renderer | Prefer `SkiaGpuNative` when host GPU surface exists; `SkiaRasterNative` explicit/recovery |

## Workspace note

- Active members: `moon.work` (see generated `docs/repository-facts.md`).
- Do not list `./openseek` in `moon.work` by default.
- Local `./window/modules/window*` members: enable local source only when
  intentionally editing `window` (`sh scripts/window-dev-mode.sh on`).
  Outside that window, keep `./window` out of `moon.work`.

## Where to go next

| Need | Doc |
|---|---|
| Full package narrative | `docs/architecture.md` |
| Invariants table | `docs/invariants.md` |
| Validation commands | `docs/testing.md` |
| Embedded-runtime route | `docs/window-hosted-moui.md` |
| Doc catalog | `docs/INDEX.md` |
