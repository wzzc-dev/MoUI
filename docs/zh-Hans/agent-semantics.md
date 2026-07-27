# 已提交语义与 Agent 操作

MoUI 从 runtime 已提交的语义状态中提供自动化与无障碍能力。Agent 代码不以
屏幕坐标或 `ElementId` 为目标，读取语义也不会触发绘制。

## Runtime 管线

```text
ViewDeclaration
  -> reconcile
  -> LayoutTree / RenderTree / SemanticsTree / PlatformTree
  -> committed SemanticsSnapshot + generation + indices
  -> typed SemanticsAction
  -> TEA Msg
  -> next atomic commit
```

`ViewNode::declaration` 独立声明 `layout`、`paint`、`semantics` 和
`platform` 通道。每个通道都是 `Constant`、精确的 canonical
`DeclarationKey` 或 `Uncacheable`；只有 layout 变化会隐式使另外三个通道失效。
未实现 `declaration` 的节点会保守地把四个通道全部默认为 `Uncacheable`；精确
declaration 是可选的缓存证明，而不是正确性的前置条件。`View::from_node` 只采样
一次 identity、declaration、语义 metadata、action handler 和静态 children。
`View::map` 保留这些快照，只映射 typed message。

runtime 仅在 rebuild、layout、dirty semantics 重算、索引替换和 delta 构造全部
完成后发布不可变 `SemanticsSnapshot`。只有公开 snapshot 实际变化时 generation
才会递增。仅 paint 的工作和重复读取不会推进 generation。runtime 保留最近 64 次
已提交 delta，因此 `read_semantics(since=...)` 返回 `Full`、`Delta` 或
`Unchanged`；过期 cursor 会通过 `Full` 恢复。

## 身份与组合

`SemanticId` 是可选、由应用拥有的稳定地址。它精确区分大小写，长度为 1 到
255 个 UTF-8 byte，并拒绝空白和控制字符。`counter.increment` 这样的点分名称
只是约定，不是 namespace。重复 ID 仍会作为 snapshot issue 暴露，但通过歧义
ID 发起的所有操作都会被拒绝且不派发消息。

`SemanticsNodeId` 在单个 runtime session 内单调分配，并且在 element 生命周期
结束后不复用。Web、原生无障碍和 mobile host 使用它作为传输身份。
`SemanticsGeneration` 和 node ID 在 wire 边界使用十进制字符串，避免 JavaScript
丢失 `UInt64` 精度。`ElementId` 只存在于 runtime 内部。

View 通过 `Transparent`、`Boundary`、`MergeDescendants` 或 `Hidden` 显式组合
语义。semantics modifier 覆盖有效 logical boundary。它不会把第一个 child 的
role、label、value、state 或 actions 复制到无关 wrapper，`semantic_id` 也不会
继承到 ancestor 或 sibling。

## 操作事务

能力使用 `SemanticsActionKind`，调用使用携带 payload 的 `SemanticsAction`，
包括 `SetText(String)` 和 `Scroll(SemanticsScrollDirection)`。runtime 从 typed
handler 自动推导公开能力。Focus 由 runtime 管理；其他 action 直接返回临时状态
失效和 typed message，不伪造 pointer 或 keyboard event。

每次操作都必须携带 `Exact(generation)` 或显式 `Latest`。runtime 先提交待处理
语义，再依次检查 generation、target 唯一性、enabled 状态、capability 和
handler。拒绝路径不投递消息，也不修改 runtime focus 或临时状态。handler callback
只能生成 proposal：构造 proposal 时不得直接修改 mutable UI handle，而应把修改
作为 deferred commit 返回。成功操作会应用 runtime-local state 和 deferred UI
state commit，将 message 按 FIFO 入队，完成同步 TEA drain，再次提交 semantics。
receipt 包含 `before`、`after` 和 `pending_work`；generation 相等是合法结果，也不
表示异步 effect 已完成。

## Agent 与 MCP 边界

`AgentHost` 只拥有 `read_semantics` 和 `perform_action`。`RuntimeAgentHost` 永久
绑定到一个 `AppRuntime`；runtime 销毁后，两项操作都返回 `host_closed`。坐标
event、全局 command、runtime counter 和 paint summary 属于独立的
`AgentDiagnosticsHost` 契约。

默认 MCP router 只暴露：

- `read_semantics`
- `perform_action`

diagnostics router 是显式启用的 profile。工具参数错误和业务拒绝都返回普通 MCP
tool result，包含 `structuredContent`、text fallback、`isError`，以及稳定的
`{ "ok": true, "value": ... }` 或 `{ "ok": false, "error": ... }` envelope。
JSON-RPC error 仅用于 malformed JSON-RPC 或 `tools/call` envelope。

稳定寻址不等于授权。应用仍需在 UI 和 TEA `update` 中实现确认流程与高风险业务
规则。
