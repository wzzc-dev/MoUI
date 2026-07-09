# MoUI

MoUI is a multi-platform MoonBit GUI framework for building
declarative UI apps with shared platform-neutral app logic. Native host cores
own windows, events, services, and lifecycle, then receive concrete renderers
through platform renderer provider packages.

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

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
  Material, Carbon, Primer, and Fluent theme previews plus the first-party
  Smartisan-inspired Sickle hybrid skeuomorphic/flat theme.
- `examples/*/app/` contains shared app logic, while platform subpackages are
  thin entrypoints.
- `website/` is the MoUI homepage and Web demo surface.

## Screenshots

<div align="center">
  <img src="resource/screenshots/markdown_editor.png" width="400px"/>
  <img src="resource/screenshots/showcase.png" width="400px"/>
  <img src="resource/screenshots/mo_workbench.png" width="400px"/>
  <img src="resource/screenshots/excel.png" width="400px"/>
  <img src="resource/screenshots/webview.png" width="600px"/>
  <img src="resource/screenshots/ios-componentgallery.png" width="200px"/>
</div>

## Quick Start

The fastest way to try MoUI is the standalone `moui_example` counter app, a
small repo that pins a published MoUI crate and renders the same Model /
Msg / update / view loop on both macOS Skia and Web wasm-gc.

```sh
cd moui_example
moon update
```

`moui_example` is an independent sub-repo on `wzzc-dev/moui@0.1.5-1`; it is not
listed in this repository's `moon.work` and is not built by the repository
daily check. It is the recommended starting template for new apps.

When cloning this repository for framework or example development, include
submodules (required for the `wzzc-dev/window` fork):

```sh
git clone --recurse-submodules git@github.com:wzzc-dev/MoUI.git
cd MoUI
```

If you already cloned without submodules, initialize them once:

```sh
git submodule update --init --recursive
```

The default daily baseline covers the core framework, maintenance baseline
ratchets, Web wasm-gc, native Skia mainline contracts, Showcase, and Markdown
Editor. Design Systems is addon diagnostic coverage; run
`sh scripts/check.sh --profile theme` when changing `moui_theme` or
`examples/design_systems`.

For current-host backend/provider checks, run:

```sh
sh scripts/check.sh --profile platform
```

For release-oriented screenshot and benchmark handoffs, use:

```sh
node scripts/conformance-capture-scaffold.mjs --mode golden
node scripts/conformance-capture-scaffold.mjs --mode benchmark
```

These commands generate local scaffold manifests and logs under `artifacts/`;
release notes should cite the relevant CI run, uploaded artifact, or smoke log
instead of committing generated artifacts.
`artifacts/` is ignored; keep those files as local or CI evidence.

## Running Examples

The featured examples — `markdown_editor`, `mo_workbench`, `showcase`, and
`excel` — share app logic in `examples/<name>/app` and expose thin platform
entrypoints under `web_wasm`, `macos_skia`, `windows_skia`, and `linux_skia`.
Run the matching entrypoint for your host; `mo_workbench` currently ships a
macOS Skia entrypoint only; `excel` ships `macos_skia` and `linux_skia`.

> **Windows prerequisite:** before building or running any `windows_skia`
> entrypoint, initialize the MSVC toolchain in a PowerShell session:
>
> ```powershell
> .\scripts\windows\msvc_env.ps1
> ```
>
> This sets up the MSVC environment required by the native Skia link step.
> Run it once per shell before `moon run ... --target native` on Windows.

### Markdown Editor

Typora-style WYSIWYG Markdown editor. Source lives in
`examples/markdown_editor/app`; platform entrypoints are thin.

```sh
# Web (wasm-gc)
moon build examples/markdown_editor/web_wasm --target wasm-gc

# macOS Skia
moon run examples/markdown_editor/macos_skia --target native

# Windows Skia (run msvc_env.ps1 first in PowerShell)
.\scripts\windows\msvc_env.ps1
moon run examples/markdown_editor/windows_skia --target native

# Linux Skia
moon run examples/markdown_editor/linux_skia --target native
```

### Mo Workbench

Native-Skia-first desktop agent dogfood app. Only `macos_skia` is wired today;
Linux/Windows/Web entrypoints are reserved. The `bobzhang/openseek` dependency
resolves from mooncakes.io (pinned in `examples/mo_workbench/moon.mod`); no
submodule or workspace member override is required.

```sh
moon run examples/mo_workbench/macos_skia --target native
```

### Showcase

Full MoUI view catalog and reusable example index. Shared app logic is in
`examples/showcase/app`.

```sh
# Web (wasm-gc)
moon build examples/showcase/web_wasm --target wasm-gc

# macOS Skia
moon run examples/showcase/macos_skia --target native

# Windows Skia (run msvc_env.ps1 first in PowerShell)
.\scripts\windows\msvc_env.ps1
moon run examples/showcase/windows_skia --target native

# Linux Skia
moon run examples/showcase/linux_skia --target native
```

### Excel Viewer

MoonBit Excel (`bobzhang/mbtexcel`) file renderer using MoUI data table
components. Shared app logic is in `examples/excel/app`; `macos_skia` and
`linux_skia` entrypoints are wired today.

```sh
# macOS Skia
moon run examples/excel/macos_skia --target native

# Linux Skia
moon run examples/excel/linux_skia --target native
```

Focused app-package tests for the featured examples:

```sh
moon test examples/markdown_editor/app --target native
moon test examples/mo_workbench/app --target native
moon test examples/showcase/app --target native
moon test examples/excel/app --target native
```

See [Examples](docs/examples.md), [Markdown Editor](docs/markdown-editor.md),
[Mo Workbench](docs/mo-workbench.md), and [Showcases](docs/showcases.md) for
package shapes and platform coverage.

## Documentation

The source docs live under `docs/`. The website preview copies those Markdown
files into `website/web_wasm/docs/` with `node scripts/sync-website-docs.mjs`.

- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Testing](docs/testing.md)
- [API surface](docs/api-surface.md)
- [API surface audit](docs/api-surface-audit.md)
- [Maintenance mainline](docs/maintenance.md)
- [Platform notes](docs/platform-notes.md)
- [Renderer capability report](docs/renderer-capability-report.md)
- [View catalog](docs/view-catalog.md)
- [Views API guide](docs/views-api-guide.md)
- [Non-render component cookbook](docs/non-render-component-cookbook.md)
- [App templates](docs/app-templates.md)
- [Examples](docs/examples.md)
- [Markdown Editor](docs/markdown-editor.md)
- [Mo Workbench](docs/mo-workbench.md)
- [AI collaboration](docs/ai-collaboration.md)
- [2026 roadmap](docs/roadmap-2026.md)
- [Release readiness](docs/release-readiness.md)

## Contributing

MoUI is maintained by a single maintainer with AI assistance and is open to
external contributions. Pull requests are the primary entry point for changes.

- [Contributing guide](CONTRIBUTING.md) — setup, package boundaries, PR requirements, DCO
- [Governance](GOVERNANCE.md) — decision mechanism, RFC process, maintainer roles, project handover
- [Security policy](SECURITY.md) — vulnerability reporting and support scope
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

Apache-2.0. See [LICENSE](LICENSE).

Third-party dependency and attribution notes are collected in
[THIRD_PARTY.md](THIRD_PARTY.md).
