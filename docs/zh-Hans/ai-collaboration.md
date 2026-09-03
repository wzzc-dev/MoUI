# AI 协作

当变更保持小而可审查，并且与框架架构一致时，AI 辅助会让 MoUI 受益。本指南记录项目特定的 agent 和维护者工作流。

## 目标

- 保留公开 `View[Msg]` / runtime tree 管线。
- 保持包边界清晰，并让平台无关代码远离平台 host。
- 相比大范围 churn，优先采用聚焦编辑、聚焦测试和显式验证。
- 通过生成的 interface diff 让公开 API 变更可见。
- 保持渲染器能力状态在代码、测试、文档和 Showcase 之间同步。
- 保持 `AGENTS.md` 与 repo-local skills 跟随快速变化的文档、验证命令、包布局、示例以及文本/渲染边界同步。

## 项目不变量

- 公开 view 构造器返回不透明 `@moui.View[Msg]`；内置具体行为在 `moui/views` 中实现 `@core.ViewNode`，并通过 `@core.View::from_node` 构造。
- runtime 管线保持为：

  ```text
  View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
  ```

- `core/` 拥有平台无关 contract、不透明 view、event、geometry、draw/semantics/text/theme contract，以及由类型化 `View[Msg]` adapter 包裹的公开、与消息无关的 `ViewNode` 扩展协议；`moui/runtime` 拥有 `AppRuntime`、runtime state、tree/layout/paint、event dispatch、program message drain、effect task、subscription 和 runtime diagnostics。
- `views/` 拥有公开构造 helper 和具体 custom view 行为，复用 binding、style 和 modifier，但不暴露 runtime internals。
- `backend/` 拥有 `Event`、surface metrics、input contract、file drag/drop normalization、text-input session state 和 redraw driver behavior。
- 平台包把 native event 转换为 `Event`；它们不直接修改 element tree。
- 渲染器消费 `DrawCommand` 值，并且不依赖 view 构造器。
- `examples/*/app/` 包包含共享应用逻辑；平台子包保持轻薄。
- Linux 具有 Wayland host core 和 WGPU provider 路径；请保持剩余匹配主机 runtime evidence 与 native font-provider gap 显式可见。

## 推荐 Agent 工作流

1. 将 `AGENTS.md` 作为**地图**阅读（只看任务路由和硬边界摘要）。
2. 打开 `docs/INDEX.md`，然后只打开任务所需的已链接 canonical 页面。在确有需要前，优先阅读 `docs/architecture-map.md`，而不是完整架构叙述。常驻约束：`docs/invariants.md`。验证：`docs/testing.md`。
3. 对多包或平台工作，在大编码循环前添加或更新 `docs/plans/active/<id>.md`。
4. 通过阅读相关 `moon.pkg` 定位包边界。
5. 名称不清楚时，使用 `moon ide doc`、`moon ide outline`、`moon ide peek-def` 或 `moon ide find-references` 发现 MoonBit API。
6. 在包本地编辑，并保留 `///|` 顶层分隔符。
7. 在被触碰的包中添加或更新聚焦测试。
8. 先运行最小有用的验证命令（见 AGENTS 任务路由）。
9. 交接前运行 `moon fmt`。
10. 公开 API 变更后运行 `moon info`，并审查生成的 `pkg.generated.mbti` diff。
11. 当命令、平台行为、公开 API、渲染器能力或示例变化时更新文档。不要把 invariant 表复制进 skill；链接 `docs/invariants.md`。品味规则：`docs/golden-principles.md`。
12. 当 guidance 会变陈旧时，检查 `AGENTS.md` 和 `skills/`。如果不需要编辑，请说明已检查并保持不变。

## Prompt 模板

### 添加 View 构造器

```text
Add a MoUI view constructor for <control>. Keep it in views/, return @moui.View[Msg],
implement reusable behavior in views/ as a concrete @core.ViewNode and construct it with @core.View::from_node, reuse existing styles/modifiers where possible, add focused tests in
the moui/views tests (tests/smoke), update docs/view-catalog.md if public coverage changes, and
run moon test moui/views --target native plus moon info if the public API changes.
```

### 修改渲染器能力

