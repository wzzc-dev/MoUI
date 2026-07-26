# API 公开面

MoUI 仍是原型阶段，因此向后兼容还不是首要优先级。项目仍应保持一个可读的公开形态：应用代码应从根 `moui` app-loop 门面、领域门面和 `moui/views` 开始；运行时构造应通过 `moui/runtime`；host/renderer 包则为平台和渲染器集成暴露更窄的契约。

## 公开面层级

- **稳定应用 API**：`moui`（仅 app-loop 语法糖）、领域门面包
  (`moui/geometry`, `moui/graphics`, `moui/animation`, `moui/text`,
  `moui/state`) 以及日常使用的 `moui/views` constructors。这是普通应用包应最先学习的公开面。`moui/views` 暴露返回不透明 `@moui.View[Msg]` 值的 constructor helpers，以及面向应用的控件专属契约，例如 command/menu descriptors、control styles、theme builders 和 `SheetPresentationMode`。
- **高级 core API**：`moui/core`。它拥有 `View[Msg]`、`Program`、
  `Effect`、`Subscription`、layout、input、semantics、draw-command protocols、
  renderer-neutral platform-view contracts、公开 open `ViewNode` trait，以及把类型化 children 和消息 adapter 连接到无消息节点的 `View::from_node`。新控件不应新增 core enum variants、`@core.View::primitive_*_view` constructors、`ViewLoweringSink` 或 runtime lowering arms。共享应用应尽量减少默认 `moui/core` 导入；guard 会跟踪 shared-app core import budget。
- **运行时 API**：`moui/runtime`。运行时消费者应通过
  `@runtime.AppRuntime`、`@runtime.new_view`、`@runtime.new_program` 或
  `@runtime.new_program_with_dimensions` 构造 runtime。Runtime 拥有 program execution、element/layout/render state、effect/subscription lifecycle、inspector snapshots 和 diagnostics；`core` 不再暴露 `AppRuntime`、`RuntimeKernel` 或 `RuntimeState`。
- **集成 API**：`moui/backend/host`、`moui/render` 以及 renderer/provider 包。这些包面向 platform backends、renderers、examples 和 observation tooling 公开，但它们不是常规应用编写公开面。
- **诊断/插件 API**：诊断 renderer routes（例如 native WGPU）、`moui_theme/audit`、带源码映射的 theme previews、platform scaffolds，以及 opt-in smoke/evidence helpers。除非测试和文档明确将其提升，否则它们保持在 `core`、`views` 和 root facade 之外。

## 审查规则

添加导出声明前，先判断新符号应归属于哪个层级。优先把应用易用性留在 `views`，把运行时构造和 host runtime handles 留在 `runtime`，把中立契约留在 `core`，把 host routing 留在 `backend/host`，把具体 renderer 细节留在实现它们的 renderer 包。

公共 API 变化后运行 `moon info`，并审查生成的 `pkg.generated.mbti` diff。对于无 API 变化的工作，这些文件应保持不变。

当公开形态可能变化时，在 `moon info` 后运行 API surface guard：

```sh
node scripts/validate-api-surface.mjs
```

该 guard 用 MoonBit 实现在 `tools/moui/validate_api_surface/`。Node 脚本只是很薄的 build/run 入口。它会检查当前生成的 interface 文件：

- 关键包的行数和导出声明预算；
- 高风险包 `moui/core`、`moui/views`、`moui/runtime`、`moui/backend/host` 和
  `moui/render` 的语义分类预算，因此新的 public declarations 必须归类为
  `app_constructor`、`app_state_helper`、`app_style`、
  `advanced_core_protocol`、`runtime_diagnostic`、`host_contract`、
  `renderer_contract`、`required_protocol`、`test_exposure` 或
  `migration_debt`；
- root facade imports 以及 forbidden host/renderer/runtime tokens；
- geometry、graphics、animation、text 和 state/focus 包所需的领域门面 tokens，以及跨领域 forbidden aliases；
- `moui/views` 通过暴露 constructors、command/menu/theme helpers 和
  `DateValue` 保持面向应用，同时拒绝重新导出低层 drawing、animation、
  focus-scope、semantics、runtime-id 和 component-kernel；
- `moui/runtime` 存在性、不透明 `AppRuntime` 及有界 runtime methods、
  runtime source 不包装 `@core.AppRuntime` 或 `@core.RuntimeKernel`，以及 app/host source 对 `@runtime.AppRuntime` 的使用；
- 最终 core/runtime 边界 tokens：public `ViewNode` 与 `View::from_node` 必须出现在 core；`RuntimeKernel`、`RuntimeState`、`ViewSpec`、`ElementNode`、`ElementTree`、`ViewLoweringSink`、`View::node` 和 `@core.View::primitive_*_view` 不得出现在 core 生成的 public API 中；
- backend 生成接口暴露 `@runtime.AppRuntime` 而不是旧的 `@core.AppRuntime` 路径，并有一个零预算 guard 防止 shared app packages 默认导入 `moui/runtime`；
- shared app package 默认 `moui/core` 导入预算以及显式 advanced-app allowlist，确保新的普通应用保持在 `moui + views`；
- app、host、smoke 和 cross-package tests 使用 `moui/views` 进行 view construction 和 control-level helpers，而不是直接使用 `@moui.View::*` constructors；
- 所需的面向应用 re-exports，例如 `View`、`Program`、`State`、`Binding`、
  `Effect`、`Subscription`、`Theme`、graphics、animation 和 state/focus facade tokens，同时把 runtime bridges、diagnostic descriptors 和 draw command types 排除在 root facade 与 `@views` 之外；
- `moui/views` constructors 返回 `@moui.View[Msg]`；
- host/render/package boundary tokens 保持在其归属包内。

预算失败是审查提示，不是兼容性承诺。如果有意的 API 扩展值得保留，请更新数值和语义预算，并在同一变更中说明归属包理由。当前计数和后续候选项见 [API 公开面审计](../api-surface-audit.md)。
