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
        ├───────────────┬───────────────┬───────────────┬───────────────┬───────────────┐
        ▼               ▼               ▼               ▼               ▼
moui_skia_renderer  moui_wgpu_renderer  moui_sun_renderer  moui_web_renderer  moui_tui_renderer
        │               │               │               │               │
        ▼               ▼               ▼               ├─ root:        ▼
   moui_skia        wgpu_mbt        moui_sun            │  WebGPU host  moui_tui
                    (diagnostic)    (experimental)      └─ canvas2d:    (experimental)
                                                        fallback        (ANSI bytes)
```

The direct-GPU route (`moui_metal_renderer`, ADR 0045) binds the same
`RendererProvider` contract to the host `CAMetalLayer` and links no second-party
graphics library; it is not drawn above because it adds no dependency edge — its
only non-`moui` imports are Apple frameworks.

Composition: an executable entrypoint builds an `AppBuilder` with
`@runtime.run_app`, supplies ordered `RendererProvider` values with
`.render`/`.render_all`, supplies a platform `PlatformEntry` with `.backend`,
and calls `.run`. The backend creates an opaque `HostSurface` after its
window exists; providers bind in registration order and the first
`Bound(RendererSession)` wins. No
backend imports or constructs a concrete renderer. Renderer selection is
**provider negotiation** (`@render_common.resolve_renderer`), never a central switch.
`RendererBackendKind` is diagnostic metadata only (ADR 0019, invariant P6).
The terminal route is the narrow exception to "renderers consume `DrawCommand`
only": `moui_tui_renderer` reads `DrawFrame.semantics` and writes ANSI bytes to
a host-supplied sink, so quantization, per-cell ownership and in-box wrapping
stay inside that package and `moui/core` / `moui/runtime` know nothing about
terminals. Pixel commands handed to it are not approximated; each one is
recorded as a degrade diagnostic.

**Non-windowed output paths** is the category name for hosts that run a MoUI
program on a surface that is neither a window nor a pixel device. Two members
exist today: the terminal path (`moui_terminal_host` + `moui_tui_renderer`,
whose output is an ANSI byte stream through a composition-root sink) and the
agent path (`moui_agent`, a `HostRuntimeDriver` pump with no present target at
all). Both share the shape — drive the runtime through `HostRuntimeDriver`,
declare the output composition explicitly, and stay outside the canonical
platform matrix, which describes windowed hosts. A future headless snapshot
or semantic-dump renderer belongs to this category, not to the platform
matrix: classifying it here is what keeps the 14-route governance contract
intact (the Linux RISC-V64 and ADR 0021 precedents vary or extend routes, this
category is orthogonal to them). The category changes nothing else: renderer
selection stays provider negotiation, and release-closure rules are unchanged.
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
| Renderer implementations, providers, and platform policies | `moui_{skia,wgpu,metal,sun,web,tui}_renderer` (`moui_web_renderer/canvas2d` for Canvas2D) |
| Renderer-neutral native text providers and their shared payload protocol | `moui_text_providers` (`coretext`, `directwrite`, `fontconfig`, `cosmic_text`, `text_protocol`) |
| Cell buffer underneath the ANSI path (damage/revision, CJK double width) | `moui_tui` |
| TTY raw mode, SGR mouse modes, input decode, cell→logical geometry, explicit `tui-ansi` composition | `moui_terminal_host` (experimental) |
| Application/platform composition | `examples/*/<platform>/main.mbt` through `@runtime.run_app` |
| Skia FFI / native capability | `moui_skia` |
| CPU raster stack (experimental) | `moui_sun` |
| Embedded-runtime templates, native payload adapters, and nominal event loops/windows | `wzzc-dev/window/{android,ios,harmonyos}` |
| Rich text domain (engine) | `moui_richtext` |
| Markdown chrome addon (find/replace, outline, format palette, document info, HTML export) | `moui_markdown` (not an app default dep) |
| Design-system addons | `moui_theme` (not an app default dep) |
| Repo validators | `tools/moui/*` via `scripts/*.mjs` shells |

## Product classification (short)

| Track | Status |
|---|---|
| Native Skia | **Mainline** |
| Native WGPU | **Experimental** (engineering gate: `diagnostic` — runnable and testable, no product commitment) |
| Native direct GPU (`moui_metal_renderer`) | **Experimental** (ADR 0045) — the no-Skia, no-wgpu route. All 26 `DrawCommand` variants carry a draw arm (a new variant is a compile error here, not a silent gap): rects, rounded rects and strokes, gradient brushes, shadows, tessellated paths, glyph runs through the injected platform text engine, decoded images with the async request/completion lifecycle, and layer, filter, retained-layer and shader-effect scopes. Text fidelity, Overlay blending, Gaussian-quality blur and retained-layer caching stay `Partial` in the capability report. No product commitment, not on default composition roots |
| Sun CPU raster (`moui_sun_renderer` + `moui_sun`) | **Experimental** (ADR 0023) — no product commitment, not on default composition roots, capability freeze by default |
| Terminal cell ANSI (`moui_tui_renderer` + `moui_tui` + `moui_terminal_host`) | **Experimental** (`ready=false`) — no pixel claim; semantics-only projection, non-projectable controls degrade to named placeholders; interaction proof is the PTY smoke gate, not a host-window route |
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
