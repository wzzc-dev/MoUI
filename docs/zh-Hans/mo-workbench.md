# Mo 工作台

Mo 工作台是一个以 macOS Skia 原生优先的多工作区桌面 Agent 外壳，镜像 DeepSeek-GUI 的工作台/入口模型。该外壳承载响应式工作区栏、中心工作表面、顶部栏控件、可选右侧检查器和低噪声状态栏。Code 是目前唯一可交互的 Agent 工作区；Write、Connect Phone、Scheduled Tasks 和 Plugins 渲染产品形态的静态表面，让信息架构可见，同时不声称尚未接线的后端行为。

## 包形态

- `examples/mo_workbench/app` 拥有共享 TEA 外壳模型、各工作区子模型、更新路由和视图组合。它是可移植的（native + wasm-gc），且不依赖任何仅原生可用的 LLM SDK。后端以 `AgentBackendRuntime` 闭包边界注入，因此应用包可以在无网络环境下测试。其公共表面刻意保持狭窄：`program_with_backend`、`AgentBackendRuntime`、`AgentBackendFixture`、`AgentCommand`、`AgentEvent`、`ModelChoice`、`ThinkingChoice`、`TurnStatus`、`SessionSummary`、`WorkbenchModel`、`WorkbenchMsg` 和 `MoWorkbenchApp`。
- `examples/mo_workbench/openseek_native_transport` 是仅原生包，把 `AgentCommand` / `AgentEvent` 桥接到进程内 OpenSeek agent。
- `examples/mo_workbench/acp_native_transport` 是仅原生的通用 ACP stdio 传输。它启动 ACP 兼容 Agent 子进程，通过 stdin/stdout 传输 JSON-RPC 换行消息，把 `session/update` 和 `session/request_permission` 映射为 `AgentEvent`，并在 v1 中保持客户端文件系统和终端能力关闭。
- `examples/mo_workbench/macos_skia` 在 `settings.json` 选择 `"agent_backend": "acp"` 且 `acp_command` 非空时注入 `acp_native_transport`。否则，在配置了 API key 时使用 `openseek_native_transport`，并在无配置时回退到 `AgentBackendRuntime::stub()`。

## 工作区架构

外壳（`WorkbenchModel`）持有活动工作区枚举、每个工作区一个子模型、共享界面框架状态（外观），以及注入的后端运行时。工作区范围消息会包装为 `WorkbenchMsg` 上的 `CodeMsg(...)` / `SettingsMsg(...)` / `WriteMsg(...)` 变体；外壳把每个包装消息路由到匹配的子更新，并通过 `Effect::map` 把子 effect 提升回 `Effect[WorkbenchMsg]`。子视图在外壳视图分派器中通过 `View::map` 提升为 `View[WorkbenchMsg]`。

### 工作区

- **Code**（`CodeWorkspace`）：以会话为先的编码 Agent 聊天表面（会话、消息、提示词、steering/cancel、OpenSeek 模型/思考控件、ACP 模式/配置控件、流式状态）。拥有 `AgentBackendRuntime` 分派和 `AgentEvent` 投影。这是 Codex 风格聊天表面所在的位置。
- **Write**（`WriteWorkspace`）：静态 Markdown 写作外壳，包含文档和助手面板。它目前不保存文件、不请求补全，也不调用导出服务。
- **Settings**（`SettingsWorkspace`）：Agent 运行时加界面框架设置表单（后端选择 / provider 设置 / ACP 命令和参数 / approval policy / sandbox mode / 工作目录 / 字号）。provider/model 持久化已为原生 OpenSeek 原型接线。ACP 命令设置由 macOS Skia 入口点消费。
- **ConnectPhone / ScheduledTasks / Plugins**（保留）：面向未来 IM/webhook 自动化、定时提示和 Skills/MCP 管理的产品形态静态外壳。它们通过 `SwitchWorkspace(...)` 路由，但目前还没有子模型或子更新。

### 消息路由

`WorkbenchMsg` 变体：

- `SwitchWorkspace(Workspace)` — 在外壳层处理；更新 `active_workspace`。工作区状态在切换时保留（每个子模型都位于外壳上）。
- `CodeMsg(CodeMsg)` — 委托给 `CodeWorkspace::update(msg, backend)`；返回的 `Effect[CodeMsg]` 通过 `Effect::map(m => CodeMsg(m))` 提升。
- `SettingsMsg(SettingsMsg)` — 委托给 `SettingsWorkspace::update(msg)`；返回的 `Effect[SettingsMsg]` 通过 `Effect::map(m => SettingsMsg(m))` 提升。
- `WriteMsg(WriteMsg)` — 目前为 no-op（`WriteWorkspace` 为保留工作区）。
- `ToggleAppearance` — 在外壳层处理；按 `System → Light → Dark → System` 循环。

`CodeMsg` 包含 `ReceiveAgentEvent(AgentEvent)`，因此代码工作区端到端拥有自身后端分派和事件投影（外壳不需要了解 Agent 事件）。

启动时，共享应用分派 `FetchSessionList`。当返回的会话列表非空且尚无活动会话时，Code 会自动选择第一个会话并分派 `SwitchSession`，使工作台恢复已有对话，而不是停留在空白状态。

## 后端边界

应用包通过 `AgentBackendRuntime` 闭包保持与 LLM 无关：

```
UI side  -> Effect::run callback (sync) -> runtime.run(commands, emit)
backend  -> async worker -> emit(event) -> dispatch(map(event)) into UI queue
```

