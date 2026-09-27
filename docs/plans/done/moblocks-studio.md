# Plan: MoBlocks Studio — AI 直接生成的可视化应用开发工具

- **Status**: done
- **Superseded by**: [momao.md](../active/momao.md)（2026-09-27：MoMao 墨卯统一取代 Mo易/MoBlocks 双 Studio，本计划对应代码 `examples/moblocks_studio` 已删除，salvage 映射见新计划第 11 节）
- **Goal**: 在上海 2026 开源软件应用创新大赛「开源 AI 工具」赛道交付一个可打开即用的产品：用户通过类 Scratch 积木与自然语言生成、验证、运行、调试应用工作流，并导出可运行的 MoUI 应用。
- **Deadline**: 2026-10-11 报名截止；内部目标 2026-10-09 完成交付包，10-10 提交。
- **Non-goals**: 不复刻 Scratch 的角色/舞台/动画系统；不复用或复制 Scratch AGPL 源码；比赛版不做 MCP 集成（client、server 管理与工具积木，已列入赛后路线图）；不做多人协作、云账户、多 Agent 编排、任意代码执行、移动端产品承诺或完整低代码平台。

## Product Positioning

**产品名**：MoBlocks Studio  
**一句话**：像搭积木一样构建应用，也可以让 AI 直接生成可视、可改、可验证的工作流。  
**目标用户**：需要快速制作应用但不想从执行引擎、权限控制和跨平台 UI 开始编码的开发者、技术教师与业务创新人员。

首个完整案例是「对话机器人」，致敬 Scratch 最经典的 ask/say 入门项目（Scratch 让小猫说话，MoBlocks 让 AI 记住你）：UserPrompt 事件驱动多轮对话 → ConversationMemory 保持上下文 → PromptTemplate 设定人设 → 首次外发被 UserConfirmation 拦停 → ModelCall 生成回复 → ShowMarkdown 渲染；运行全程配合“绿旗时刻”演出（画布当前节点点亮、数据沿边流动、确认点暂停等待），让图“活”起来。全程可用 deterministic fake model 离线演示。

## Evidence And Reference Boundary

### Scratch Editor 一手资料（参考，不移植）

2026-09-24 读取 `https://github.com/scratchfoundation/scratch-editor` 的 `develop` 分支：

- 仓库自述为构成 Scratch editor 的 package monorepo；当前根许可证为 **AGPL-3.0**。
- `packages/` 已包含 `scratch-gui`、`scratch-paint`、`scratch-render`、`scratch-storage`、`scratch-svg-renderer`、`scratch-vm`、`task-herder`；README 说明其迁移目标是统一依赖管理与跨包变更。
- 可借鉴的是**职责分离与交互模型**：编辑器外壳、领域 VM、画布/渲染、存储、媒体工具分开；工具箱→工作区→运行舞台/调试结果的即时反馈；结构化项目持久化。
- 不复制其源码、视觉资产、积木文案、品牌、角色/舞台语义或 AGPL 实现。MoBlocks 采用独立 MoonBit/MoUI 实现，并在第三方说明中只列架构研究来源。

### MoUI 已确认基础

- `moui_agent` 当前面向**控制一个 MoUI runtime**，公开 `read_semantics` / `perform_action` 与可选 diagnostics；它不是通用 LLM Agent loop。
- `moui_agent_mcp` 当前把上述 AgentHost 路由为 MCP 工具，默认只暴露 `read_semantics` / `perform_action`。
- `docs/agent-semantics.md` 明确：稳定寻址不等于授权，高风险规则必须由应用 UI 与 TEA `update` 实现。
- MoBlocks 的工作流 Agent、模型 provider 与权限策略属于产品域；赛后若接入 MCP client 同样属于产品域，不得错误塞入 `moui_agent` / `moui_agent_mcp`，除非后续证明是多个独立产品共用的稳定协议。

## Product Architecture

```text
examples/moblocks_studio/
├── app/                         # 平台中立产品：严格 TEA
│   ├── model.mbt                # 项目、编辑选择、运行状态
│   ├── update.mbt               # 所有业务状态入口
│   ├── view.mbt                 # Studio shell / panels
│   ├── block_catalog.mbt        # 17 个比赛版积木定义
│   ├── block_graph.mbt          # Graph/Node/Port/Edge/配置值
│   ├── graph_validation.mbt     # schema/类型/权限/环/可达性
│   ├── graph_editing.mbt        # 添加、移动、连线、撤销/重做
│   ├── execution_plan.mbt       # graph -> 可执行计划
│   ├── execution_reducer.mbt    # 步骤状态机、重试、取消、审计
│   ├── ai_generation.mbt        # prompt + 结构化 BlockGraph 解码
│   ├── permissions.mbt          # read/write/execute/external-submit
│   ├── project_codec.mbt        # .moblocks.json v1
│   └── *_test.mbt
├── services/                    # 产品私有适配器；不进 app Model
│   ├── model_provider/          # OpenAI-compatible + deterministic fake
│   ├── project_store/           # 文件读写、原子保存
│   └── export/                  # 生成独立 MoUI 项目模板
├── web_wasm/                    # 评审主路径，薄 wiring
├── macos_skia/                  # 本机演示加分项，薄 wiring
└── fixtures/                    # fake model 与示例项目
```

