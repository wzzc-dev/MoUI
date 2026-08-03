# 架构地图

供代理和人工阅读的一页地图。深入叙述：`docs/architecture.md`。
约束：`docs/invariants.md`。应用导入：`docs/moui-app-package-boundary.md`。

## 运行时流水线

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

## 包层级（依赖方向）

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
        │                   moui/backend/host   # HostEvent, services, EmbedderHostChannel
        │                          │
        └────────────►     backend/<platform>  # neutral host only
                                   │
                                   ▼
                           moui/render/*  ──►  moui_skia / webgpu_adapter / wgpu
```

**领域门面（ADR 0003 / 0014）：** `geometry`/`graphics`/`animation`/`text`/`state` 只重新导出经过筛选的 `@core` 类型；`core` 永不导入它们。

**允许方向：** app 和 views 向内依赖 facades/core；平台归一化为 host contracts；renderers 只消费 `DrawCommand`。

**禁止项（高频）：**

| 来源 | 不得依赖 |
|---|---|
| `examples/*/app` | `moui/runtime`、`moui/render/*`、具体后端、providers |
| `moui/core` | `views`、runtime、backends、renderers |
| view constructors | renderer fallback decisions、platform hosts |
| platform backends | 直接修改 element/render trees |

## 所有权速查表

| 区域 | 归属路径 |
|---|---|
| 公共控件 / 主题 helpers | `moui/views` |
| 跨运行时协议 | `moui/core` |
| AppRuntime / trees / effects | `moui/runtime` |
| Host 服务与 embedder 通道 | `moui/backend/host` |
| 原生宿主后端 | `moui/backend/{macos,windows,linux}` |
| 嵌入运行时后端 | `moui/backend/{android,ios,harmonyos}` |
| 中立宿主 surface/presenter | `moui/backend/<platform>` |
| Renderer factory 与实现 | `moui/render/{skia,wgpu,sun,canvas2d,webgpu_adapter}` |
| 应用组合 | `@moui.run_app(...)` 后调用 `.render(...)` 或 `.render_all(...)`，再调用 `.backend(...).run()` |
| Skia FFI / native capability | `moui_skia` |
| 嵌入运行时模板与事件循环 | `wzzc-dev/window/{android,ios,harmonyos}` |
| 富文本领域 | `moui_richtext` |
| 设计系统 addons | `moui_theme`（不是 app 默认依赖） |
| 仓库 validators | `tools/moui/*`，由 `scripts/*.mjs` shells 调用 |

## 产品分类（简版）

| 轨道 | 状态 |
|---|---|
| Native Skia | **主线** |
| Native WGPU | **实验性**（工程门禁：`diagnostic` — 可运行、可测试，无产品承诺） |
| Web `wasm-gc` + browser WebGPU imports | Web 主路径 |
| 嵌入运行时后端路线 | `experimental` — 代码路径可编译；无匹配设备证据前不做可用性/产品承诺 |
| Product `auto` renderer | 宿主 GPU surface 存在时优先 `SkiaGpuNative`；`SkiaRasterNative` 用于显式选择/恢复 |

## 工作区说明

- 活跃成员：`moon.work`（见生成的 `docs/repository-facts.md`）。
- 默认不要在 `moon.work` 中列出本地 `./window/modules/window*` 成员或
  `./openseek`。
- 本地 window 源码：仅在有意编辑 window 时使用 `sh scripts/window-dev-mode.sh on/off`。

## 下一步去哪里

| 需求 | 文档 |
|---|---|
| 完整包叙述 | `docs/architecture.md` |
| 不变量表 | `docs/invariants.md` |
| 验证命令 | `docs/testing.md` |
| 嵌入运行时路线 | `docs/window-hosted-moui.md` |
| 文档目录 | `docs/INDEX.md` |
