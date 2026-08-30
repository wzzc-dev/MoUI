<div align="center">
  <img src="resource/branding/moonbud-mascot.svg" width="100" alt="MoUI Logo" />
  <h1>MoUI</h1>
  <p>Multi-platform MoonBit declarative GUI framework — build declarative UI apps with shared platform-neutral logic</p>
  <p>
    <a href="./README.zh-CN.md">简体中文</a> | English
  </p>
  <p>
    <a href="./LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue.svg" alt="license: Apache-2.0" /></a>
    <a href="https://github.com/wzzc-dev/MoUI"><img src="https://img.shields.io/github/stars/wzzc-dev/MoUI?style=social" alt="GitHub Stars" /></a>
  </p>
  <p>
    <a href="https://gitcode.com/wzzc/MoUI"><img src="https://gitcode.com/wzzc/MoUI/star/new_badge.svg" alt="G-Star Selected by AtomGit" height="32" /></a>
  </p>
  <p>
    <a href="#quick-start">Quick Start</a> ·
    <a href="#project-shape">Project Shape</a> ·
    <a href="#running-examples">Running Examples</a> ·
    <a href="#documentation">Documentation</a> ·
    <a href="#contributing">Contributing</a>
  </p>
</div>

---

MoUI is a multi-platform MoonBit GUI framework for building declarative UI apps with shared platform-neutral app logic. Native host cores own windows, events, services, and lifecycle, then receive concrete renderers through platform renderer provider packages.

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

The current mainline is native Skia raster plus the Web `wasm-gc + window/web + browser WebGPU host imports` path. Native WGPU remains available as an experimental diagnostic route while the MoonBit WGPU ecosystem matures.

### Supported platforms (product class)

| Platform | Class | Meaning |
| --- | --- | --- |
| macOS | **committed** | Product mainline (L0–L3 evidence) |
| Web | **committed** | Product mainline (wasm-gc + WebGPU) |
| Windows | **committed** | Product mainline (L0–L3 evidence) |
| Linux | **committed_with_gaps** | Product L0–L2; interactive L3 still partial |
| Android | **experimental** | Window-hosted path compiles; no usability/product commitment yet |
| iOS | **experimental** | Same as Android |
| HarmonyOS | **experimental** | Same; signed-device full smoke still open |

Mobile is **not** "unwired glue only," and it is **not** product-committed. It is **experimental**: code compiles and host-sim tests pass, but no development/demonstration usability or product commitment is made without matching-device evidence. See [platform readiness declaration](docs/platform-readiness-declaration.md).

The runtime pipeline is explicit:

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

## Project Shape

- `moui/core/` owns platform-neutral contracts, opaque `View`, typed events, `Program`, `Effect`, `Subscription`, geometry, draw, semantics, and the public message-independent `ViewNode` extension protocol wrapped by typed `View[Msg]`.
- `moui/views/` owns public view constructors and concrete control behavior implemented as `@core.ViewNode` values and constructed with `@core.View::from_node`, without adding new `core` enum variants.
- `moui/runtime/` exposes app/host `AppRuntime` construction entrypoints and owns runtime state, tree/layout/paint, event dispatch, program message drain, effect task, subscription lifecycle, and diagnostics.
- `moui/views/` returns app-facing `@moui.View[Msg]` values for app code.
- `moui/backend/` defines shared host contracts; platform backends normalize window and input events into `Event`.
- `moui/backend/<platform>/` owns only the neutral host; applications select `moui_skia_renderer` or another renderer provider in the composition root.
- `moui/render/` provides the renderer facade, with native Skia raster, WebGPU adapter, and experimental native WGPU implementations under `moui_skia_renderer/`, `moui_web_renderer/`, and `moui_wgpu_renderer/`.
- `moui_theme/` is an optional addon workspace member for source-mapped Material, Carbon, Primer, and Fluent theme previews plus the first-party Smartisan-inspired Sickle hybrid skeuomorphic/flat theme.
- `examples/*/app/` contains shared app logic, while platform subpackages are thin entrypoints.
- `website/` is the MoUI homepage and Web demo surface.

## Screenshots

<div align="center">

  <img src="resource/screenshots/showcase.png" width="48%" alt="Showcase"/>
  <img src="resource/screenshots/markdown_editor.png" width="48%" alt="Markdown Editor"/>

  <br/><br/>

  <img src="resource/screenshots/mo_workbench.png" width="48%" alt="Mo Workbench"/>
  <img src="resource/screenshots/excel.png" width="48%" alt="Excel"/>

  <br/><br/>

  <img src="resource/screenshots/webview.png" width="70%" alt="WebView Demo"/>
  <img src="resource/screenshots/ios-componentgallery.png" width="25%" alt="iOS Component Gallery"/>

  <br/><br/>

  <img src="resource/screenshots/harmonyos-componentgallery.png" width="45%" alt="HarmonyOS Component Gallery"/>
  <img src="resource/screenshots/android-componentgallery.jpg" width="48%" alt="Android Component Gallery"/>

</div>

## Quick Start

Choose the path that matches what you are trying to do.

### Playground

