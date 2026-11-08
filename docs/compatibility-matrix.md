# Compatibility Matrix

> Release line: `0.5.x`. Source: `checks/release-modules.json`,
> `checks/portfolio-governance.json`, and the module manifests. This matrix is
> a documentation aid; the machine gate is
> `node scripts/validate-release-module-closures.mjs` with exact workspace pins.

## Base

| Module | Intent | Base pin | Stage |
|---|---|---|---|
| `wzzc-dev/moui` | product | self | base-bindings |

`moui/apphost` is a package inside the base module, not a separate release
module.

## Bindings

| Module | Intent | Base pin | Stage |
|---|---|---|---|
| `wzzc-dev/moui_skia` | product | `wzzc-dev/moui@0.5.1` | base-bindings |
| `wzzc-dev/moui_sun` | lab | `wzzc-dev/moui@0.5.1` | base-bindings |
| `wzzc-dev/moui_tui` | lab | `wzzc-dev/moui@0.5.1` | base-bindings |
| `wzzc-dev/moui_text_providers` | product | `wzzc-dev/moui@0.5.1` | base-bindings |

## Renderers

| Module | Intent | Base pin | Stage |
|---|---|---|---|
| `wzzc-dev/moui_skia_renderer` | product | `wzzc-dev/moui@0.5.1` | renderers |
| `wzzc-dev/moui_web_renderer` | product | `wzzc-dev/moui@0.5.1` | renderers |
| `wzzc-dev/moui_wgpu_renderer` | diagnostic | `wzzc-dev/moui@0.5.1` | renderers |
| `wzzc-dev/moui_metal_renderer` | diagnostic | `wzzc-dev/moui@0.5.1` | renderers |
| `wzzc-dev/moui_sun_renderer` | lab | `wzzc-dev/moui@0.5.1` | renderers |
| `wzzc-dev/moui_tui_renderer` | lab | `wzzc-dev/moui@0.5.1` | renderers |

## Addons

| Module | Intent | Base pin | Stage |
|---|---|---|---|
| `wzzc-dev/moui_agent` | lab | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_terminal_host` | lab | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_devtools` | product | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_i18n` | product | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_richtext` | product | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_markdown` | product | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_theme` | product | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_webview` | product | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_3d` | lab | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_3d_physics` | lab | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_3d_physics_rapier` | lab | `wzzc-dev/moui@0.5.1` | addons |
| `wzzc-dev/moui_3d_xr` | lab | `wzzc-dev/moui@0.5.1` | addons |

## Entrypoints

| Module | Intent | Base pin | Stage |
|---|---|---|---|
| `wzzc-dev/moui_agent_mcp` | product | `wzzc-dev/moui@0.5.1` | entrypoints |
| `wzzc-dev/moui_cli` | product | `wzzc-dev/moui@0.5.1` | entrypoints |

## Policy

- A base-only patch path is not offered.
- A module keeps its version unless its own contract changes or the
  coordinated release requires a new artifact.
- Lab/diagnostic modules are not product commitments. Their inclusion here
  means the closure compiles and passes its own gates, not that the route is
  product-ready.