- `AgentCommand`：`SendTask`、`Steer`、`NewSession`、`SwitchSession`、`SetModel`、`SetThinking`、`CancelTurn`、`SetSessionMode`、`SetSessionConfigOption`、`RespondPermission`、`FetchSessionList`、`Shutdown`。
- `AgentEvent`：`UserMessageAdded`、`AssistantMessageAdded`、`ToolResultAdded`、`RuntimeNoticeAdded`、`TurnTerminal`、`ProgressNotice`、流式 message/thought chunk、ACP 模式/配置更新、权限请求、会话信息更新、`SessionRebuilt`、`SessionListed`、`ActiveSessionChanged`。

`AgentBackendFixture` 是用于可移植测试的脚本化后端：它记录已分派命令，并按命令重放调用方提供的事件序列。

后端注入只影响 `CodeWorkspace::update`；Settings/Write 在该原型中不会分派后端 effect。

## UI 布局

外壳视图遵循 DeepSeek-GUI 宏观语法：

- **左侧工作区栏**：宽桌面为 268px，1120px 以下为 236px，760px 以下为 188px。它包含 Code、Write、Connect Phone、Scheduled Tasks 和 Plugins 的图标+标签工作区按钮；Settings 和 Appearance 位于页脚。主体随活动工作区变化：Code 显示工作区策略和会话历史，Write 显示写作空间，Connect Phone 显示通道，Scheduled Tasks 显示队列，Plugins 显示能力组，Settings 汇总当前偏好。
- **顶部栏**：中心列内的 52px 条带。显示活动工作区身份和副标题。
- **中心工作表面**：Code 渲染消息时间线、起始卡片、按证据着色的消息行和底部 composer。Code 提示行把紧凑模型和思考级别选择器直接放在 Send 旁。Settings 渲染分组卡片。Write、Connect Phone、Scheduled Tasks 和 Plugins 渲染静态产品形态表面。
- **右侧检查器**：视口至少 1180px 宽时为 360px；更窄布局中隐藏。Code 显示 Plan / Todo / Changes / Context 卡片。其他工作区显示匹配的静态检查器卡片。
- **状态栏**：28px 条带，显示运行时就绪状态和会话身份。

Code 工作区中的消息行按角色渲染：user（右对齐气泡）、assistant（左对齐气泡，可带 reasoning）、tool result（diff/status 着色的证据卡）、runtime notice（弱化说明文字）和 terminal（状态 badge + 消息）。重复卡片使用 8px 圆角；chip 和 badge 通过视图库保持 pill 形。

当前 UI 刻意不实现 Write 持久化/补全、手机配对、任务执行、插件安装、本地 diff 应用或命令目录。ACP v1 支持位于传输层，并且有意不公布客户端文件系统或终端能力。

## OpenSeek 集成（当前）

macos_skia 入口点使用 `openseek_native_transport`，它会：

- 从 MoUI `Effect::run` 入队命令，并在专用 `openseek_worker_loop` 任务上与 Skia 异步 pump（`@async.all`）一起运行；
- 通过 `@store.SessionStore` 在 `MO_WORKBENCH_SESSION_ROOT`（默认 `<workspace>/.openseek`）下持久化会话事件；
- 把 `SessionItem` / `TurnTerminal` 映射为 Code 工作区的 `AgentEvent`；
- 仅启用 OpenSeek 当前解析的模型 id（`deepseek-v4-flash`、`deepseek-v4-pro`、`kimi-k2.7-code`、`kimi-k2.7-code-highspeed`），同时把 provider 发现的其他 id 显示为禁用选项；
- 支持对 store 执行 `NewSession`、`SwitchSession` 和 `FetchSessionList`。

后续工作：提供长生命周期 `AgentRuntime` 加后台 worker（serve-mode 形态），使 turn 中途的 `Steer` 与活动 turn 共享同一运行时，并可选集成 `spawn_bg` 与 Skia 异步 pump，替代每个 turn 的阻塞。

## ACP 集成（当前）

macos_skia 入口点可以从 `.mo_workbench/settings.json` 选择 `acp_native_transport`：

```json
{
  "agent_backend": "acp",
  "acp_command": "acp-agent",
  "acp_args": "[\"--stdio\"]",
  "acp_process_cwd": ""
}
```

ACP 后端：

- 启动配置命令作为子进程，并使用 ACP stdio JSON-RPC 换行消息；
- 发送带保守客户端能力的 `initialize`（`fs.readTextFile=false`、`fs.writeTextFile=false`、`terminal=false`）；
- 通过中立后端边界映射 `session/new`、`session/prompt`、`session/cancel`，以及可选的 `session/list`、`session/load`、`session/resume`、`session/set_mode` 和 `session/set_config_option`；
- 处理 Agent `session/update` 通知，包括消息 chunk、thought chunk、工具调用、plan/usage 通知、模式/配置更新和会话信息；
- 通过渲染权限卡并以所选选项或 `cancelled` 回复，处理 Agent `session/request_permission` 请求。

## 保留的完整对齐计划

未来扩展（不在当前原型范围内）：

- **ConnectPhone**：ADB/设备配对 UI + 文件传输 + 日志流。
- **ScheduledTasks**：类 cron 任务调度器 + 任务历史。
- **Plugins**：插件加载 + 配置面板。
- **Write workspace**：Markdown 编辑器表面（`examples/markdown_editor` 包已经展示构建块）。
- **跨平台入口点**：目前只有 macOS Skia 已接线；Linux/Windows/Web 入口点可作为 `linux_skia` / `windows_skia` / `web_wasm` 子包添加，而无需触碰共享应用。
