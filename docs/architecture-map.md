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
          moui/backend/common                  provider selection, fallback,
          stateless host workflows             mailbox/GPU worker,
                   │                            shared drawing algorithms
       ┌───────────┼───────────┬───────────┐           │
       ▼           ▼           ▼           ▼           │
   lifecycle     frame       image       input          │
       │           │           │           │           │
       └───────────┼───────────┴─────┬─────┘           │
                   ▼                 ▼                 │
               services          embedded             │
             /    │    \       session assembly        │
       desktop embedded native                          │
                   │                                   │
                   ▼                                   │
          backend/<platform>                           │
          native decode, presenter, I/O                 │
                   │ supplies opaque HostSurface         │
                   └──────────────────┬─────────────────┘
                                      ▼
                         ordered provider binding
                                      │
        │
        ├────────────────┬────────────────┬────────────────┬────────────────┐
        ▼                ▼                ▼                ▼
moui_skia_renderer  moui_wgpu_renderer  moui_sun_renderer  moui_web_renderer
        │                │                │                │
        ▼                ▼                ▼                ├─ root: WebGPU host
   moui_skia          wgpu_mbt         moui_sun            `─ canvas2d: fallback
                    (diagnostic)     (experimental)
```

Composition: an executable entrypoint builds an `AppBuilder` with
`@runtime.run_app`, supplies ordered `RendererProvider` values with
`.render`/`.render_all`, supplies a platform `PlatformEntry` with `.backend`,
and calls `.run`. The backend creates an opaque `HostSurface` after its
window exists; providers bind in registration order and the first
`Bound(RendererSession)` wins. No
backend imports or constructs a concrete renderer. Renderer selection is
**provider negotiation** (`@render_common.resolve_renderer`), never a central switch.
`RendererBackendKind` is diagnostic metadata only (ADR 0019, invariant P6).
Extension cost (2026-08-03 audit): `moui/core` has ~210 enum variants of
which ~2 are platform-related (~1%); adding a renderer costs one
`RendererBackendKind` diagnostic variant plus a provider package — no core
or host contract changes. Root render exposes only opaque native surface and
display handles; renderer-local policies such as Skia's
`NativeGpuPlatform`/`SkiaSurfaceRoute` interpret them. Renderer preference
(`NativeRendererMode`) stays a renderer-local closed enum by design.

**Cross-layer edges (imports, beyond the tree above):**

- `moui/runtime` → `moui/backend` (`HostRuntimeDriver::dispatch` takes `@host.Event`) and `moui/render` (`HostRuntimeDriver::apply_render_frame_result` takes `@render.RenderFrameResult`)
- `moui/backend/common` → root `backend`, `core`, `services`, `runtime`, neutral `render`, and `render/common`; root `backend` never imports common
- `moui/render/common` → root `render` + `core`; root `render` never imports common
- `backend/<platform>` → root/common backend layers, runtime, services, neutral render layers, and its matching `wzzc-dev/window` package; never a concrete renderer

**Domain facades (ADR 0003 / 0014):** `geometry`/`graphics`/`animation`/`text`/`state` re-export curated `@core` types only; `core` never imports them.

**Allowed direction:** app and views depend inward on facades/core; platform
backends normalize lifecycle facts through `backend/common` into
host contracts and expose neutral surfaces; application entrypoints compose
renderer providers with platform entries;
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
| Backend protocols and DTOs (Event/HostCmd/HostServiceBridge/WindowRequests/platform channel) | `moui/backend` |
| Stateless cross-owner window-host workflows and DTO conversion | `moui/backend/common` |
| Registry, request queue, runtime slots, platform ID map, phase/generation, exactly-once close | `moui/backend/common/lifecycle` |
| Per-window renderer session, redraw, resize, present completion, IME frame hook | `moui/backend/common/frame` |
| Image loading, repaint revision, completion, callback detach, cancellation | `moui/backend/common/image` |
| Input conversion and pointer/text/IME session state | `moui/backend/common/input` |
| Service facade, async completion, and bridge lifetime | `moui/backend/common/services` |
| Desktop/embedded/native service implementations | `moui/backend/common/services/{desktop,embedded,native}` |
| Native filesystem image-byte source | `moui/backend/common/image/native` |
| Shared mobile session assembly (transport, renderer attach, IME, semantics, platform views) | `moui/backend/common/embedded` |
| Physical Android/iOS/HarmonyOS callback dispatch | `wzzc-dev/window/internal/embedded_dispatch` |
| Native host backends (native decode + capability decl + neutral presenter/surface kit) | `moui/backend/{macos,windows,linux}` |
| Embedded runtime backends | `moui/backend/{android,ios,harmonyos}` |
| Web host backend | `moui/backend/web` |
| Opaque HostSurface/NativeSurface + RendererProvider/RendererSession/image protocols | `moui/render` |
| Provider selection, fallback, workers, image lifecycle, shared drawing algorithms | `moui/render/common` |
| Renderer implementations, providers, and platform policies | `moui_{skia,wgpu,sun,web}_renderer` (`moui_web_renderer/canvas2d` for Canvas2D) |
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
| Sun CPU raster (`moui_sun_renderer` + `moui_sun`) | **Experimental** (ADR 0023) — no product commitment, not on default composition roots, capability freeze by default |
| Web `wasm-gc` + browser WebGPU imports | Main web path, with Canvas2D provider fallback |
| Embedded runtime backend route | `experimental` — code paths compile; no usability/product commitment without matching-device evidence |
| Product `auto` renderer | Prefer `SkiaGpuNative` when host GPU surface exists; `SkiaRasterNative` explicit/recovery |

## Workspace note

- Active members: `moon.work` (see generated `docs/repository-facts.md`).
- Do not list `./openseek` in `moon.work` by default.
- Local `./window/modules/window*` members: enable local source only when
  intentionally editing `window` (`sh scripts/window-dev-mode.sh on`).
  Outside that window, keep `./window` out of `moon.work`.

## Release module closures

`wzzc-dev/moui` publishes only the neutral framework, runtime, platform
backends, renderer protocols, and shared renderer algorithms. Concrete
renderers are independent `wzzc-dev/moui_*_renderer` modules; dedicated
integration tests and renderer smokes live in unpublished
`moui_tests/`. Composition-root modules declare both the base module
and their selected renderer module.

`checks/release-modules.json` is the release directory/stage catalog. The
required `node scripts/validate-release-module-closures.mjs` gate checks module
names, dependency direction, workspace pins, base closure exclusions, and the
unpublished `moui_tests/` boundary. Release stage order is base and bindings,
then renderers, addons/agent, and finally agent MCP and CLI. Stage order
does not require equal module versions after the 0.2 migration release.

## Where to go next

| Need | Doc |
|---|---|
| Full package narrative | `docs/architecture.md` |
| Invariants table | `docs/invariants.md` |
| Validation commands | `docs/testing.md` |
| Embedded-runtime route | `docs/window-hosted-moui.md` |
| Doc catalog | `docs/INDEX.md` |
