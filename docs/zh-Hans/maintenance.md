# 维护主线

MoUI 保持窄而明确的默认维护基线，让框架可以持续增长，而不会把每条诊断路线都变成每日发布压力。

## 状态分类

- `mainline`：由默认的 `sh scripts/check.sh --profile daily` 路径覆盖。常规交接前，主线工作必须保持通过。
- `diagnostic`：可运行、可测试，并允许记录观察结果，但不是默认每日门禁。诊断路线发生变化时，运行对应的选择性标志或聚焦命令。
- `pending`：已有文档化脚手架或能力说明，但在对应 smoke 运行之前，不得描述为已就绪。

## 默认基线

默认每日基线覆盖：

- `moui/core` 和 `moui/views`
- `moui/backend/host` 和 `moui/backend/web`
- `moui/render`、`moui/render/skia` 和 `moui/render/webgpu_adapter`
- fallback 安全的 `moui_skia` 检查
- Showcase 应用/Web wasm-gc 验证
- Markdown Editor 应用/Web wasm-gc 验证
- 渲染器/provider 静态检查和轻量 Web handoff 验证
- 超大源码文件、源码级 `pub(all)` 数量以及根 facade 类型转发数量的维护基线 ratchet
- API surface 包预算，以及 `core`、`views`、`runtime`、`backend/host` 和 `render` 的语义分类预算

完整平台运行时 smoke 是发布门禁或匹配主机门禁，不是默认每日门禁。每日检查不要求新鲜的匹配主机 promotion。

## 工程基线 Ratchet

维护基线 ratchet 由 MoonBit 工具 `tools/moui/validate_maintenance_baseline` 实现。它扫描 `moui/`、`examples/` 和 `website/` 下 MoUI 拥有的 MoonBit 源码，排除生成的 `pkg.generated.mbti` 文件、vendor 的 `.mooncakes/` 树、构建输出和生成的 Unicode fixture 测试。默认 `sh scripts/check.sh --profile daily` 路径通过 `node scripts/validate-maintenance-baseline.mjs` 运行该 guard；拆分文件、收缩 `pub(all)` 或减少根 facade 转发时，直接运行该 wrapper，并在同一变更中下调相关预算。

该 guard 跟踪三类预算：

- 当前热点的超大文件 ratchet，例如 `moui/core/unicode/grapheme_data.mbt`、`moui/runtime/view_tree.mbt`、`moui/views/form/form_validation_test.mbt`、`moui/backend/host/host_test.mbt`、Skia 渲染器文本/测试，以及大型示例应用文件；
- core、views、host、render、主线示例、Mo Workbench、PDF Workbench 和 Website 的直接包源码 `pub(all)` 数量；
- `moui/moui.mbt` 中根 facade 的 `pub type` 转发数量。

API surface guard 独立于这条维护基线。它跟踪生成的公开 API 大小、禁止的边界 token，以及 `app_constructor`、`advanced_core_protocol`、`runtime_diagnostic`、`host_contract`、`renderer_contract` 等语义 API 分类预算。扩展公开 API 前，请参见 [API surface](../api-surface.md) 和 [API surface audit](../api-surface-audit.md)。

当前 `max` 值有意匹配今天的债务，因此无关变更不需要解决整个积压。当一次重构拆分文件、把 control 级入口点移动到 `views`、收缩公开 surface area 或移除根 facade 转发时，请在同一次提交中下调对应预算。

默认 wrapper 运行 `daily` scope。MoonBit 工具还支持 full-workspace 热点 scope：

```sh
moon run tools/moui/validate_maintenance_baseline --target native -- --scope full
```

`full` scope 保留每日预算，并额外扫描 addon/tool 工作区根，例如 `moui_richtext`、`moui_skia`、`moui_sun`、`moui_theme`、`moui_tester`、`moui_devtools`、`moui_webview`、`moui_agent*` 和 `tools`。已知大型文件拥有显式的 full-only 临时预算，这样广域验证可以报告热点，而不会强迫每个 2k-4k 行的诊断/测试文件进入每日基线或本次重构。请在聚焦后续变更中拆分这些文件，并在每次拆分落地时下调它们的 full-only 预算。

## 诊断路线

Native WGPU 是**实验性**渲染器诊断路线。它的工程门禁保持 `diagnostic`——可运行、可测试、允许记录观察，但**不是**默认每日门禁，也不携带**任何**产品承诺。它通过 `sh scripts/check.sh --profile full` 和聚焦的渲染器/provider 命令保持可用，但它不是 native 主线。

Design Systems 是 addon 诊断覆盖。`moui_theme` 和 `examples/design_systems` 仍然是重要的 source-mapped 预览/一致性 surface，但它们不是核心 MoUI 框架基线的一部分。修改 `moui_theme` 或 Design Systems 示例时，请运行 `sh scripts/check.sh --profile theme`。

慢速 native 示例构建和匹配主机平台运行时采集仍通过 `--profile full`、真实 Skia smoke helper 和直接运行时日志选择性运行。
