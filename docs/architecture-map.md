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
        ▼
moui/core                      # contracts & value types only
                               # (no control vocab, no runtime, no renderer)
        │
        ├───────────────────────────────────────────┐
        ▼                                           ▼
moui/runtime                    moui/backend/host   # host CONTRACTS only (ADR 0018):
trees, dispatch, effects,       HostEvent/HostCmd,  #   imports core + window/core + dpi + utf8;
HostRuntimeDriver,              services facade,    #   NO runtime/render in default imports;
RedrawScheduler,                EmbedderHostChannel,#   NO platform_bridge (no reverse dep)
HostWallClock,                  platform channel,
window_host_coordinator         capability summary,
        │                       text-input session   # no edges down (contracts only)
        ▼
backend/<platform>   ──►  platform_bridge   # neutral lifecycle transforms (ADR 0020):
(native decode,          close/focus/resize/scale/redraw, surface
capability decl,         attach/detach, logical coords, window slots)
HostSurfaceKit,          ──► normalized HostEvent/HostCmd (host contracts)
presenter + I/O)
        │ supplies neutral host surface capabilities
        ▼
moui/render                 # RendererProvider / RendererProviderBinding /
                            # capability model (ADR 0019); never imports host
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
`@moui.run_app`, supplies ordered `RendererBindingFactory` values with
`.render`/`.render_all`, supplies a platform `PlatformEntry` with `.backend`,
and calls `.run`. The backend creates a neutral `HostSurfaceKit` after its
window exists; renderer factories bind and negotiate against that kit. No
backend imports or constructs a concrete renderer. Renderer selection is
**provider negotiation** (`resolve_host_renderer`), never a central switch.
`RendererBackendKind` is diagnostic metadata only (ADR 0019, invariant P6).
Extension cost (2026-08-03 audit): `moui/core` has ~210 enum variants of
which ~2 are platform-related (~1%); adding a renderer costs one
`RendererBackendKind` diagnostic variant plus a provider package — no core
or host contract changes. New platform types extend via the open
`NativePlatformSurface` trait; renderer preference (`NativeRendererMode`)
stays a closed enum by design.

**Cross-layer edges (imports, beyond the tree above):**

- `moui/runtime` → `moui/backend/host` (`HostRuntimeDriver::dispatch` takes `@host.HostEvent`) and `moui/render` (`HostRuntimeDriver::apply_render_frame_result` takes `@render.RenderFrameResult`)
- `backend/<platform>` → `moui/runtime` (`PlatformEntry`, host driver), `moui/backend/host` (services), `platform_bridge` (transforms), and only the neutral `moui/render` host-surface contract
- `platform_bridge` imports `moui/backend/host` contracts; **host does not import `platform_bridge`** (no reverse dependency, Phase F gate)

**Domain facades (ADR 0003 / 0014):** `geometry`/`graphics`/`animation`/`text`/`state` re-export curated `@core` types only; `core` never imports them.

**Allowed direction:** app and views depend inward on facades/core; platform
backends normalize lifecycle facts through `backend/platform_bridge` into
host contracts and expose neutral surfaces; application entrypoints compose
renderer factories with platform entries;
renderers consume `DrawCommand` only.

**Forbidden (high frequency):**

| From | Must not depend on |
|---|---|
| `examples/*/app` | `moui/runtime`, `moui/render/*`, concrete backends, providers |
| `moui/core` | `views`, runtime, backends, renderers |
| `moui/backend/host` (default) | `moui/runtime`, `moui/render` (ADR 0018: contracts only) |
| `moui/backend/host` | `moui/backend/platform_bridge` (no reverse dependency, Phase F gate) |
| `moui/render` | `moui/backend/host` (renderers consume `DrawCommand` only) |
| view constructors | renderer fallback decisions, platform hosts |
| platform backends | mutating element/render trees directly |
| platform backends | duplicating lifecycle transforms (must go through `platform_bridge`) |
| platform backends | concrete renderer packages, renderer FFI/native libraries, decode logic, or provider construction |

## Ownership cheat sheet

| Area | Owner path |
|---|---|
| Public controls / themes helpers | `moui/views` |
| Cross-runtime protocols | `moui/core` |
| AppRuntime / trees / effects / HostRuntimeDriver / RedrawScheduler / HostWallClock | `moui/runtime` |
| Window host coordination (shared) | `moui/runtime/window_host_coordinator.mbt` |
| Host contracts only (HostEvent/HostCmd/services facade/EmbedderHostChannel/platform channel) | `moui/backend/host` |
| Neutral platform lifecycle bridge | `moui/backend/platform_bridge` |
| Shared embedded-runtime host shell | `moui/backend/internal/embedded_runtime_backend` |
| Native host backends (native decode + capability decl + neutral presenter/surface kit) | `moui/backend/{macos,windows,linux}` |
| Embedded runtime backends | `moui/backend/{android,ios,harmonyos}` |
| Web host backend | `moui/backend/web` |
| Host surface kit + renderer provider/factory contracts | `moui/render` (`host_surface_kit.mbt`, `provider_contract.mbt`) |
| Renderer implementations and factories | `moui/render/{skia,wgpu,sun,canvas2d,webgpu_adapter}` |
| Application/platform composition | `examples/*/<platform>/main.mbt` through `@moui.run_app` |
| Skia FFI / native capability | `moui_skia` |
| CPU raster stack (experimental) | `moui_sun` |
| Embedded-runtime templates and event loops | `wzzc-dev/window/{android,ios,harmonyos}` |
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
