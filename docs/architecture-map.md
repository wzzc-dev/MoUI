# Architecture Map

One-page map for agents and humans. Deep narrative: `docs/architecture.md`.
Constraints: `docs/invariants.md`. App imports: `docs/moui-app-package-boundary.md`.

## Runtime pipeline

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
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
        │                   moui/backend/host   # HostEvent, services, MobileHostChannel
        │                          │
        └────────────►     backend/<platform>  (+ /skia, /wgpu providers)
                                   │
                                   ▼
                           moui/render/*  ──►  moui_skia / webgpu_adapter / wgpu
```

**Allowed direction:** app and views depend inward on facades/core; platforms
normalize into host contracts; renderers consume `DrawCommand` only.

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
| Host services & mobile channel | `moui/backend/host` |
| Platform hosts | `moui/backend/{macos,windows,linux,web,android,ios,harmonyos}` |
| Skia mainline providers | `moui/backend/<platform>/skia` |
| WGPU diagnostic providers | `moui/backend/<platform>/wgpu` |
| Renderer facades | `moui/render`, `render/skia`, `render/webgpu_adapter`, `render/wgpu` |
| Skia FFI / native capability | `moui_skia` |
| Managed mobile shells | `moui/mobile/{android,ios,harmonyos}` |
| Legacy mobile fixtures | `moui/mobile/legacy/*`, example `*_app` when marked Release N |
| Rich text domain | `moui_richtext` |
| Design-system addons | `moui_theme` (not an app default dep) |
| Repo validators | `tools/moui/*` via `scripts/*.mjs` shells |

## Product classification (short)

| Track | Status |
|---|---|
| Native Skia | **Mainline** |
| Native WGPU | **Diagnostic** |
| Web `wasm-gc` + browser WebGPU imports | Main web path |
| Mobile embedded session | `runtime_partial` — usable managed shell, not product-complete |
| Product `auto` renderer | Prefer `SkiaGpuNative` when host GPU surface exists; `SkiaRasterNative` explicit/recovery |

## Workspace note

- Active members: `moon.work` (see generated `docs/repository-facts.md`).
- Do not list `./window` or `./openseek` in `moon.work`.
- Local window source: `sh scripts/window-dev-mode.sh on/off` only when intentionally editing window.

## Where to go next

| Need | Doc |
|---|---|
| Full package narrative | `docs/architecture.md` |
| Invariants table | `docs/invariants.md` |
| Validation commands | `docs/testing.md` |
| Mobile roadmap | `docs/mobile-mainline-roadmap.md` |
| Doc catalog | `docs/INDEX.md` |
