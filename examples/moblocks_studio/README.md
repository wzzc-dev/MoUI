# MoBlocks Studio

像搭积木一样构建应用，也可以让 AI 直接生成可视、可改、可验证的工作流。

底座是 MoUI（跨平台 MoonBit 声明式 UI 框架 + TEA 运行时）；MoBlocks Studio 是构建在其上的完整产品。

项目介绍（创新/可用/开源/案例四维口径）见 [PROJECT_INTRO.md](PROJECT_INTRO.md)。

## 5 分钟 Quick Start

### Web

```sh
# 在仓库根目录
moon build examples/moblocks_studio/web_wasm --target wasm-gc

# 起一个静态服务器（仓库根为根目录）
python3 -m http.server 8791
# 浏览器打开
#   http://127.0.0.1:8791/examples/moblocks_studio/web_wasm/index.html
```

页面加载后：

1. 右侧「模型 Provider」保持 **假模型（确定性，离线可演示）**。
2. 右侧「AI 生成」保持默认描述（或改成自己的话，例如「分析上传的 csv 表格数据」——假模型按关键词路由到对应模板）→ 点「生成」→ 出现「AI 提案预览」→ 点「接受替换」。
3. 底部「项目模板」可切换到三个内置模板或新建空项目。
4. 点「自动运行到阻塞点」：时间线逐格推进，画布上金色高亮跟随当前积木（绿旗时刻）。
5. 跑到「模型调用」会暂停在「等待人工确认」——这就是数据外发闸门；点「确认外发」跑到完成，点「拒绝」则失败且不产生副作用。

### macOS（Skia，原生加分演示）

```sh
moon check examples/moblocks_studio/macos_skia --target native
```

macOS 入口额外带一个真实的 OpenAI 兼容 provider 工作者（async），切到「真实 provider」后填写 endpoint 与 API Key 即可联网生成。

## 17 种积木手册

| 分类 | 积木 | 作用 | 端口/配置要点 |
|---|---|---|---|
| 事件 | AppStart | 应用启动时触发一次 | 输出 `flow`（执行流） |
| 事件 | UserPrompt | 等待用户输入一段提示 | 输出 `prompt`(Text)、`message`(ChatMessage) |
| 事件 | FileSelected | 用户选择一个本地文件 | 输出 `file`(FileRef) |
| AI | ModelCall | 调用大模型生成文本 | **external_submit**；输入 `prompt`/`context`/`approved` |
| AI | StructuredModelCall | 调用大模型并按 schema 解析 JSON | **external_submit**；输出 `result`(Json) |
| AI | PromptTemplate | 用变量渲染提示词模板 | 配置 `persona` |
| AI | ConversationMemory | 读写多轮对话上下文 | 配置 `entries` |
| 安全 | UserConfirmation | 高风险动作前暂停并等待用户确认 | 输入/输出均为 `action`/`approved`(Json) |
| 控制 | Sequence | 按顺序依次执行分支 | — |
| 控制 | IfElse | 按条件选择分支 | 配置 `condition` |
| 控制 | ForEach | 对有界集合逐项执行 | 配置 `limit`（上限 64） |
| 控制 | Retry | 失败时重试 | 配置 `attempts`（上限 3 次）、`backoff_ms` |
| 控制 | Timeout | 超过预算时间转为失败 | 配置 `budget_ms` |
| 控制 | CatchError | 捕获上游失败并转入处理分支 | — |
| 数据/UI | ParseJson | 把文本解析为 JSON 值 | — |
| 数据/UI | ShowMarkdown | 把 Markdown 文本渲染到界面 | 输入 `content`(ChatMessage) |
| 数据/UI | ShowTable | 把结构化数据渲染为表格 | 输入 `data`(Json) |

连线规则：每个非入口积木都有 `trigger`(Unit) 输入与 `flow`(Unit) 输出表达执行顺序；数据端口类型必须严格匹配；**每个输入端口至多一条入边**。

## 安全模型

1. **AI 只产出版本化提案**：模型输出必须是 `BlockGraphProposal`（version 2 JSON）。未知积木类型、未知版本、非法 JSON、类型错连、环、无入口、超预算（节点 64 / 连线 96 / 遍历 64）一律拒绝。
2. **外发闸门**：`ModelCall`/`StructuredModelCall` 为 external_submit 风险级，验证器要求其 `approved` 输入端口必须从某个 `UserConfirmation` 积木的 `approved` 输出**直接连线**——仅仅"图上可达"不够（确认节点挂在无关支路上时一律拒绝）；删掉确认节点或改接别处，图即不可运行。
3. **拒绝无副作用**：运行中拒绝确认，当前步骤标记失败、下游跳过、审计留痕。
4. **凭据脱敏**：API Key 只存在会话内存，不写入 `.moblocks.json`（有测试断言导出内容不含 key）；日志/演示/fixture 均脱敏。
5. **有界执行**：重试上限、超时预算、遍历上限、请求字符预算，四层边界保证「有界性」可演示。
6. **审计**：运行结束可导出 Markdown 审计报告（状态 / 步骤表 / 事件流）。
7. **执行语义口径**：Studio 的执行器是确定性的状态机——按拓扑序推进、在确认闸门暂停、记录每一步状态/耗时/摘要；模型步骤的回复由确定性假模型承担（离线可回放）。它演示的是**执行编排与安全闸门**，不是完整的积木语义求值器。