```text
Improve renderer support for <feature>. Keep DrawCommand as the renderer boundary,
update render/capabilities.mbt, render/capabilities_test.mbt, docs/renderer-capability-report.md,
and Showcase if visible. Validate with renderer package tests and a Showcase Web wasm-gc build.
```

### 修改后端事件处理

```text
Change backend handling for <event>. Keep platform-specific code in backend/<platform>,
normalize through backend Event, add focused backend tests, and validate with
moon test moui/backend --target native plus the affected backend package test.
```

### 更新示例

```text
Update the <example> example. Keep shared logic in examples/<example>/app and platform
entrypoints thin. Add app-package tests for behavior, build the Web wasm-gc entrypoint
if browser behavior changes, and update docs/examples.md if commands or coverage change.
```

### 更新文档

```text
Update MoUI docs for <topic>. Keep the root README.md as the short entrypoint, put
detailed commands in docs/development.md, platform caveats in docs/platform-notes.md,
example behavior in docs/examples.md, text architecture in docs/text-system.md,
Markdown Editor behavior in docs/markdown-editor.md, and validation policy in
docs/testing.md. Also check AGENTS.md and skills/ when the guidance surface changes.
```

## 审查清单

- 变更是否保留了 runtime 管线？
- 包边界是否被尊重？
- 公开 API surface 是否有意变更？
- 是否添加或更新了聚焦测试？
- 是否运行了 `moon fmt`？
- 对公开 API 变更是否运行了 `moon info`？
- 是否为用户可见行为、命令或平台约束更新了文档？
- 当文档位置、验证、包布局、示例、平台行为、渲染器状态或文本架构发生变化时，是否检查了 `AGENTS.md` 和 repo-local skills？
- 如果渲染器行为改变，能力代码、测试、报告和 Showcase 是否同步？
- 如果后端行为改变，event 是否仍然流经 `Event`？
- 如果示例改变，共享应用逻辑是否仍在 `examples/*/app/` 下？

## 决策与会话记录

MoUI 为 AI-agent 辅助开发维护三层记录系统。

### 第 1 层：记忆速记（`memories/repo/`）

每个会话中 agent 会自动加载的短项目事实。
用途：关键模式、常见陷阱、已验证约定。
每个文件保持在 20 行以内。

### 第 2 层：架构决策记录（`docs/decisions/`）

用于重要技术决策的正式结构化记录。
在以下情况创建 ADR：

- 在两个或更多架构方案之间做选择。
- 修改公开 API contract 或包边界。
- 引入新依赖或外部协议。
- 修改渲染器、后端或 runtime 管线行为。
- 会影响 agent 在此 repo 中工作方式的决策。

使用 `docs/decisions/TEMPLATE.md` 模板。
按顺序编号（`0001-`、`0002-`、...），并更新 `docs/decisions/README.md` 中的索引。

### 第 3 层：AI 会话日志（`docs/ai-sessions/`）

记录重要的多文件或触及架构边界的会话摘要。
在以下情况记录会话：

- 触及架构边界的多文件变更。
- 会话产出了 ADR。
- 发生了重要调试或发现。
- 建立了新模式或反模式。

使用 `docs/ai-sessions/TEMPLATE.md` 模板。
文件命名为 `YYYY-MM-DD-short-description.md`。

### 工作流集成

一次重要 agent 会话之后：

1. 用新的速查事实更新 `memories/repo/`。
2. 如果做出了正式决策，在 `docs/decisions/` 中创建 ADR。
3. 如果会话复杂或具有教学价值，将其记录到 `docs/ai-sessions/`。
4. 在提交消息或 PR 描述中引用 ADR/会话日志。

## 反模式

- 把平台窗口或渲染器逻辑放进 `core/`。
- 从公开构造器返回 legacy view 类型。
- 让后端包直接修改 runtime element tree 或 render tree。
- 在 view 构造器内重复渲染器 fallback 决策。
- 更新渲染器行为却不更新能力报告和测试。
- 对小包编辑一开始就运行广泛 native 检查。
- 除非明确要求，否则为已移除 API 创建兼容 shim。
- 把 `AGENTS.md` 扩写成百科全书，而不是路由到 `docs/`。
- 在 skill 或会话笔记中重述完整 invariant 表（请改为链接）。
- 只把关键规则留在聊天或会话 prose 中，而不提升到 `memories/repo/`、ADR、plan 或 validator。