Open the [browser Playground](https://wzzc-dev.github.io/MoUI/playground/) to edit and run the guided examples without installing a native toolchain. This is the shortest route for learning the view/update model and checking Web behavior.

### Independent Project

Install the standalone CLI, then generate a project outside this repository:

```sh
moon install wzzc-dev/moui_cli/cmd/moui
moui new my_app
# Optional smaller skeleton: moui new my_app --template hello
cd my_app
moon update
moon check
moon run macos_skia --target native   # or windows_skia / linux_skia on that host
```

`moui new` creates shared app logic plus Web and the current desktop entrypoint. Add Android, iOS, or HarmonyOS explicitly with `--platform`; mobile projects use `wzzc-dev/window` templates and keep lifecycle, surface, and input in the platform event loop. See [Getting started](docs/getting-started.md).

### This Repository

Use this path when changing MoUI itself or running the full featured examples:

```sh
git clone --recurse-submodules https://github.com/wzzc-dev/MoUI.git
cd MoUI
sh scripts/ci-moon-update.sh
sh scripts/check.sh --profile pr
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
```

Showcase and Markdown Editor are the primary scanning and interaction examples. Their platform entrypoints are listed under [Running Examples](#running-examples).

Framework setup details, including optional submodules and the `window/` local-source workflow, live in [Development](docs/development.md).

The default daily baseline covers the core framework, maintenance baseline ratchets, Web wasm-gc, native Skia mainline contracts, Showcase, and Markdown Editor. Design Systems is addon diagnostic coverage; run `sh scripts/check.sh --profile theme` when changing `moui_theme` or `examples/design_systems`.

For current-host backend/provider checks, run:

```sh
sh scripts/check.sh --profile platform
```

For release-oriented screenshot and benchmark handoffs, use:

```sh
node scripts/conformance-capture-scaffold.mjs --mode golden
node scripts/conformance-capture-scaffold.mjs --mode benchmark
```

These commands generate local scaffold manifests and logs under `artifacts/`; release notes should cite the relevant CI run, uploaded artifact, or smoke log instead of committing generated artifacts. `artifacts/` is ignored; keep those files as local or CI evidence.

## Running Examples

The featured examples — `showcase`, `markdown_editor`, `mo_workbench`, and `excel` — share app logic in `examples/<name>/app` and expose thin platform entrypoints. Showcase uses `web_wasm`, desktop renderer-specific entrypoints, and `android_window_hosted`, `ios_window_hosted`, and `harmonyos_window_hosted` mobile entrypoints.

To try Showcase on a mobile platform, follow the platform-specific setup, build, and run instructions for [Android](docs/android-support.md), [iOS](docs/ios-support.md), or [HarmonyOS](docs/harmonyos-support.md). Standard examples use the matching `wzzc-dev/window` platform template through `moui build`.

> **Windows prerequisite:** before building or running any Windows native entrypoint (`windows_skia`, or the `windows_wgpu` diagnostic route), initialize the MSVC toolchain in a PowerShell session:
>
> ```powershell
> .\scripts\windows\msvc_env.ps1
> ```
>
> This sets up the MSVC environment required by the native Skia link step and provides the C11 atomics flags (`/experimental:c11atomics /std:c11`) that `wgpu_mbt`'s C stubs require. Run it once per shell before `moon run ... --target native` on Windows.

### Showcase

Unified Components, Patterns, Platform, and Diagnostics workspaces across desktop, mobile, and Web. Source lives under `examples/showcase/app`; platform entrypoints are thin.

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

### Markdown Editor

Typora-style WYSIWYG Markdown editor. Source lives in `examples/markdown_editor/app`; the retained macOS/Web entrypoints are thin.

```sh
# Web (wasm-gc)
moon build examples/markdown_editor/web_wasm --target wasm-gc

# macOS Skia
moon run examples/markdown_editor/macos_skia --target native
```

### Mo Workbench

Native-Skia-first desktop agent dogfood app. Only `macos_skia` is wired today; Linux/Windows/Web entrypoints are reserved. The `bobzhang/openseek` dependency resolves from mooncakes.io (pinned in `examples/mo_workbench/moon.mod`); no submodule or workspace member override is required.

```sh
moon run examples/mo_workbench/macos_skia --target native
```

### Excel Viewer

MoonBit Excel (`bobzhang/mbtexcel`) file renderer using MoUI data table components. Shared app logic is in `examples/excel/app`; `macos_skia` is the retained entrypoint.

```sh
# macOS Skia
moon run examples/excel/macos_skia --target native
```

Focused app-package tests for the featured examples:

```sh
moon test examples/markdown_editor/app --target native
moon test examples/mo_workbench/app --target native
moon test examples/showcase/app --target native
moon test examples/excel/app --target native
```

See [Showcase](examples/showcase/README.mbt.md), [Examples](docs/examples.md), [Markdown Editor](docs/markdown-editor.md), [Mo Workbench](docs/mo-workbench.md), and [Showcases](docs/showcases.md) for package shapes and platform coverage.

## Documentation

The source docs live under `docs/`. The website preview copies those Markdown files into `website/web_wasm/docs/` with `node scripts/sync-website-docs.mjs`.

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

MoUI is maintained by a single maintainer with AI assistance and is open to external contributions. Pull requests are the primary entry point for changes.

- [Contributing guide](CONTRIBUTING.md) — setup, package boundaries, PR requirements, DCO
- [Governance](GOVERNANCE.md) — decision mechanism, RFC process, maintainer roles, project handover
- [Security policy](SECURITY.md) — vulnerability reporting and support scope
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

Apache-2.0. See [LICENSE](LICENSE).

Third-party dependency and attribution notes are collected in [THIRD_PARTY.md](THIRD_PARTY.md).