## 架构

```text
examples/moblocks_studio/
├── app/                  # 平台中立产品：严格 TEA（Model/Msg/update/view）
│   ├── block_catalog.mbt # 17 积木规格：端口 + config schema
│   ├── block_graph.mbt   # Graph/Node/Edge（端口化边 + flow 标准流端口）
│   ├── graph_validation.mbt # 类型/占用/入口/可达/环/预算/权限路径
│   ├── graph_editing.mbt # 编辑命令 + 100 步 undo/redo
│   ├── execution_reducer.mbt # 事件化执行状态机（重试/超时/取消/审计）
│   ├── ai_generation.mbt # 提案 v2 解码 + 系统提示 + 真实生成收尾
│   ├── project_codec.mbt # .moblocks.json v1 编解码（往返字节稳定）
│   ├── canvas.mbt        # 画布绘制计划 + 视口变换 + 绿旗时刻聚光灯
│   ├── templates.mbt     # 三个内置模板（镜像 fixtures/*.moblocks.json）
│   └── app.mbt           # Model/Msg/update/view + provider 面板
├── services/
│   ├── model_provider/   # OpenAI 兼容请求/响应 + 确定性假模型 + native async worker
│   └── export/           # 导出自包含 MoUI 项目（15 个文件）
│       ├── kernel_*.mbt      # 生成物：内核与 runner 的逐字节副本（改内核后重跑 sync_kernel）
│       ├── tools/sync_kernel/        # 同步工具（--check 漂移门，已进 pr profile）
│       └── tools/export_runner_template/ # 导出应用的 runner 模板（TEA）
├── web_wasm/             # 评审主路径（薄入口 + 固定 ABI shim）
├── macos_skia/           # 原生加分演示（async main + provider worker）
└── fixtures/             # 提案与示例项目镜像文件
```

数据流：所有交互（画布、属性表单、连接、运行）都收敛为 typed `Msg` → 纯 `update`；IO（文件对话框、provider 请求）走 `Effect`/`ServiceTask` 与原生 worker，结果仍以 `Msg` 回到 reducer。

## 故障排查

| 现象 | 原因 | 处理 |
|---|---|---|
| 页面白屏 | 静态服务器根目录不对（index.html 用相对路径找 wasm） | 以**仓库根**为服务器根目录 |
| 画布积木选中/拖拽 | 画布内按下即可选中，按住拖动可移动积木（回归测试 `M2：画布积木可经拖拽移动`）；注意 draw 命令里的文本帧是画布局部坐标，指针事件是屏幕坐标，二者相差画布原点 | 也可用底部「选择积木」按钮列表选择；属性在检查器编辑 |
| 提案被拒绝 | 模型输出 schema 不符/类型错连/缺确认节点 | notice 会给出中文校验错误；用模板起步或手动连线 |
| 真实 provider 无响应 | Web 目标无 async HTTP（`moonbitlang/async/http` 仅 native） | Web 请用假模型；真实 provider 走 macOS 入口 |
| 导出后不会运行 | 需要在导出目录按其 README 构建 | `moon build <name>/web_wasm --target wasm-gc`（以该目录为服务器根） |
| 导出页面停在 Loading | 静态服务器根目录不对：宿主页从**导出项目自己的 `.mooncakes`** 加载运行时 JS（`moon build` 后生成），必须从项目根起服务 | 在导出项目根执行 `python3 -m http.server`，再打开 `/<name>/web_wasm/index.html` |
| 导出应用点「运行」提示校验失败 | 项目图本身不合法（如缺确认闸门/类型错连）——导出应用内嵌与 Studio 同一套校验器，会原样阻止 | 回 Studio 修图或换合法模板再导出 |

## 测试

```sh
moon test examples/moblocks_studio/app --target native
moon test examples/moblocks_studio/app --target wasm-gc
moon test examples/moblocks_studio/services/model_provider --target native
moon test examples/moblocks_studio/services/export --target native
moon build examples/moblocks_studio/web_wasm --target wasm-gc
moon check examples/moblocks_studio/macos_skia --target native
```

覆盖：积木规格与端口类型校验（20 类失败，含 3 类输入解析）、项目 codec 往返、编辑/撤销重做、执行状态机（确认/拒绝/重试/超时/取消/无 UI 确定性运行）、真实生成回路的围栏容忍、模板加载、导出 bundle 结构、内嵌项目数据往返、**导出引擎端到端跑到完成**（app 52）、提示词关键词路由与无坐标自动布局、approved 精确闸门（含无关支路拒绝）、模型步骤确定性回复摘要、UI 运行时点击。

## 致谢与边界

- 架构研究参考了 scratchfoundation/scratch-editor 的 package 职责分离（GUI/VM/render/storage）与「工具箱—工作区—即时反馈」交互模型；**未复用其源码、视觉素材、品牌或角色/舞台系统**（其根许可证为 AGPL-3.0）。详见 `THIRD_PARTY.md`。
- 本作品为独立 MoonBit/MoUI 实现，随仓库以 Apache-2.0 许可分发。