### 包边界

1. `examples/moblocks_studio/app` 只能依赖 `wzzc-dev/moui`、领域 facades、`views`、`services` 和产品私有纯 DTO 包；禁止导入 runtime/backend/render/provider。
2. 模型 API 与文件 I/O 通过 typed `Effect` / `ServiceTask` 返回 `Msg`；请求 ID、连接句柄、密钥不进入业务 `Model`。
3. 积木画布首版优先用 app-owned custom `ViewNode`；仅当可复用控制经验证后才提升到 `moui/views`。不要先扩 core。
4. `moui_agent` 用于以后让外部 Agent 操作 MoBlocks UI；不用于实现 MoBlocks 内部工作流执行器。
5. 平台入口只组合 runtime/backend/renderer 与产品 service adapter。

## Core Domain Model

```text
BlockProject v1
├── metadata(id, name, revision)
├── graph(nodes, edges, entrypoints)
├── studio(viewport, selection)      # 可选、非执行语义
├── permissions(policy)
└── template_origin

BlockSpec
├── kind / version / category
├── input_ports[] / output_ports[]
├── config_schema
├── effect_kind                      # pure/model/ui/control（mcp 保留至赛后）
├── risk_class                       # read/write/execute/external_submit
└── runner_key

Execution
├── plan(snapshot_hash, ordered steps)
├── status(idle/running/waiting_confirmation/completed/failed/cancelled)
├── step records(input summary/output summary/duration/error)
└── audit entries
```

端口类型第一版固定为 `Text | Number | Bool | Json | FileRef | Table | ChatMessage | ToolResult | Unit`。不做用户自定义泛型类型。

## AI Generation Contract

AI 不返回任意 MoonBit 代码，只返回版本化 JSON `BlockGraphProposal`：

1. 严格 JSON 解码与 schema 校验；未知 kind/version/config 字段拒绝。
2. 对 block catalog 做 kind 解析；prompt 模板、记忆键等引用必须可解析。
3. 检查端口类型、单输入占用、entrypoint、可达性、环与执行预算。
4. 检查权限路径：`write/execute/external_submit` 必须经过显式 `UserConfirmation` 节点；验证器不自动授权。比赛版中 `ModelCall` / `StructuredModelCall` 归为 `external_submit`（用户数据将发往外部 endpoint），使权限验证在无 MCP 时仍可演示。
5. proposal 先进入 diff/预览，用户接受后才替换 graph；保留原 graph，支持撤销。
6. 模型不可接触明文密钥；provider adapter 读取平台安全配置。

## MVP Block Catalog

比赛版只实现 17 个积木：

- **事件**：AppStart、UserPrompt、FileSelected。
- **AI**：ModelCall、StructuredModelCall、PromptTemplate、ConversationMemory。
- **安全**：UserConfirmation。
- **控制**：Sequence、IfElse、ForEach（有界）、Retry（上限 3）、Timeout、CatchError。
- **数据/UI**：ParseJson、ShowMarkdown、ShowTable。

延后：MCP 集成（CallTool / ReadResource / HandleToolFailure 与 server 管理）、自由循环、并行 fan-out、多 Agent、插件、自定义代码节点。

## UX Surface

1. **欢迎/模板页**：新建空项目、打开 `.moblocks.json`、3 个示例。
2. **Studio 主界面**：左侧 toolbox，中间 workspace，右侧属性/AI 生成面板，底部运行时间线。
3. **模型 Provider 管理**：endpoint 与凭据配置（走平台安全存储，不落入项目文件）、连接诊断、fake/真实一键切换。
4. **安全确认**：显示将执行的动作、外发数据摘要、风险等级与作用范围；拒绝后流程进入可处理失败状态。
5. **调试器**：当前节点、输入/输出摘要、耗时、错误、重试/取消；禁止默认展示凭据和敏感正文。
6. **导出**：生成 MoUI app 项目、README、依赖清单和运行命令。导出应用内嵌与 Studio 逐字节同源的领域内核 + 通用 TEA runner，**可直接运行**（加载→校验→拓扑序执行→外发确认闸门→时间线→审计）；不承诺把任意图编译为静态 MoonBit 源码（解释执行，语义与 Studio 永不分叉）。

### Workspace 交互的递进降级

