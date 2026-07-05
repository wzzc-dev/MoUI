# Showcase

<div align="center">
  <img src="../../resource/screenshots/showcase.png" width="600px" alt="Showcase screenshot"/>
</div>

Showcase is the MoUI visual component catalog. It exercises layout, input,
rendering, and platform smoke paths through a single shared app package
(`examples/showcase/app`) and is the broadest proof of the public `@views`
surface. It is run on every host entrypoint in CI to keep cross-platform
behavior aligned.

## Package Shape

- `app/` — shared app logic. `ShowcaseModel` is sectioned into focused panels
  (`layout_section.mbt`, `controls_section.mbt`, `forms_section.mbt`,
  `data_section.mbt`, `feedback_section.mbt`, `examples_section.mbt`,
  `interaction_lab_section.mbt`, `diagnostics_section.mbt`,
  `advanced_rendering_section.mbt`, `theme_renderer_section.mbt`,
  `text_media_section.mbt`, `navigation_section.mbt`, `overview_section.mbt`)
  plus a `navigation.mbt` shell, `formatting.mbt` helpers, `richtext_addon.mbt`
  integration with `@moui_richtext`, and per-theme rendering diagnostics.
- `web_wasm/`, `macos_skia/`, `macos_wgpu/`, `macos_wgpu_cosmic/`,
  `linux_skia/`, `linux_wgpu/`, `linux_wgpu_cosmic/`, `linux_sun/`,
  `windows_skia/`, `windows_wgpu/`, `windows_wgpu_cosmic/`, `windows_sun/`,
  `macos_sun/` — thin platform entrypoints.

`moui_skia` and `moui_sun` provide the native Skia and experimental Sun raster
providers picked per entrypoint. WGPU entrypoints are diagnostic-only and are
not the mainline.

## Dependencies

```toml
import {
  "wzzc-dev/moui@0.1.4",
  "wzzc-dev/moui_richtext@0.1.0",
}
```

## Running

```sh
# Web (wasm-gc)
moon build examples/showcase/web_wasm --target wasm-gc

# macOS Skia (mainline)
moon run examples/showcase/macos_skia --target native

# Windows Skia (run msvc_env.ps1 first in PowerShell)
.\scripts\windows\msvc_env.ps1
moon run examples/showcase/windows_skia --target native

# Linux Skia
moon run examples/showcase/linux_skia --target native
```

Diagnostic-only WGPU and Sun entrypoints exist on each host; the Skia raster
path is the mainline renderer for this example.

## Tests

```sh
moon test examples/showcase/app --target native
```

## Platform Coverage

| Target               | Entrypoint            | Status               |
| -------------------- | --------------------- | -------------------- |
| Web wasm-gc          | `web_wasm`            | Wired                |
| macOS Skia           | `macos_skia`          | Wired (mainline)     |
| macOS Sun            | `macos_sun`           | Diagnostic           |
| macOS WGPU           | `macos_wgpu`          | Diagnostic           |
| macOS WGPU Cosmic    | `macos_wgpu_cosmic`   | Diagnostic           |
| Windows Skia         | `windows_skia`        | Wired                |
| Windows Sun          | `windows_sun`         | Diagnostic           |
| Windows WGPU         | `windows_wgpu`        | Diagnostic           |
| Windows WGPU Cosmic  | `windows_wgpu_cosmic` | Diagnostic           |
| Linux Skia           | `linux_skia`          | Wired                |
| Linux Sun            | `linux_sun`           | Diagnostic           |
| Linux WGPU           | `linux_wgpu`          | Diagnostic           |
| Linux WGPU Cosmic    | `linux_wgpu_cosmic`   | Diagnostic           |

See [docs/examples.md](../../docs/examples.md) and
[docs/showcases.md](../../docs/showcases.md) for cross-cutting notes.
