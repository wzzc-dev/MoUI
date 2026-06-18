# MoUI

MoUI is a multi-platform MoonBit GUI framework for building
declarative UI apps with shared platform-neutral app logic. Native host cores
own windows, events, services, and lifecycle, then receive concrete renderers
through platform renderer provider packages.

The current mainline is native Skia raster plus the Web
`wasm-gc + window/web + browser WebGPU host imports` path. Native WGPU remains
available as an experimental diagnostic route while the MoonBit WGPU ecosystem
matures.

The runtime pipeline is explicit:

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

## Project Shape

- `moui/core/` owns platform-neutral contracts, opaque `View`, typed events,
  `Program`, `Effect`, `Subscription`, geometry, draw, semantics, and the
  private custom view protocol wrapped by `View[Msg]`.
- `moui/views/` owns public view constructors and concrete control behavior
  implemented with `@core.View::node`, without adding new `core` enum variants.
- `moui/runtime/` exposes app/host `AppRuntime` construction entrypoints and
  owns runtime state, tree/layout/paint, event dispatch, program message drain,
  effect task, subscription lifecycle, and diagnostics.
- `moui/views/` returns app-facing `@moui.View[Msg]` values for app code.
- `moui/backend/host/` defines shared host contracts; platform backends
  normalize window and input events into `HostEvent`.
- `moui/backend/<platform>/skia` selects the native Skia raster mainline
  provider; `moui/backend/<platform>/wgpu` keeps native WGPU diagnostics
  available.
- `moui/render/` provides the renderer facade, with native Skia raster, WebGPU
  adapter, and experimental native WGPU implementations under `render/skia/`,
  `render/webgpu_adapter/`, and `render/wgpu/`.
- `moui_theme/` is an optional addon workspace member for source-mapped
  Material, Carbon, Primer, and Fluent theme previews.
- `examples/*/app/` contains shared app logic, while platform subpackages are
  thin entrypoints.
- `website/` is the MoUI homepage and Web demo surface.

## Screenshots

<div align="center">
  <img src="resource/screenshots/markdown_editor.png" width="400px"/>
  <img src="resource/screenshots/showcase.png" width="400px"/>
</div>

## Quick Start

Refresh registry packages, verify repo-local dependencies, then run the bounded
development check:

```sh
moon update
sh scripts/check-local-deps.sh
sh scripts/dev-check.sh
```

The default daily baseline covers the core framework, maintenance baseline
ratchets, Web wasm-gc, native Skia mainline contracts, Showcase, and Markdown
Editor. Design Systems is addon diagnostic coverage; run
`sh scripts/dev-check.sh --theme-diagnostics` when changing `moui_theme` or
`examples/design_systems`.

For current-host backend/provider checks, run:

```sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/conformance-check.sh --platform-services
```

For release-oriented screenshot and benchmark handoffs, use:

```sh
sh scripts/conformance-check.sh --golden
sh scripts/conformance-check.sh --bench
```

These commands generate local scaffold manifests and logs under `artifacts/`;
release notes should cite the relevant CI run, uploaded artifact, or smoke log
instead of committing generated artifacts.

## Documentation

- [Architecture](website/web_wasm/docs/architecture.md)
- [Development](website/web_wasm/docs/development.md)
- [Testing](website/web_wasm/docs/testing.md)
- [API surface](website/web_wasm/docs/api-surface.md)
- [Maintenance mainline](website/web_wasm/docs/maintenance.md)
- [Platform notes](website/web_wasm/docs/platform-notes.md)
- [Renderer capability report](website/web_wasm/docs/renderer-capability-report.md)
- [View catalog](website/web_wasm/docs/view-catalog.md)
- [Views API guide](website/web_wasm/docs/views-api-guide.md)
- [Non-render component cookbook](website/web_wasm/docs/non-render-component-cookbook.md)
- [App templates](website/web_wasm/docs/app-templates.md)
- [Examples](website/web_wasm/docs/examples.md)
- [Markdown Editor](website/web_wasm/docs/markdown-editor.md)
- [Mo Workbench](website/web_wasm/docs/mo-workbench.md)
- [AI collaboration](website/web_wasm/docs/ai-collaboration.md)
- [2026 roadmap](website/web_wasm/docs/roadmap-2026.md)
- [Release readiness](website/web_wasm/docs/release-readiness.md)

## License

Apache-2.0. See [LICENSE](LICENSE).