- L0（必须）：自动布局、点击选中、添加/删除、属性编辑、按钮式“连接到…”。
- L1（目标）：节点拖动、端口拖线、平移、缩放、框选。
- L2（赛后）：吸附、minimap、多选批量操作、大图虚拟化。

若画布 custom view 在第 4 天仍无法稳定通过拖拽/命中测试，立即回退 L0，不阻塞产品闭环。

## Milestones

### M0 — 计划与技术探针（09-24～09-25）

- [x] 建 `examples/moblocks_studio` 骨架、app 测试与 Web route。
- [x] 证明 custom view 可绘制 20 节点、命中选择、移动并生成 typed `Msg`。
- [x] 证明 fake model JSON → proposal → validation → graph。
- [x] 证明执行状态机产出逐步骤 timeline（状态/耗时/错误），全部经 typed `Msg` 回到 reducer。
- [ ] 记录 20/50/100 节点画布 frame 基线。

**退出门**：Web 显示三栏 shell，fake flow 可从 prompt 生成并跑到 ShowMarkdown；否则范围降为 L0 workspace。

### M1 — 领域内核与测试（09-26～09-28）

- [x] `BlockSpec/Graph/Port/Edge/Project v1` 与稳定 JSON codec。
- [x] 类型、可达性、环、预算和权限路径验证。
- [x] graph edit command + 至少 20 步 undo/redo。
- [x] execution reducer：运行、等待确认、拒绝、重试、超时、取消。
- [x] deterministic fake model fixtures。

**退出门**：核心测试覆盖有效图和至少 15 类失败；无 UI 也可确定性运行样例图。（已达成，见 Progress）

### M2 — 可用 Studio（09-29～10-02）

- [x] toolbox/workspace/inspector/timeline 四区布局（控件集中于底部滚动面板 + 检查器，工作区方案见 done/row-child-hit-testing.md（2026-09-26 复核关闭））。
- [ ] 运行演出（绿旗时刻）：执行时画布当前节点高亮、确认节点暂停脉冲、时间线联动滚动。
- [x] 17 种积木的目录、属性表单和颜色/图标语言（config schema 实时校验、效果/风险徽标）。
- [x] AI 自然语言生成 + proposal diff/接受/撤销。
- [ ] 模型 provider 配置、连接诊断与 fake/真实切换。
- [~] 项目新建/打开/原子保存（codec + services 对话框接线完成并有分支测试；真实端到端留待桌面环境人工验证）。

**退出门**：新用户在 5 分钟内从模板运行第一个应用；核心流程不要求命令行。

### M3 — 真实闭环与安全（10-03～10-05）

- [x] 接一个 OpenAI-compatible provider，保留 fake/offline demo（native：macos_skia 组合根跑 async worker，真实 POST；Web：`moonbitlang/async/http` 无 wasm-gc 目标，评审走确定性 fake）。
- [x] 人工确认、凭据脱敏、参数/结果截断、审计导出（自动运行/审计导出/截断见 Progress 09-26 条）。
- [ ] 对话机器人完整案例（含绿旗时刻运行演出）。
- [ ] 本地文档分析助手与 CSV 分析助手至少可从模板运行。

**退出门**：断网时 fake demo 完整可演示；联网时真实模型可生成同 schema 图；删除 confirmation 节点后 validator 必须阻止数据外发图。
（MCP 相关原条目已按 2026-09-25 决策移除——比赛版不做 MCP 集成，见 Decision Log。）

### M4 — 导出、文档与比赛材料（10-06～10-08）

- [x] 导出独立 MoUI 项目并在 workspace 外验证（`services/export` 生成 moon.mod/moon.pkg/内核 5 文件/project_data/runner/web 入口/README/deps，共 15 个文件；Web 宿主页的运行时 JS 从导出项目 `moon build` 后生成的 `.mooncakes` 依赖目录加载，版本与 moon.mod 固定一致、无需手工拷贝；export 8/8 测试；workspace 外 `moon check` native+wasm-gc、`moon build web_wasm` 与浏览器实测（运行→等待人工确认→确认外发→8 步全部完成）均通过）。
- [x] 中文 README、5 分钟 Quick Start、积木手册、安全模型、故障排查、架构图。
- [x] LICENSE/NOTICE/THIRD_PARTY；明确未复用 Scratch 源码与品牌。
- [x] 3-5 分钟演示视频脚本与 8-10 分钟备用完整演示（DEMO_SCRIPT.md：绿旗时刻 + 确认闸门主线 + 一句话扩展生成镜头；录制待人工）。
- [x] 项目介绍按“创新/可用/开源/案例”组织（PROJECT_INTRO.md，README 指向）。

**退出门**：干净环境按 README 10 分钟内启动；导出项目能构建；演示无需现场联网也能跑。

### M5 — 冻结与提交（10-09～10-10）

