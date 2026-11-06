# 兼容矩阵

> 发布线：`0.4.x`。事实源：`checks/release-modules.json`、
> `checks/portfolio-governance.json` 与各模块 manifest。本矩阵是文档辅助；
> 机器门禁是 `node scripts/validate-release-module-closures.mjs` 与精确
> workspace pin。

## 基础

| 模块 | Intent | 基础 pin | 阶段 |
|---|---|---|---|
| `wzzc-dev/moui` | product | 自身 | base-bindings |

`moui/apphost` 是基础模块内的包，不是独立发布模块。

## 绑定

| 模块 | Intent | 基础 pin | 阶段 |
|---|---|---|---|
| `wzzc-dev/moui_skia` | product | `wzzc-dev/moui@0.4.0` | base-bindings |
| `wzzc-dev/moui_sun` | lab | `wzzc-dev/moui@0.4.0` | base-bindings |
| `wzzc-dev/moui_tui` | lab | `wzzc-dev/moui@0.4.0` | base-bindings |
| `wzzc-dev/moui_text_providers` | product | `wzzc-dev/moui@0.4.0` | base-bindings |

## 渲染器

| 模块 | Intent | 基础 pin | 阶段 |
|---|---|---|---|
| `wzzc-dev/moui_skia_renderer` | product | `wzzc-dev/moui@0.4.0` | renderers |
| `wzzc-dev/moui_web_renderer` | product | `wzzc-dev/moui@0.4.0` | renderers |
| `wzzc-dev/moui_wgpu_renderer` | diagnostic | `wzzc-dev/moui@0.4.0` | renderers |
| `wzzc-dev/moui_metal_renderer` | diagnostic | `wzzc-dev/moui@0.4.0` | renderers |
| `wzzc-dev/moui_sun_renderer` | lab | `wzzc-dev/moui@0.4.0` | renderers |
| `wzzc-dev/moui_tui_renderer` | lab | `wzzc-dev/moui@0.4.0` | renderers |

## 插件

| 模块 | Intent | 基础 pin | 阶段 |
|---|---|---|---|
| `wzzc-dev/moui_agent` | lab | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_terminal_host` | lab | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_devtools` | product | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_i18n` | product | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_richtext` | product | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_markdown` | product | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_theme` | product | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_webview` | product | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_3d` | lab | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_3d_physics` | lab | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_3d_physics_rapier` | lab | `wzzc-dev/moui@0.4.0` | addons |
| `wzzc-dev/moui_3d_xr` | lab | `wzzc-dev/moui@0.4.0` | addons |

## 入口

| 模块 | Intent | 基础 pin | 阶段 |
|---|---|---|---|
| `wzzc-dev/moui_agent_mcp` | product | `wzzc-dev/moui@0.4.0` | entrypoints |
| `wzzc-dev/moui_cli` | product | `wzzc-dev/moui@0.4.0` | entrypoints |

## 策略

- 不提供 base-only patch 路径。
- 模块只有自身契约变化或协同发布需要新产物时才升版本。
- lab/diagnostic 模块不是产品承诺；列入这里只表示闭包可编译并通过自身门禁。