- [x] 功能冻结：本会话仅修 P0/P1（导出 bundle 无法启动为 P0；M4-e 文档缺口为 P1）。
- [x] Web 评审包、macOS 演示包、示例项目、SBOM/依赖清单（`deps.txt` + `THIRD_PARTY.md` 依赖表）。
      video/截图/3 名首次用户为**人工任务**（见文末「人工待办」）。
- [x] 完整回归：app 46/46 ×2 目标、`moui/runtime` 140/140 ×2 目标（含新增指针回归 5 项）、
      model_provider 5/5 ×2、export 6/6、web_wasm wasm-gc 构建、macos_skia/provider_native/emit_bundle
      check、`sh scripts/check.sh --profile pr` 176 步全绿、两包 `moon fmt --check` 干净、
      静态校验七件套通过、workspace 外导出 bundle `moon check/build` + 浏览器启动实测通过。

## Acceptance

### Product

- [x] 用户不写代码即可新建、生成、编辑、保存、打开并运行一个项目（保存/打开经
      `SaveRequested`/`OpenReadCompleted`/`OpenPathPicked` 测试覆盖含取消与格式拒绝；
      OS 文件对话框本身需人工点一次，见「人工待办」）。
- [x] AI 只生成结构化 proposal；非法 kind、类型错连、无界环、未知引用均不可执行
      （20 类校验失败 + proposal v2 解码围栏容忍，均有测试）。
- [x] 数据外发节点没有显式确认路径时验证失败；拒绝确认不产生副作用（权限路径校验 +
      执行状态机 Reject/Cancel 测试）。
- [x] 运行时间线显示每一步状态、耗时和安全摘要，支持取消与有界重试；执行时画布联动
      高亮当前节点、确认点暂停（绿旗时刻；`spotlight_node` + 时间线 + 截断摘要测试）。
- [x] 至少一个真实案例和两个可运行模板；离线 fake demo 与真实 provider 共用协议
      （chatbot 案例 8 积木/15 连线 + doc/csv 模板 + 同一 `provider_submit` 签名）。
- [x] Web 是完整评审路径；macOS Skia 运行同一 app 逻辑（两端浏览器/入口实测启动：
      canvas 2560×1440、状态 Running）。

### Architecture

- [x] app 生产依赖不含 runtime/backend/render/provider；平台入口符合 P1 行数与薄 wiring
      （`moon info`/import 断言行 + `validate-release-module-closures` 通过）。
- [x] 产品 DTO/执行器不进入 `moui/core`、`moui_agent` 或 `moui_agent_mcp`（包边界由
      import 声明与 validator 固定）。
- [x] 所有 I/O、模型结果通过 typed Msg 回到 reducer；Model 是 plain data
      （`Effect`/`ServiceTask` 回 `Msg`；API Key 只在会话内存，编码产物不含 Key 有测试）。
- [x] custom view 字段满足 P17 declaration/identity coverage
      （`validate-viewnode-declaration-coverage` OK，34 个节点）。
- [x] 无 Scratch 源码/视觉资产/商标复制；第三方说明记录设计研究来源与 AGPL 边界
      （`THIRD_PARTY.md` 边界表 + AGPL 无衍生声明）。

### Quality / Docs

- [x] 关键 reducer/validator/codec 有 native + wasm-gc 测试（app 46/46 ×2、
      model_provider 5/5 ×2、export 6/6、`moui/runtime` 140/140 ×2）。
- [ ] Quick Start 由非作者按干净环境复现（人工任务）。
- [x] 示例配置不含真实凭据；日志、演示和 fixture 均脱敏（fixture 用 example.com + 假 key；
      `encode_project` 不含 Key 有测试）。
- [x] 失败模式可读：模型 JSON 非法、provider 不可达、超时、拒绝、取消（中文 notice +
      测试覆盖各分支）。

### 人工待办（作者不可替代）

1. 录制演示视频（`DEMO_SCRIPT.md` 3–5 分钟主版本 + 8–10 分钟备用版；全程假模型离线可录）。
2. 提交用截图（Studio 三栏界面 + 绿旗时刻 + 导出 bundle 运行画面）。
3. 至少 3 名首次用户按 README Quick Start 走查（计时 + 卡点记录）。
4. OS 文件对话框实点一次：保存 `.moblocks.json` → 重新打开 → 图恢复。
5. 桌面端真实 provider 联调一次（endpoint + key → 生成同 schema 图）。

## Validation

最小循环：

```sh
moon test examples/moblocks_studio/app --target native
moon test examples/moblocks_studio/app --target wasm-gc
moon test examples/moblocks_studio/services/model_provider --target native
moon test examples/moblocks_studio/services/model_provider --target wasm-gc
moon check examples/moblocks_studio/services/provider_native --target native
moon build examples/moblocks_studio/web_wasm --target wasm-gc
moon check examples/moblocks_studio/macos_skia --target native
```

涉及可复用 canvas/control 时追加：

```sh
moon test moui/views --target native
node scripts/validate-viewnode-declaration-coverage.mjs
```

仅在触及 Agent 边界（例如赛后接入 MCP）时追加：

```sh
moon test moui_agent --target native
moon test moui_agent_mcp --target native
moon test examples/agent_counter --target native
```

冻结前：

```sh
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/validate-release-module-closures.mjs
sh scripts/check.sh --profile pr
```

浏览器 smoke 必须检查：创建项目、AI 生成、接受 proposal、连线/编辑、阻断缺确认的数据外发图、运行 fake model flow、保存重开、导出，并要求 console 无未解释错误。

## Risk Register And Fallbacks

| 风险 | 触发条件 | 处理 |
|---|---|---|
| 画布耗时失控 | 第 4 天拖线/命中仍不稳定 | 固定栅格 + 自动布局 + “连接到”菜单；保住生成/验证/运行闭环 |
| 通用 Agent loop 范围膨胀 | 需要多 Agent、自由循环、长期记忆 | 延后；比赛只做单执行计划、有界控制流 |
| 缺少 MCP 后叙事差异化不足 | 评审认为与普通 workflow 工具差异小 | 主线突出 AI 生成 proposal、权限路径验证与导出 MoUI 应用；MCP 作为赛后路线图展示架构远见 |
| 模型输出不稳定 | proposal 首次通过率低于 80% | 两阶段生成（意图→graph）、修复提示、模板约束；始终保留 fake demo |
| Web 文件持久化受限 | 浏览器无法自由读写本地文件 | 下载/导入 `.moblocks.json` 为基线，File System Access API 渐进增强；不承诺浏览器内透明写盘 |
| 框架改动拖慢产品 | 需要新增通用控制或 core API | 先 app-owned custom ViewNode；公共 API 提升另开 slice |
| 许可/品牌混淆 | UI 或命名接近 Scratch | 使用 MoBlocks 自有视觉与术语；不含 Scratch 名称/角色/素材；NOTICE 说明仅参考架构 |
| 评审环境无网络 | 模型服务不可达 | 确定性 fake model + 预录真实调用证据，离线完整演示 |

## Post-Contest Roadmap

1. MCP 集成：CallTool / ReadResource / HandleToolFailure 积木、server discovery 与管理 UI、外部 MCP client adapter。
2. 版本化 block extension SDK 与签名插件。
3. 多 Agent 子图、并行执行与资源预算。
4. MCP server marketplace（签名、权限清单、沙箱）。
5. 大图虚拟化、minimap、协同编辑与 project diff。
6. 从验证过的 BlockGraph 生成静态 MoonBit/MoUI 源码。
7. 面向教育的角色/舞台扩展；保持为独立 addon，不污染应用工具核心。

## Decision Log

| Date | Decision |
|---|---|
| 2026-09-24 | 上海赛提交产品为 MoBlocks Studio；MoUI 是底座而非唯一交付物。 |
| 2026-09-24 | 借鉴 Scratch editor 的 package/VM/GUI/storage 职责分离，不复制 AGPL 源码、素材和品牌。 |
| 2026-09-24 | 比赛 MVP 聚焦 Agent workflow，不实现 Scratch 角色/舞台动画。 |
| 2026-09-24 | AI 只能提出版本化 BlockGraph；执行前必须通过类型、环、预算和权限验证。 |
| 2026-09-24 | Web 为评审主路径；macOS Skia 是同 app 逻辑的加分证明；离线 fake demo 是硬要求。 |
| 2026-09-24 | `moui_agent`/`moui_agent_mcp` 保持 UI Agent 边界，不承载产品通用 Agent loop。 |
| 2026-09-25 | 比赛版暂缓 MCP 集成（client、server 管理、工具积木），聚焦 AI 生成 + 可视化应用闭环；MCP 移至赛后路线图。 |
| 2026-09-25 | `ModelCall`/`StructuredModelCall` 归为 `external_submit` 风险级，权限路径验证在无 MCP 时保持可演示。 |
| 2026-09-25 | 产品叙事从 Agent 开发工具收敛为通用可视化应用构建；保留 AI 直接生成作为核心差异点。 |
| 2026-09-25 | 旗舰案例定为对话机器人（致敬 Scratch ask/say）+ 绿旗时刻运行演出；本地文档分析助手降为模板。 |

## Progress

| Date | Note |
|---|---|
| 2026-09-24 | 计划创建；已读取 Scratch editor 公开仓库、MoUI Agent/MCP API、app 边界、测试与框架 Skill。尚未开始编码。 |
| 2026-09-25 | 范围调整：暂缓 MCP 集成；积木目录调整为 17 个（移除 CallTool/ReadResource/HandleToolFailure，UserConfirmation 归入安全类）；旗舰案例改为本地文档分析助手；M0 第三探针改为执行时间线；Web 持久化基线定为下载/导入。 |
| 2026-09-25 | 定位调整：一句话与验收口径改为"构建应用"，不再以 Agent 作为产品叙事；AI 直接生成工作流保留为核心卖点。 |
| 2026-09-25 | 旗舰案例调整：对话机器人 + 绿旗时刻运行演出成为首个完整案例；本地文档分析助手降为模板；M2 增加运行演出要求，M4 演示脚本明确 AI 现场扩展生成。 |
| 2026-09-25 | M0 探针落地：`examples/moblocks_studio`（app + web_wasm + fixtures）进入 workspace；探针A 画布命中/拖动经 typed Msg（`canvas.mbt` + 测试）；探针B fake model JSON→提案→校验→自动布局（`ai_generation.mbt`）；探针C 执行状态机在外发步骤暂停、确认/拒绝/取消全经 typed Msg（`execution_reducer.mbt`）。9/9 测试 native + wasm-gc 双端通过，包内零警告。帧基线以绘制计划规模代理：20/50/100 节点 → 59/149/299 条绘制 op（线性 3n-1）；浏览器端墙钟基线待 M2 真 UI 稳定后记录。 |
| 2026-09-25 | M0 退出门通过：浏览器 smoke 实测——三栏 shell 渲染 20 节点画布；点击「AI 生成对话机器人」→ 7 积木图自动布局；「运行」→ 时间线逐格完成并在「模型调用」处进入等待人工确认；「确认外发」→ 全部 7 步完成。拒绝路径与缺确认阻断由 native 测试覆盖。已知 UI 瑕疵（M2 处理）：画布无视口滚动（超出列被裁剪）、标题文本对比度偏低。 |
| 2026-09-25 | M1 领域内核落地：`block_graph.mbt`（端口化节点/边 + flow 标准流端口）、`block_catalog.mbt`（17 积木含 input/output ports 与 config schema）、`graph_validation.mbt`（类型匹配、单输入占用、未知端口/config key/值、节点/连线/遍历预算）、`project_codec.mbt`（.moblocks.json v1 编解码，二次编码字节一致）、`graph_editing.mbt`（9 种编辑命令 + 100 步历史 undo/redo）、`execution_reducer.mbt`（事件化：Start/StepOk/StepFail/Tick/Confirm/Reject/Cancel，重试次数与超时预算由图上游 Retry/Timeout 节点推导）。fixtures：chatbot_proposal.json 与 demo_project.moblocks.json 镜像。23/23 测试 native + wasm-gc 双端通过、包内零警告；浏览器 smoke 验证 AI 生成（8 积木分支图）、运行起始、时间线逐格推进。M2 待办：UI 自动步进接 Timer effect（当前"前进一步"手动）、画布视口滚动、调试器详情。 |
| 2026-09-26 | M2 落地：`app.mbt` 接入 GraphEditor 全量编辑（增删/移动/改名/配置/连线/撤销重做经 Msg）；检查器属性表单（标题/config 字段与实时错误）；L0 按钮式「连接到…/断开」；画布视口平移/缩放（Transform2D 组合）；AI 提案预览（接受替换/取消提案）；保存/打开走 services 文件对话框（AppServices 在 program 构造时捕获一次）。UI 测试：`moblocks_ui_test.mbt` 以 AppRuntime 点击真实按钮（运行、AI 生成）均通过；33/33 测试 native + wasm-gc 双端绿色、包内零警告。框架副线：发现并立案 `docs/plans/debt/row-child-hit-testing.md`（后移入 done/，见 2026-09-26 澄清条目）（row 子级按钮/scroll_view 嵌套/on_drag 手势不命中指针，附最小复现与绕行方案）；AppEnvironment 每 update 构造会静默杀死指针事件（已记 memories）。浏览器端完整链路（AI 生成→接受→运行→确认）已在当日早些时候验证；末轮面板重排后浏览器点击坐标需重新校准，native runtime 测试覆盖同一路径。 |
| 2026-09-26 | M2 尾项 + M3 起点：绿旗时刻——`canvas_draw_plan` 增加聚光灯参数，运行中/等待确认节点在画布上追加金色高亮描边（`app.mbt` 按 `execution.cursor` 状态推导）；模型 provider 面板（fake/真实切换、endpoint/key 字段，key 仅存会话内存并禁止入项目文件，测试断言编码产物不含 key）；新增 `services/model_provider` 包：OpenAI 兼容 chat/completions 请求体构造、响应解析（错误体/残缺结构拒绝）、确定性假模型、请求预算守卫，5/5 测试双端通过。app 36/36 保持双端绿色。M3 计划中的 MCP 条目按 2026-09-25 决策移除。 |
| 2026-09-26 | M3 provider IO：`services/model_provider/worker.mbt`（ProviderOwner 队列 + OpenAI 兼容 POST + `provider_submit_prompt`）；app 侧 `RealGenerationFinished` 分支（合法提案→预览、非法提案→中文拒绝、网络失败→notice）；macos_skia 入口改为 async main 跑 window/worker 对（模式同 mo_workbench）。发现并绕行：`moonbitlang/async/http` 无 wasm-gc 目标（post 找不到），因此 app 不依赖该包，Web 继续走 fake；已记 memories。app 39/39 + provider 5/5 双端绿，macos_skia `moon check` 干净。 |
| 2026-09-26 | M3 收尾：自动运行到阻塞点（AutoRunExecution——演示一键跑到确认闸门，`前进一步` 留给调试）；审计导出 Markdown（`export_audit_markdown`：状态/步骤表/审计事件）+ 摘要截断（`truncate_summary` 120 字符）；三个内置模板（对话机器人/本地文档分析助手/CSV 分析助手，`templates.mbt` 内嵌常量镜像 `fixtures/*.moblocks.json`）+ 新建空项目，均经 decode→validate 测试。app 44/44 双端绿。CSV 模板首版曾因确认节点在模型调用之后形成 5↔6 环，被校验器捕获后修正——顺带证明环检查在真实图设计中的价值。 |
| 2026-09-26 | M4 导出起点：`services/export/export.mbt`——从 BlockProject 生成自包含 MoUI 项目（8 个文件：moon.mod、app/moon.pkg、app/project_data.mbt（转义内嵌项目 JSON）、app/runner.mbt（模板化确定性 runner）、web_wasm/moon.pkg+main.mbt、README（构建命令）、deps.txt），模块名安全化、MoonBit 字面量转义、`join_path`；app 侧 ExportRequested → pick_directory → 批量 write_text（Effect::batch）。export 3/3 + app 45/45 双端绿，全部静态校验通过。 |
| 2026-09-26 | 导出应用从「展示壳」升级为**真正可执行**：`tools/sync_kernel` 把 5 个领域内核文件与 runner 模板逐字节同步成常量（`--check` 漂移门已注册进 pr profile），`export_bundle` 随包输出内核 + ~200 行通用 TEA runner（加载→校验→运行→外发确认闸门→时间线→审计）。浏览器实测：点「运行」→ 时间线推进到「模型调用·等待人工确认」→ 点「确认外发」→ 8 步全部完成。过程中修掉一个隐蔽 bug：`#|` 多行串在本工具链**不插值**，同步时对 `\{` 多做一层转义会把内核里的插值写成字面量——校验器的「输入占用」键因此退化成同一字符串，任意合法图都被误判 6 处冲突；已由 bundle 字节一致性 + app 47 的导出引擎回归固定。 |
| 2026-09-26 | 仓库维护债务收口：`docs/plans/debt/repo-format-and-ratchet-drift.md` 移入 done——5 个格式漂移文件已 `moon fmt`，`moon fmt --check` 全仓 0 差异，pr profile 格式步恢复绿色。 |
| 2026-09-26 | M4-b/M4-e 收口：导出 bundle 浏览器启动失败定位为两个真实缺陷——(1) Web 运行时 JS 闭包目录错位（runtime.js 内部 `../moui/backend/web/browser_runtime.js` 解析不到），改为复刻仓库目录结构 `bundle/moui_web_renderer/` + `bundle/moui/backend/web/`；(2) Moon wasm 链接器只导出「可执行包自身定义」的函数，bundle 缺 `web_wasm/abi.mbt` ABI 垫片导致产物只剩 `_start`，浏览器报 `must export web_dispatch_event`——generator 增加 `abi_mbt()`，export 测试固定 abi/link.exports/index.html 目录契约（6/6）。workspace 外实测：`moon check` native+wasm-gc、`moon build web_wasm`、浏览器打开 canvas 2560×1440 状态 Running。新增 `PROJECT_INTRO.md`（创新/可用/开源/案例四维）。 |
| 2026-09-26 | M4-b/M4-e 收口 + 框架债务澄清：导出 bundle 浏览器启动失败定位为两个真实缺陷——(1) Web 运行时 JS 闭包目录错位（runtime.js 内部 `../moui/backend/web/browser_runtime.js` 解析不到），改为复刻仓库目录结构 `bundle/moui_web_renderer/` + `bundle/moui/backend/web/`；(2) Moon wasm 链接器只导出「可执行包自身定义」的函数，bundle 缺 `web_wasm/abi.mbt` ABI 垫片导致产物只剩 `_start`，浏览器报 `must export web_dispatch_event`——generator 增加 `abi_mbt()`，export 测试固定 abi/link.exports/index.html 目录契约（6/6）。workspace 外实测：`moon check` native+wasm-gc、`moon build web_wasm`、浏览器打开 canvas 2560×1440 状态 Running。新增 `PROJECT_INTRO.md`（创新/可用/开源/案例四维）。`docs/plans/debt/row-child-hit-testing.md` 复核后移入 done：原症状（row 子级按钮不命中 / on_drag 不触发 / 画布拖不动）均为**坐标系误用导致的测试误判**——画布 draw 命令的文本帧是画布局部坐标，指针事件是屏幕坐标，旧测试把局部帧当屏幕点派发，点击落在积木上方 42px 空白处；且拖拽手势 `Started` 发生在首次越过 3px 阈值的 Move 而非 Down。框架无缺陷：8 形状探针 + canvas/按钮/普通 view 拖拽全部正常，新增 `moui/runtime/row_child_pointer_input_test.mbt`（5 项，双端 140/140），并恢复 Studio 画布拖拽端到端回归（app 46/46 ×2 目标）。 |
| 2026-09-26 | M4 文档与材料：`examples/moblocks_studio/README.md`（5 分钟 Quick Start、17 积木手册表、安全模型六条、ASCII 架构图、故障排查表、测试清单）；`THIRD_PARTY.md`（依赖表 + Scratch editor 参考边界：无源码/素材/品牌复用、AGPL 无衍生声明）；`NOTICE`；`DEMO_SCRIPT.md`（3-5 分钟主版本分镜 + 8-10 分钟备用版，全程离线假模型可录制）。 |
| 2026-09-26 | M5 冻结回归：`services/model_provider` 拆分为纯编解码包（双目标 5/5）+ `services/provider_native`（async worker，native-only，macos_skia 改引新包）。全量回归：app 45/45 ×2 目标、model_provider 5/5 ×2 目标、export 3/3 ×2 目标、web_wasm wasm-gc 构建、macos_skia 与 provider_native check 全部通过；清理检查确认无 scratch 文件/无调试输出；.gitignore 已覆盖 _build/.mooncakes。 |
| 2026-09-26 | M5 冻结回归（进行中）：修复仓库工具 `validate_viewnode_declaration_coverage` 的 `@fs.read_dir` 返回 `ArrayView` 编译错误（阻塞全仓 PR 门）；重生成 `docs/repository-facts.md` + `checks/api-surface-report.json`（新增 workspace 成员后必做）；按实测值重新登记 6 个源码行预算 ratchet；本会话全部新文件按 release formatter 输出格式化。剩余既有格式漂移（moui/core、moui_richtext、pdf_workbench 的 5 个文件）与 row 命中外推等登记于 `docs/plans/debt/`。MoBlocks 自身全量回归仍全绿：app 45/45 ×2、model_provider 5/5 ×2、export 3/3 ×2、web 构建、native checks。 |
| 2026-09-26 | 冻结前收口（本轮评审视角复查后修复三项）：(1) **P0 导出 bundle 无法在浏览器启动**——Studio 内「导出为 MoUI 项目」只写 15 个生成文件，而导出的 `index.html` 引用运行时 JS；此前只有离线 CLI `emit_bundle` 会从仓库拷 3 个 JS，产品路径与文档承诺不一致。修法：宿主页改为从**导出项目自己的 `.mooncakes` 依赖目录**加载（`../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js`，其内部 `../moui/backend/web/browser_runtime.js` 与动态 `./canvas2d_runtime.js` 同域解析，版本与 moon.mod 固定一致），`emit_bundle` 与产品导出收敛到同一个 `export_bundle`（两边零差异），目录契约由 `export_test` 固定；workspace 外实测 `moon check` native+wasm-gc、`moon build web_wasm`、静态服务全部资源 200、浏览器 Running → 运行 → 等待人工确认 → 确认外发 → 8 步全部完成。(2) **自然语言生成没有输入面**——检查器新增 prompt 输入框（`PromptInput` + `prompt_draft`），假模型按关键词路由到三个内置模板（默认描述仍走对话机器人提案），真实 provider 发送用户输入；连带修复「提案形状项目解码后节点全叠在原点」（无坐标时 `decode_project` 自动布局）。(3) **外发闸门精度**——校验器从「从确认节点可达」收紧为「外发节点的 `approved` 输入必须从 UserConfirmation 的 `approved` 输出直接连线」（无关支路上的确认节点不再放行），错误标签与 proposal 系统提示同步。另：执行步骤增加输入/输出摘要（`step_summaries`），模型步骤的回复由确定性假模型按人设/模型配置生成，时间线与审计显示可回放的真实内容；样例 20 节点图补接 approved 连线以保持合法。回归：app 52/52 ×2、model_provider 5/5 ×2、export 8/8 ×2、emit_bundle/macos_skia/provider_native check、web_wasm 构建、sync_kernel `--check` 全绿。 |
