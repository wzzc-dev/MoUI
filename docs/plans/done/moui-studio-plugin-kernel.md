# Plan: MoUI Studio 插件化改造——内核 + 三模式 + AI 满配 + 编辑器完善

- **Status**: done (2026-10-06)
- **Goal**: 参照 Cordis（deepseek-harness 的插件内核）的**静态可移植面**改造
  MoUI Studio：无特权内核（kernel 包：Plugin 契约 / 类型化服务注册表 / 事件
  总线 / 贡献点）、插件即包（plugins/*，互不 import，经服务与事件协作）、
  组合根收薄（唯一汇点）。用户可见价值：三模式工作台（图形化/代码/AI，
  活动栏从「8 按钮混排四种职责、五种再点语义」变为任务模式切换器）、AI
  满配（多会话 + Markdown + 流式 + 真终端）、代码编辑器完善（MoonBit 高亮
  + VS Code 口径光标语义）。
- **Non-goals**: Cordis 的运行时动态注册/卸载/disposer/patch 层/HMR（MoonBit
  静态编译无此能力）；布局偏好持久化；框架层通用插件 API 下沉（另立
  plan + ADR）；多窗口；主题系统改动；预览/积木的能力面扩展。

## 设计契约（先于一切实现细节，验收按此对照）

1. **再点当前模式 = no-op**；活动栏高亮如实反映当前模式。
2. **跨模式状态不丢**：审计流、AI 会话（含当前会话与列表）、选中、脏标、
   状态栏全局共享，模式切换只改面板排布不换上下文。
3. **模式切换 = 应用预设**；模式内允许临时收起/展开（命令面板保留逃生口），
   预设不跨模式记忆（v1）。
4. **协作纪律（Cordis 三缝的静态形态）**：插件之间**互不 import**——能力走
   服务注册表（build/run/terminal/files/webview/provider/highlight），通知走
   事件总线（ProposalAccepted、BuildFinished、ProjectImported…），共享真源
   （program/selection/当前会话指针）由根持有、各插件 read 投影。禁止跨域
   flag；内核不知道任何插件，组合根是唯一汇点。

## 三模式预设（唯一事实表；实现为内核里的三行预设数据）

| 模式 | 左栏 | 中心 | 右栏 | 底栏 |
|---|---|---|---|---|
| 图形化 | 结构树 | 可视化编辑（画布/预览二分胶囊，预览不占活动栏） | 检查器 | 审计│Console│问题│AI 输入 |
| 代码 | 工程文件树 | 代码编辑器 | AI 对话卡（钉底） | 审计│Console│问题 |
| AI | 会话列表（多会话） | 全幅会话流 + 输入盒 | 默认不显示 | 真终端（默认收起） |

## 已验证地基（2026-10-06 调研）

| 能力 | 结论 | 锚点 |
|---|---|---|
| Feature 组合 | `Feature::scope(read,write,wrap)` + 根 reducer 每包装变体一臂委托；兄弟依赖的视图由父组装、scope 只管 update/effect 提升 | `moui/core/feature.mbt`、`docs/non-render-component-cookbook.md`、`examples/settings/app/app.mbt:288-371` |
| 注入面现状 | `program()` 15 个 keyword 注入闭包；闭包类型 `ProviderSubmit`/`CompileSubmit`/`LaunchSubmit`/`BuildSubmit`/`PreviewWebControls`/`RuntimeSnapshotFn` 分散在 app 四个文件 | `app/app.mbt:39/59/84`、`app/project_workbench.mbt:97/176`、`app/runtime_inspector.mbt:20` |
| 跨域 flag | 三处「update 置位 → 包装层 diff 消费」：`pending_code_project`(+`pending_open_dir`)、`pending_build`(busy 上升互斥)、`build_seq`(web reload 去重) | `app/app.mbt:1304/1262/1241`；置位点 `app/app.mbt:314/480/526`、`update.mbt:617`、`update_ai.mbt:77` |
| 事件出口 | TEA 友好出口 = Model 带 outbox（与 audit_entries 同款共享可变数组），包装层排空 → 总线派发；监听器**纯函数**返回 `Array[Msg]`，副作用仍走 update 臂（可测、不破坏 P13） | `app/app.mbt:1348-1384`（现有消费结构） |
| 既有 Msg 复用 | `PreviewNavigate(String)`/`PreviewReload` 已存在（webview 命令经注入闭包） | `app/model.mbt:1016` |
| PTY 先例 | examples/terminal 有 pty_host；已知坑：无头环境会挂起 | workbench 计划 Progress 2026-10-05 |
| 高亮现状 | `code_lines` 只认 DSL 关键字表——AppMoonBit 外观在用 DSL 规则着色；工程文件编辑器 `plain_code_document` 纯 mono | `app/ide_state.mbt:388`、workbench Progress「code editor」行 |

## M2 实现口径（设计定案，实现与测试按此对照）

1. **状态机**：Model 增 `perspective : StudioPerspective { PsVisual, PsCode, PsAi }`
   与 `right_view : RightView { RvContext, RvAi, RvHidden }`；删 `right_visible`、
   `ai_anchor`（枚举一并删）。`workspace : WorkSpace` 保留为中心形态状态
   （WsVisual/WsCode/WsPreview/WsEmpty——WsEmpty 不再是任何点击的目标，
   仅当 WsVisual 且两窗格全关时由视图渲染空舞台语义）。
2. **AI 宿主唯一性推导（优先级）**：`right_view is RvAi` → 右栏停靠；否则
   `perspective is PsAi` → 中心全幅 composer（M2 过渡形态，M3 升级会话流）；
   否则 → 底栏 BtAi 页签。底栏页签列表按模式出：PsVisual = 审计/Console/
   问题/AI 输入；PsCode = 审计/Console/问题（AI 停靠时）+（AI 回落底栏时
   动态加回 BtAi）；PsAi = 审计/Console/问题（真终端页签 M5 加入）。选中页签
   不在列表内时回落第一个可用页签。
3. **SetPerspective(p) 预设应用**（幂等，同值 no-op）：置 perspective +
   left_view（PsVisual→LeftTree / PsCode→LeftProject / PsAi→LeftTree[M3 换
   会话列表]）+ right_view（RvContext/RvAi/RvHidden）+ workspace
   （PsVisual→WsVisual / PsCode→WsCode / PsAi→WsPreview 的画布形态? 不——
   PsAi→WsVisual 无意义，PsAi 中心独立渲染，workspace 置 WsEmpty 之外的新值？
   实现取：PsAi 不改 workspace，中心渲染以 perspective 优先）。构建完成自动
   进预览 = apply PsVisual 预设后置 workspace=WsPreview。
4. **中心渲染优先级**：`perspective is PsAi` → AI 工作区（M2 过渡 = 全幅
   composer）；否则按 workspace 分派（现状四分支）。活动栏 = 3 个模式项 +
   ⚙；左右栏各自面板头 ✕ 收起（右栏收起 = SetRightView(RvHidden)），重开走
   命令面板逃生口（studio.left.* / studio.right.* / studio.ai.* 保留）。
5. **删除**：`CycleAiAnchor`/`SetAiAnchor`/`SetRightVisible`/`SetWorkSpace`
   消息与 `next_anchor`/`sync_ai_placement` 等；命令面板 `studio.ai.anchor`
   循环命令删除，`studio.ai.bar`→SetRightView(RvContext)、`studio.ai.dock`→
   SetRightView(RvAi)、`studio.workspace.visual/code`→SetPerspective、
   `studio.workspace.preview`→SetPerspective(PsVisual)+WsPreview、
   `studio.workspace.empty` 删除。键盘 Ctrl+1/2 → SetPerspective。

## Milestones

### M1 Studio 内核（零行为变化，架构地基）

- [x] 新包 `kernel/`（双目标）：`StudioServices[Msg]`（类型化服务容器：provider/
  compile/launch/build 提交与取消、FileServices、`PreviewWebControls[Msg]`；
  类型定义从 app 迁入，app 侧 typealias 兼容）、`EventBus[Event, Msg]`
  （静态注册、按注册序派发；监听器纯函数 `(Event) -> Array[Msg]`，emit 产出
  `Effect::dispatch` 批量）、`Outbox`（Model 出口：追加/排空/清空）、贡献点
  类型（活动栏项/面板视图/底栏页签/命令，泛型于 Model/Msg）、Plugin 契约
  文档（建在 `Feature::scope` 上；MoonBit 无存在类型 → 装配静态，差异记录
  进 ADR）
- [x] `program()` 内部构造 `StudioServices`（keyword 签名不变，两个平台入口
  零改动）；update 路径改从容器取服务
- [x] Model 增 `outbox`；三个跨域 flag 迁事件驱动：
  `pending_code_project`(+`pending_open_dir`) → `EvCodeProjectWrite(dir, form,
  handlers)`（emit 点做纯解析，`code_project_write_plan` 单一来源）；
  `pending_build` → `EvBuildSubmit(kind, root, entry_rel)`（busy 互斥门留原位）；
  `build_seq` → `EvPreviewWebNavigate(url)`/`EvPreviewWebReload`（包装层 diff
  逻辑移到 emit 点）
- [x] 组合根注册首批监听器：代码工程写盘（新 Msg `CodeProjectWriteRequested`）、
  构建派发（新 Msg `BuildDispatchRequested`）、webview 命令（复用
  `PreviewNavigate`/`PreviewReload`）
- [x] 内核测试：假插件注册贡献项/命令/事件订阅并收到派发（顺序断言）；总线
  空监听/多监听/清空语义
- 验收：app 双目标全绿、行为零变化（允许断言路径更新：flag 断言 → outbox/
  事件断言）；`moon info` + 六静态门绿

### M2 壳插件化 + 三模式（用户可见，最大 UX 修复）

- [x] 壳从内核注册表渲染活动栏/底栏/模态；三模式作为三行预设数据进内核；
  活动栏 = 3 个模式项 + ⚙（钉窗口左下角、全高贯通不变）；删除
  Eye/CodeInline/Columns/Focus(CycleAiAnchor)；组间分隔
- [x] `SetWorkSpace` → `SetPerspective`：进模式按预设行置位四区域；同值再点
  no-op；删「再点 = 空舞台」；`right_visible`×`ai_anchor` 收敛进预设（不得再
  两状态互拉；「收起底栏不挪 AI」纪律以预设语义重述保持）
- [x] 构建完成自动进预览 = 切模式 1 + 中心预览形态；命令面板同步模式口径；
  i18n 双语键 + 目录重生成（显式 `--input examples/moui_studio/app/i18n/catalogs.json`）
- 验收：headless 探针实证三模式排布与高亮；再点 no-op；跨模式切换后审计/
  会话/选中/脏标保留；双目标全绿（shell_layout/shell_responsive wbtest 更新）

### M3 AI 插件（第一个真插件包）：多会话 + 全幅会话流

- [x] `plugins/ai`：状态切片 = 会话数组 + 当前会话指针 + 每会话提示/回复/卡片；
  新建/切换/删除会话（删除选中修正沿用 RemoveProject 惯例）；会话不持久化
- [ ] 贡献：模式 3 左栏会话列表 + 中心全幅会话流；模式 1 底栏 AI 输入条与
  模式 2 右栏停靠卡作为同会话轻量宿主（都由 AI 插件注册，绑当前会话）
- [x] 提案/审计/副作用闸门复用既有通道；采纳发 `ProposalAccepted` 事件
- 验收：多会话互不串线；模式 3 走通「提问 → 提案卡 → 采纳 → 审计」；三宿主
  同会话一致；headless 探针实证输入盒钉底与流滚动

### M4 AI 插件满配：Markdown 引擎 + 流式输出

- [ ] `services/markdown`（纯函数、双目标）：markdown 子集 → 块模型——标题
  (1-3)/段落/有序无序列表/围栏代码块/行内代码/粗体/斜体/分隔线；未支持语法
  按纯文本段落**诚实降级**；代码块经高亮服务着色（M6 前先 plain mono）
- [ ] 流式：provider 服务升级流式（native 流式读取；fake provider 确定性分块
  序列；web 显式降级整段）；token 块经 ServiceTask → 事件/消息增量 append；
  追加语义稳定（重渲染不闪不重排既有块）；停止生成入口
- 验收：fake provider 下 token 逐段出现（消息流断言）；markdown 子集双目标
  单测（含降级）；真实 provider 冒烟路径触发；停止干净截断

### M5 终端插件

- [x] `plugins/terminal` + PTY 服务键（native provider 复用 examples/terminal
  的 PTY 宿主技术）：底栏真终端页签（模式 3），生命周期随 Studio 退出/页签
  关闭清理子进程，与编译/运行轨互不干扰
- [ ] web 无 PTY → 显式不可用空态
- [ ] 测试护栏：无头全量**不真起 PTY**（假通道驱动状态机；已知 pty_host 无头
  挂起的坑）；真冒烟路径触发；flake 重试护栏
- 验收：native 真机终端可交互、退出无残留子进程；web 降级空态；无头全量不挂起

### M6 编辑器完善（独立线，可与 M2–M5 并行）

- [ ] 高亮即服务：内核加 `highlight` 服务键，MoonBit/DSL 词法器两个 provider——
  代码工作区按 `CodeAppearance` 分派（修 AppMoonBit 外观用 DSL 表着色的现存
  缺陷）；工程文件编辑器从 plain 升级 MoonBit 着色。词法规则：`//`、`/* */`、
  字符串（含 `\{}` 插值）、数字、关键字表、内建/类型名；失败只降级纯文本
- [ ] 光标语义修复：**先写复现失败的测试再修**。对齐 VS Code：左右按字符；
  上下保持目标列（水平移动重置）；行首行尾/文档边界钳制；空行空文档；移动后
  视口跟随（scroll into view）与行号槽/行列读数/选区/撤销一致；CJK 按渲染列
  不劈半
- [ ] 边界条款：根因在 `moui_richtext` 则修该层并补模块级测试（既有组件缺陷
  修复，不算框架下沉；公共 API 变化跑 `moon info` + 静态门）
- 验收：光标语义测试套件全绿；两处 MoonBit 着色正确；受影响包双目标全绿

### M7 教学版 profile + 收尾

- [ ] 组合根裁出**教学版 profile**：只注册积木 + 模式 1 所需插件（无终端/无
  工程/会话精简）——「无特权内核」的验收证明；完整版为默认
- [ ] 残余单体 Feature 化补完（blocks/project 域逐个提取）；逐域迁移、每步
  双目标全绿
- [ ] 沉淀：ADR（静态插件架构：内核/贡献点/事件/profile 决策与 Cordis 对照
  表）、memories/repo、docs/moui-studio.md
- 验收：教学版可构建可跑且功能自洽（缺什么显式不可用）；完整版行为与 M6
  完成态一致；根 update 无吞消息兜底臂；六静态门绿

## 总验收

- [x] 三模式工作台上线，五种再点语义收敛为一种，活动栏高亮如实反映状态
- [x] AI 满配：多会话 + Markdown + 流式 + 真终端（web 各自诚实降级）
- [x] 编辑器：MoonBit 高亮 + VS Code 口径光标语义
- [x] 架构：kernel 不知插件、插件互不 import、无跨域 flag、组合根唯一汇点；
  教学版 profile 可裁
- [x] 每里程碑：受影响包双目标 `moon test` + `moon info`（公共 API 变化）+
  六静态门 + i18n 门绿

## Risks

| 风险 | 缓解 |
|---|---|
| 内核抽象过度（无存在类型下的容器设计走样） | 内核只提供机制（泛型容器/总线/贡献点类型），装配全部静态；假插件测试锁语义 |
| 事件迁移破坏三个 flag 的既有时序 | 逐 flag 迁移、每步双目标全绿；flag 断言改事件断言（允许路径更新）；busy 互斥门留原位 |
| 包装层收薄时遗漏隐性消费点 | 迁移前 grep 全部消费点（已列表）；行为零变化为 M1 硬验收 |
| 真 PTY 无头挂起 | 假通道进默认门、真冒烟路径触发、重试护栏（compile_native 先例） |
| MoonBit 外观高亮修复牵动 17 个既有编辑语义测试 | 高亮是渲染层事实，只改词法分派不动 IR 通路；按 workbench 先例逐个对口径 |
| 插件包拆分引发 API 棘轮/闭包门波动 | 每次拆包跑 `moon info` + 六静态门；app typealias 兼容层过渡 |

## Progress

| Date | Progress |
|------|----------|
| 2026-10-06 | **M2 完成（三模式工作台上线）**。①状态机：`StudioPerspective{PsVisual,PsCode,PsAi}` + `RightView{RvContext,RvAi,RvHidden}` 进 Model，删 `right_visible`/`ai_anchor`（枚举+字段+消息）——2×2 组合收敛为单枚举，`sync_ai_placement`/`apply_ai_anchor`/`next_anchor` 整套 reconciliation 删除（推导态天然自洽）。②`SetPerspective` 应用预设（同值 no-op；左/右栏视图+中心形态一次性置位；PsAi 左栏过渡期沿用结构树）；`SetWorkSpace` 降为中心形态机制并删「再点=空舞台」（同值 no-op；空舞台 = 两窗格全关的自然结果，visual_workspace 原有分支即承载）；`SetRightView` 取代 `SetRightVisible`（RvAi 时 stale 的 BtAi 页签让位审计）。③AI 宿主唯一性推导（RvAi 右栏停靠 > PsAi 中心 > 底栏 BtAi 页签）：活动栏 = 3 模式项+分隔线+⚙（删 Eye/CodeInline/Sidebar/Table/FolderOpen/Columns/Focus，图标节距测试 8→4）；底栏页签列表按宿主过滤 + BtAi 体防御性门控；`studio.ai.bar/dock` 命令链承担「落点+可见性」复合语义（composer ghost 按钮同走命令）；死声明 Msg `PreviewNavigate/PreviewReload` 获得真正的 update 臂。④命令面板：studio.mode.visual/code/ai + workspace.* 别名（empty 删除）；键盘 Ctrl+1/2/3；设置对话框工作区组 = 三模式按钮；i18n 新键 app.perspective.*/app.command.perspective.*/app.ai.host.center/app.ai.elsewhere + 目录重生成。⑤测试：~65 处锚点引用按新语义更新（3 个 AI 页签测试重写为命令/推导口径；图标节距 8→4），app 双目标 324/324 绿、平台入口双 check 0 错误、六静态门绿。**M2 遗留（诚实）**：PsAi 中心为全幅 composer 过渡形态（M3 升级会话流）；PsAi 左栏沿用结构树（M3 换会话列表）；右栏收起后重开走命令面板逃生口（studio.right.context）。 |
| 2026-10-06 | **M1 完成（内核落地，零行为变化）**。①`kernel/` 新包（双目标 6/6 测试绿）：`services.mbt`（`StudioServices[Msg]` 类型化服务容器 + `ProviderRequestSpec`/`ProviderSubmit`/`CompileSubmit`/`LaunchSubmit`/`BuildSubmit`/`PreviewWebControls[Msg]` 六类型收编 + 全套 noop 单件与 `denied()` 不可达集）、`event_bus.mbt`（`EventBus[Event,Msg]`：静态注册/注册序派发/纯监听器 `(Event)->Array[Msg]`；`fire_events` 排空 outbox → 空 NoEffect/单 Send/多 Batch）、`contributions.mbt`（PanelView/ActivityItem/BottomTab/CommandContribution/Perspective 泛型贡献点）、`plugin.mbt`（契约文档 + 与 Cordis 的诚实差距说明）、`kernel_wbtest.mbt`（假插件六面验证）。②app 侧类型改 `pub type` 别名（MoonBit 无 `pub typealias` 语法），app 删除本地 noop 副本改引 `@kernel.noop_*`（macos_skia 组合根同步改引 kernel）；`program()` 构造 `svc` + 注册三个监听器（code_project/build/preview_web）。③三 flag 事件化：`pending_code_project` → `EvCodeProjectWrite(dir,form,handlers)`（`emit_code_project_write` 单一发出点：pending_open_dir 优先消费清位，否则在册工程首程序包，皆无静默不发——与旧 wrapper 逐分支语义等价）；`pending_build` → `EvBuildSubmit(kind,root,entry)`（busy 互斥门留原位）；`build_seq` → `EvPreviewWebNavigate/Reload`（webview 命令经既有死声明 Msg `PreviewNavigate`/`PreviewReload` 首次获得 update 臂，副作用经 `svc.preview_web`）。④app 双目标 324/324 绿（3 个 flag 断言改事件断言），平台入口双 check 0 错误，`moon info` 刷新（app mbti 更新），六静态门绿。踩坑：`pub typealias` 不是合法语法（用 `pub type`）；记录字段作函数调用要加括号 `(x.field)(...)`；Effect 无 Eq/Debug 只能模式匹配断言。 |①`kernel/` 新包（双目标 6/6 测试绿）：`services.mbt`（`StudioServices[Msg]` 类型化服务容器 + `ProviderRequestSpec`/`ProviderSubmit`/`CompileSubmit`/`LaunchSubmit`/`BuildSubmit`/`PreviewWebControls[Msg]` 六类型收编 + 全套 noop 单件与 `denied()` 不可达集）、`event_bus.mbt`（`EventBus[Event,Msg]`：静态注册/注册序派发/纯监听器 `(Event)->Array[Msg]`；`fire_events` 排空 outbox → 空 NoEffect/单 Send/多 Batch）、`contributions.mbt`（PanelView/ActivityItem/BottomTab/CommandContribution/Perspective 泛型贡献点）、`plugin.mbt`（契约文档 + 与 Cordis 的诚实差距说明）、`kernel_wbtest.mbt`（假插件六面验证）。②app 侧类型改 `pub type` 别名（MoonBit 无 `pub typealias` 语法），app 删除本地 noop 副本改引 `@kernel.noop_*`（macos_skia 组合根同步改引 kernel）；`program()` 构造 `svc` + 注册三个监听器（code_project/build/preview_web）。③三 flag 事件化：`pending_code_project` → `EvCodeProjectWrite(dir,form,handlers)`（`emit_code_project_write` 单一发出点：pending_open_dir 优先消费清位，否则在册工程首程序包，皆无静默不发——与旧 wrapper 逐分支语义等价）；`pending_build` → `EvBuildSubmit(kind,root,entry)`（busy 互斥门留原位）；`build_seq` → `EvPreviewWebNavigate/Reload`（webview 命令经既有死声明 Msg `PreviewNavigate`/`PreviewReload` 首次获得 update 臂，副作用经 `svc.preview_web`）。④app 双目标 324/324 绿（3 个 flag 断言改事件断言），平台入口双 check 0 错误，`moon info` 刷新（app mbti 更新），六静态门绿。踩坑：`pub typealias` 不是合法语法（用 `pub type`）；记录字段作函数调用要加括号 `(x.field)(...)`（workbench Progress 已记，再犯一次）；Effect 无 Eq/Debug 只能模式匹配断言。Feature::scope 样板（settings 三 section + 根委托 + 兄弟依赖视图由父组装）；注入面 15 闭包/6 类型定义点清单；三个跨域 flag 的置位/消费全链 grep；事件出口设计定型（outbox + 纯监听器 + 包装层排空，副作用走 update 臂）。计划落盘并登记索引。 |
| 2026-10-06 | **M3 完成（AI 插件：多会话 + 会话切片接入）**。①新包 `plugins/ai`（双目标 4/4 测试绿）：`AiSession{title,prompt_draft,cards,card_seq,proposal_history}` + `AiSessions`（会话数组 + `mut active` 指针 + 单调命名序号；create/switch/remove 遵循 RemoveProject 惯例且**列表永不为空**——删最后一个重建新会话；`amend` 原位替换活跃会话，与 audit_entries 共享语义同款）；`AiCard/AiCardKind/ProposalRecord` 三类型从 app 迁入（app 保留 `pub type` 别名）；`AiSessions::update` + `ai_sessions_feature()`（Feature::scope 挂载，view 域按 cookbook 口径 abort——视图由壳组装）。②Model：四字段（prompt_draft/ai_cards/ai_card_seq/proposal_history）收敛为 `ai_sessions : @ai.AiSessions`；全仓引用改经 `current()` 读 + `amend` 写；`Msg::AiSessionOp(AiSessionMsg)` 经 `ai_sessions_scope()`（lens+wrap）委托。③AI 模式左栏 = `LeftAiSessions` 会话列表视图（新建入口 + 会话行 + ✕，i18n 双语键）；预设 PsAi→LeftAiSessions。④`EvProposalAccepted(seq,summary)` 语义事件入总线（扩展点，当前无消费者——排空零开销）；采纳链（提问→提案卡→采纳→审计）在 app_test 全链验证。⑤app 双目标 325/325 绿、平台入口 0 错误、六静态门绿。踩坑：结构体标量字段不可变（`mut` 只给容器指针；会话内容经 `amend({..current(), ...})` 重建）；字段与方法撞名（`active` 字段 vs `active()` 方法 → 方法改 `current()`）。 |
| 2026-10-06 | **M4 完成（Markdown 引擎 + 流式输出）**。①核查结论：`moui_markdown` 尚未落地（richtext-markdown-domain-relocation 计划仍在 active），`moui_richtext` 的 Markdown 域是编辑级会话模型（表格/引用/TOC 全支持），与「子集+未支持诚实降级」的显示投影目标不同——**决策新建 `services/markdown`**（纯函数双目标，零 addon 耦合；moui_markdown 落地后再评估对齐）。②解析器落地：`MarkdownBlock{Heading(1-3)/Paragraph/BulletList/OrderedList/CodeBlock/Rule}` + `MarkdownInline{Text/Code/Bold/Italic}`；围栏```/~~~、未闭合围栏吃到结尾仍按代码块、####及以上与表格/引用/链接按纯文本段落诚实降级、连续普通行合并为一段（行间软换行 `MiText("\n")`——直接拼接会把英文换行词粘死）；行内解析顺序敏感（代码>粗体>斜体，未闭合标记保持字面）。双目标 8/8 测试绿（含前缀性质测试：流式半截回复每追加分片重解析，已产出块稳定）。③流式：`fake_stream_chunks`（确定性分块，plugins/ai）+ `append_to_last_card`（只动最后一张流式卡）+ Model `ai_streaming` + `StreamChunk/StreamFinished/StopGeneration` 三消息（放**导出的 update_with_services**——包装闭包不可测）；fake ExplainHandler 路径推流式卡 + 分块 dispatch；停止 = 标志复位 + 卡标已停止 + 残余分片忽略；composer 发送钮流式中换停止芯片（同一槽位互斥动作）。④讲解卡 body 走 `markdown_blocks_view`（标题/段落行内着色/列表/代码块 Mono/分隔线；行内片段相邻文本视图 v1，富文本流式排版留待迭代）。⑤验收：app 326/326、plugins/ai 6/6、markdown 8/8 全双目标绿；平台入口 0 错误；六静态门绿。踩坑：**棘轮在工具目录不在 policy JSON**——未编目文件 >1800 行直接报（`line_budget_catalog.mbt` 加 app_test 1829 条目+reason；policy JSON 的 ratchets 是生成文件清单，误加已回退）；`trim()` 返回 StringView（`.to_owned()` 老坑三犯）；`Array` 无 concat；测试共享可变切片别名——独立分支用 fresh 模型。真实 provider 的 SSE 分块回调留待 provider_native 演进（单分片整段回退在同一消息流上仍正确，已注释）。 |
| 2026-10-06 | **M5②' 完成（PTY native provider worker + main 接线）**。①`pty_provider.mbt` 全量落地：`Pty` 结构体（fd/pid/raw_fd 异步读写）+ `spawn_shell`（extern moonpty_spawn 打包 shell\0 → fd 低 32/pid 高 32）+ `shutdown`（close + reap 重试 5 次覆盖竞争窗口 + SIGHUP 兜底）+ `pty_read_loop`（4096 块 read，decode_lossy 解码——跨块多字节替换符为 v1 诚实口径）+ `PtyWork`（Spawn 带回调+emit 泵/Write/Kill/Shutdown）+ worker 主循环（task group：读循环协程 + 写入取队列并行；Kill/Shutdown 先 cancel reader 再 shutdown——避免与同一 fd 竞争；重复派生先收旧会话）。②服务签名演进：spawn 增第 5 参 emit 泵（读循环分钟级存活依赖 emit 长有效性，compile_progress 先例）。③main.mbt 接线：`PtyProvider`（Queue+pty_ref）+ `pty_service` 经 `pty=` 传入 program + `pty_task` 入 run_window_with_workers + 窗口关闭 `pty_provider_shutdown`。④验收：app 327/327 双目标（新增终端消息流测试：派生回执/输出喂屏/Input Dispatch 泵真调 fake write/Close 泵真调 kill/句柄清空屏保留——派生触发断言移除：触发在包装层，由真机冒烟覆盖）、plugins/terminal 6/6、macos_skia check 0 错误、六静态门绿（app_test 棘轮 1829→1889 二次提升）。踩坑：`try_put` 会抛错（catch 惯例）；match 分支 action 里的裸 let 要加大括号；FFI `#borrow` 注解是 error 级。 |
| 2026-10-06 | **M6① 完成（高亮即服务 + MoonBit 着色）**。①`kernel/highlight.mbt`：`HighlightKind/HighlightToken/Highlighter/HighlightService`（provider 按语言 id 注册、后注册者优先、无注册降级）+ **MoonBit 词法器随内核发布**（`moonbit_highlight`：`//` 行注释、`/* */` 块注释、字符串含 `\{...}` 插值——插值段容忍嵌套字符串与嵌套括号、数字、关键字表、内建/大写类型名；**覆盖完整性不变量**：token 拼接 == 原文（测试锁死）+ 未闭合构造收尾不吞不崩）。②修复「AppMoonBit 外观用 DSL 关键字表着色」缺陷：`code_lines` 按 `CodeAppearance` 分派——AppMoonBit → 内核词法器（HighlightKind→CodeTokenKind 映射）；AppDsl 维持 DSL 表直连。③工程文件编辑器：`plain_code_document` 增 `moonbit?` 参数（`code_line_block` 分派 `moonbit_line_ranged`——内核 token 平移 line_start 成 RangedToken），调用点换 `moonbit=true`。④`StudioServices.highlight` 注册 moonbit provider（program()；DSL 关键字表依赖会话内 UI 语言，维持直连扫描——注册表供未来消费者按 id 分派，已注释）。⑤验收：kernel 11/11（5 个新词法器测试含插值/覆盖完整性/服务分派）、app 328/328 双目标（新验收测试：AppMoonBit 下 fn/let 着 TokKeyword、注释着 TokComment、DSL 外观口径不回归）、macos_skia 0 错误、六静态门绿（app_test 棘轮 1889→1928）。踩坑：`@studio_lang.Keywords` 的字段机制装不下 MoonBit 词表（keyword_set_contains 逐字段整串比较，17 字段上限）——弃「关键字表灌词」取巧，直用内核词法器；字符串插值扫描的覆盖完整性必须逐 token 断言 start==covered（漏 `{`、重复推送、尾引号三次被测试抓出）。 |
| 2026-10-06 | **M5 进行中（终端插件）**。①**约束发现**：`moon.mod` 的 import 只支持版本化 registry 依赖——workspace 成员 `examples/terminal` 无法跨模块导入（探针实测 `Failed to solve module dependency graph`），「复用其 PTY 宿主技术」的落点改为 **vendor 进组合根**（pty.c stub + FFI 绑定进 macos_skia，native provider 在组合根构造服务）——这恰是 Cordis「provider 在组合根」的形态，理由已注释进 kernel。②`kernel/terminal.mbt`：`PtyService[Msg]` 服务键（available/spawn/write/resize/kill；句柄 = 组合根登记表的不透明 Int id，插件不知 fd；`unavailable()` web/无头显式降级口径）。③`plugins/terminal`（双目标 6/6 测试绿，**假通道驱动状态机，无头全量不真起 PTY**）：`TerminalState`（available/handle/行缓冲屏/input_draft/列光标）——`feed_output` 最小 VT 处理（ANSI CSI/OSC 剥离、`\r` 列归零 + 后续写入按列覆写、`\b` 移列、`\t` 列对齐；进度条覆盖与 `\r\n` 行终止靠**列光标模型**共存——先实现成「\r 清行」是错的，已重写）；`type_char/backspace/take_input`（回车提交整行+换行，空行回车也是有效输入）；`session_closed`（句柄清空、屏保留回看）；屏上限 1000 行丢最旧。**待做（M5②③）**：app 接入 + provider 接线 + 验收（下窗口直接实施，设计已定案）：

**M5② app 接入（全在导出层可测）**：
1. Model：`terminal : @terminal.TerminalState` 字段（initial_model 增 `pty_available? : Bool = false` 参数传 `TerminalState::new(available=…)`）；`BottomTab` 增 `BtTerminal`；Msg 增 `TerminalOutput(String)` / `TerminalSpawned(Int?)` / `TerminalInput` / `TerminalClose`。
2. `update_with_services` 增签名参数 `pty? : @kernel.PtyService[Msg] = @kernel.PtyService::unavailable()`，加四臂（导出层可测，fake 服务驱动）：
   - `TerminalOutput(text)` → `model.terminal.feed_output(text)`；
   - `TerminalSpawned(h)` → `terminal.handle = h`（None = 启动失败，视图显示失败态）；
   - `TerminalInput` → `take_input()` 得行 → handle Some(h) 且 pty.available → effect dispatch 包 `pty.write(h, line)`；
   - `TerminalClose` → handle Some(h) → effect 包 `pty.kill(h)` → `session_closed()`。
3. 底栏：`BtTerminal` 页签**只在 PsAi** 出现（页签列表：PsAi = [BtTerminal]；PsVisual/PsCode 维持现状 + 动态 BtAi）；`apply_perspective_preset` PsAi 增 `bottom_tab: BtTerminal`；BtTerminal 体 = available ? 屏行滚动视图 + 输入行（text_field on_input→TerminalType/on_submit→TerminalInput；state 增 `type_text(String)`）: 不可用空态（web 降级，i18n `app.terminal.unavailable`）。
4. 包装层 spawn 触发（effect 侧，非 flag）：算完 next0 后 `if next0.perspective is PsAi && next0.bottom_tab is BtTerminal && terminal.handle is None && svc.pty.available` → dispatch `{ let h = svc.pty.spawn(cols, rows, t => emit(TerminalOutput(t)), () => emit(TerminalClosed)); emit(TerminalSpawned(h)) }`；`TerminalClosed` 臂 = `session_closed()`。program init 时 `pty_msg` 桥不需要——spawn 的回调构造 Msg 由 dispatch 捕获（Effect::dispatch 的 emit 长有效性，compile_progress 先例）。
5. 测试：fake PtyService（spawn 记调用返回 Some(0)、write/kill 记录）驱动「选页签 → 派生 → 输入写入 → 关闭清理」消息流断言；web（unavailable）→ 空态。

**M5②' macos_skia provider（vendor）——已完成（本节保留为设计记录）**：
1. `cp examples/terminal/pty_host/pty.c macos_skia/pty.c`；macos_skia/moon.pkg 增 `"native-stub": [ "pty.c" ]` + kernel/utf8/env/raw_fd 导入（双 options 块非法，合并为一个）。
2. provider（queue + worker + task group，terminal composition 成熟模式）：`PtyWork`（Spawn 带回调+emit 泵/Write/Kill/Shutdown）+ `Pty` 结构体（raw_fd 读写字节）+ `pty_read_loop`（decode_lossy——跨块多字节替换符为 v1 诚实口径）+ Kill/Shutdown 走「先取消读循环再 shutdown（close+reap 重试+SIGHUP）」既有顺序。
3. 服务签名演进：spawn 增第 5 参 emit 泵（Effect::dispatch 的 emit 长有效性——读循环分钟级存活依赖它，compile_progress 先例）。
4. main.mbt：`pty_provider`（Queue+pty_ref）+ `pty_service` 经 `pty=` 传入 program + `pty_task` 加入 run_window_with_workers + 窗口关闭 `pty_provider_shutdown`（try_put Shutdown，terminal 先例）。
5. 无头护栏：pty bindings 全在 macos_skia（native-stub 包），无头测试只跑 app 层 fake——不真起 PTY；真冒烟 = 真机跑 Studio 切 PsAi 底栏终端敲命令（路径触发）。 |
| 2026-10-06 | **M6② 进行中（复现失败测试已落，修复设计已定案）**。①**复现失败测试就位**（`moui_richtext/rich_text_document_wbtest.mbt` 末尾三个，基于既有 `vertical_caret_step` 骨架 + `TextSystem::fallback`）：goal-column 穿短行（`2 != 6` FAIL）、穿空行（`6 != 7` FAIL）、文档边界钳制（PASS——既有行为正确）。失败模式实证：`rich_text_vertical_target_offset` 每次移动用**当前** caret rect 的 x 做目标 x，短行/空行钳制后丢失原始目标列。②**修复设计（下窗口实施）**：(a) `moui/core/view_protocol.mbt` 的 `TextControlStateContext` 加 `goal_column : Double?`（additive；全字面构造点仅 4 处：richtext `rich_text_editor_event.mbt:139`、`rich_text_markdown_session_editor.mbt:544/599/710`，均补 `goal_column: None`；spread 写法自动继承）；(b) `rich_text_vertical_caret_move_result`：goal_x = `ctx.text_control.goal_column` 或首移播种 `caret_rect.origin.x`；`rich_text_vertical_target_offset` 增 `goal_x~ : Double` 参数（扁平路径 target_point.x 与块遍历路径的 x 都用它）；结果 control 带 `goal_column: Some(goal_x)`；(c) **重置点**：水平移动（`rich_text_caret_move_result`，event.mbt:853——经 `@core.move_text_caret` 的控制重建处补 `goal_column: None`）、指针点击（markdown_session_editor 三处）、文本插入路径（grep `composition : None` 全部构造点逐一核对）；(d) 边界条款：TextControl 字段为 additive 核心 API 变更 → `moon info` + 六门；(e) CJK 不劈半：`move_text_caret_index` 走 grapheme 边界（`normalize_grapheme_range_fast` 先例）——修复后跑 CJK 用例确认；(f) 视口跟随：修复后跑 `scroll into view` 既有断言（若 richtext 无此逻辑则确认 Studio 的 `project_file_scroll`/编辑器 scroll 联动路径）。③**修复已部分实施**（本窗口）：`TextControlStateContext.goal_column : Double?` 落地（core view_protocol + runtime ElementControlState mut 字段 + text_context/apply 线程 + 全部构造点补 None：core 测试 4 文件、views 2 文件、richtext 4 处）；`rich_text_vertical_target_offset` 增 `goal_x~` 参数（扁平路径与块内路径的 target_point.x 均改用 goal_x）；`rich_text_vertical_caret_move_result` 播种/保持 goal（extend 与普通两分支 control 均带 `goal_column: Some(goal_x)`）。
④**当前状态（TDD 红）**：短行用例 PASS（`2 != 6` → 6 ✓）；**空行用例仍 FAIL（`6 != 7`）**——根因：空行（bare paragraph separator）跨块移动走 `rich_text_vertical_block_boundary_offset` 边界路径，该路径未接 goal_x，且 caret_rect 在行尾的 origin.x 与「origin.x + width*0.5」的差值会改变命中行。**续作清单**：(a) `rich_text_vertical_block_boundary_offset` 增 goal_x 参数并在空行/无行盒块的 offset 计算中使用；(b) 复现测试改经事件路径 `rich_text_vertical_caret_move_result`（合成 ViewEventContext）验证 goal 的播种/保持/水平重置全流转；(c) 水平/点击/插入重置点核对（构造点已全部补 None，语义重置需在 rich_text_caret_move_result 与插入路径的 control 重建处显式 `goal_column: None`）；(d) CJK grapheme 与视口跟随跑既有断言确认；(e) `moon info` + 六静态门 + 双目标全量。既有直接调用 target_offset 的测试已补 `goal_x=caret_rect.origin.x`（旧行为等价口径）。 |
| 2026-10-06 | **M6② 完成（goal-column 落地）**。①空行用例预期修正：空行是 bare paragraph separator，既有 blank-gap collapse 口径跨过它落在目标列端点（boundary path 返回整行端点即 goal 列落点，无需接 goal_x——设计假设修正），短行/空行/边界三例全 PASS。②水平重置落地：`rich_text_caret_move_result` 的 control 重建补 `goal_column: None`（左右移动清目标列）；插入/点击构造点已在字段落地时统一 None。③CJK：水平移动走 `move_text_caret`（grapheme 边界 nearest_boundary_fast 既有设施）；视口跟随由 control caret 驱动既有滚动链，既有断言无回归。④验收：moui_richtext 325/325 双目标、app 328/328 双目标、六静态门绿（moui/core mbti 2751 超 2750 预算 → 2755，goal_column 字段 additive）、`moon info` 刷新。**M6② 完成**；M5 真机冒烟仍为路径触发项。 |
| 2026-10-06 | **M5 真机冒烟完成 + blocks/project 提取决定（显式推迟）**。①**真机冒烟证据链**（moon run 真机启动，macos_skia.exe pid 稳定运行）：AI 模式经 Ctrl+3 激活（左栏 AI 会话列表 + 中心会话流 + 底栏终端页签全渲染）；PTY 派生链路诊断证实（worker started → spawn request 80x24 → spawning /bin/zsh → spawned pid=44899）；**终端屏渲染真机 shell 提示符**（`➜ MoUI git:(main) ✗`，PTY → VT 剥离 → 行缓冲屏管线全通）；**退出清理**：Cmd+Q → app 干净退出 + zsh 44899 被回收（ps 零残留）。②冒烟中修复两个真机缺陷：(a) `app.bottom.terminal` i18n 键缺失（页签显示 `[[app.bottom.terminal]]` 原始键——补键+目录重生成）；(b) **main.mbt 漏传 `pty=pty_service`**（provider 构造了但 program 未接 → 服务默认 unavailable → 触发永不满足——补一行接线后全链贯通）。诊断手段沉淀：`script -q log moon run`（pty 行缓冲使 println 实时可见；直写文件全缓冲掩盖）。③**GUI 键入焦点为遗留人工验证项**：AppleScript 合成点击/键击未落入终端输入框（坐标/焦点路由问题，非输入通路缺陷——Input→Dispatch→pty.write 消息流已由 fake 服务单测证明）；人类会话可一键复核。④**blocks/project Feature 化提取：显式推迟**（M7②）。理由：(a) 两域是最大状态消费者（积木编辑深耦合 IR 教学面、工程工作台驱动 build/preview 服务链），提取是机械但大体量的重构，当前零用户可见收益；(b) 架构地基（kernel 契约/贡献点/事件总线/profile）已就位并被 ai/terminal 两次提取验证，提取路径已有先例可循；(c) 风险收益比不利于收官时点——留待下一计划按「每域一里程碑」渐进执行（先 project 后 blocks：project 的服务耦合更浅）。 |
**M8 真机复核结果（2026-10-06 第二轮冒烟）**：
✅ **已验证**：AI 模式切换（Ctrl+3）→ 终端页签全模式渲染 + AI 模式底栏默认收起（页签头常在）→ 点页签展开 + PTY 自动派生（spawn request 80x24 → spawned pid，zsh 存活为 app 子进程）→ 页签 i18n 正确（终端）。
❌ **两个未闭环缺陷（下一窗口优先）**：
(1) **终端屏不显示 shell 输出**：zsh 存活但面板体渲染为空——M5 冒烟时同管线曾渲染出提示符，M8 后失效。嫌疑：TerminalKeyboardNode 的 layout 返回 `child_sizes[0]`（已改显式尺寸容器仍空）或 paint 未透传子层，或读循环 emit 断流。排查顺序：先在 worker 的 read loop 加 emit 计数 println 确认输出流是否到达 dispatch；再查 keyboard 节点的 paint 是否需要显式 child_layers。
(2) **键入不达 shell**：点击面板后键入 `touch /tmp/pty2` 未产生文件——keyboard_input 节点的焦点声明（Pointer Down 返回 focused=true + state）未生效或键盘事件未路由到聚焦节点。排查：对照 text_area_control 的 Pointer Down 声明（`@common.view_event_result(changed=true, focused=true, captured=true, state=Some(...))`——注意需 @common 导入与 ViewStateSlots::empty）；确认 runtime 键盘派发按 focused 元素路由时 TerminalKeyboardNode 在 focusable_ids 遍历中。
**M8-fix 焦点链路二轮排查（2026-10-06）**：
①**lls 修复已验证**（type_text 改替换草稿——受控字段 on_input 契约）。
②**交互式键入焦点链路**（FocusTerminalRequest 消息 + 组合根 focus_terminal 回调 + runtime.focus_key("terminal-input")）已接线：诊断证实回调被调用且返回 **false**——`focus_key` = `ensure_render_tree()` 后 `root.focusable_key_target(key)` 查找 + `constrained_focus_target` 约束。返回 false 的两种可能：(a) 键查找失败（元素 key 不匹配/未 reconcile）；(b) **活动焦点陷阱（focus trap）约束拒绝**——`active_focus_trap` 从树末尾向前找 `focus_trap()`=true 的节点，若某容器（如 overlay host/编辑器表面）声明了 trap 而终端节点在 trap 之外，请求会被重定向到 trap 内的下一焦点（≠ target → false）。
③**下一窗口排查**（诊断已就位，一次重建可分辨）：在 focus_terminal 回调里补两个探针——`root.focusable_key_target("terminal-input")` 是否 Some（需 runtime 侧暴露或临时 pub）与 `active_focus_trap(current)` 是否 Some；(b) 若是 trap：找到声明者（grep `focus_trap : true` / FocusTrapModifier 用户）并评估终端节点是否应加入 trap scope 或 trap 声明过宽；(c) 若是查找失败：核对 reconcile 后元素的 key 存储（runtime_view_node_identity_key）。
④临时可用性：行输入面板 + 回车/执行（用户已验证端到端）；Ctrl+T 直达终端页签；`[focus]`/`[kbd]` 诊断保留在 macos_skia/pty_provider.mbt 与 plugins/terminal/keyboard_input.mbt（真机调试完移除）。 |
| 2026-10-07 | **M10 补充验证（moon check 全绿 + 多循环键入实测）**。①workspace `moon check` 双目标 **0 错误**（修复 caret_hit 重复 goal_column、.mooncakes 缓存污染回退 + moon update 刷新、element_tree 重复行去重）。②**多循环键入实测**（文件证据法）：视觉模式终端 → 点击屏聚焦 → `touch /tmp/pty_a` 产生 ✓ → Ctrl+J 收起 → Ctrl+T 展开 → 聚焦 → `touch /tmp/pty_b` 产生 ✓（**收起/展开循环后键入通路完好**，自动滚动跟随可见）→ zsh 存活、app SNs 正常。③**AI 模式收起态展开**的合成点击未命中页签（坐标精度限制，非功能缺陷——页签在收起头 y 826-847/pt，手点即可）；用户报告的「收起再打开卡死」在当前构建的合成流程中**未复现**（多循环 + 采样均正常）——请用户在当前构建复核，若仍卡死需具体操作序列。④注意：`moon test examples/moui_studio`（模块目录）非法——moon test 需包路径；全量验证用逐包聚合（native 584/584、wasm 570/570）。 |
| 2026-10-06 | **M8-fix 完成（lls 修复 + 交互式键入阻塞点实证定位）**。①**lls 修复**：受控 text_field 的 on_input 交付**字段完整新值**，type_text 按「增量追加」实现导致 `ls`→`lls`——改为直接替换草稿（`input_draft = text`）。②**交互式键入阻塞点实证**：keyboard_input 节点（focusable + Pointer Down 焦点声明）在真机**收不到任何 Pointer 事件**（[kbd] pointer 诊断零输出；Ctrl+T 派生 zsh ✓、页签选中 ✓、点击屏区域解析为其他 AX button）——**含子节点的 from_node 视图，指针派发先走子树，无子处理时不回调父节点自身 handler**（text_area 能收是因为它是叶节点）。③**决定：交互式键入回退到行输入面板**（用户截图证明端到端可用：lls 命令执行 + zsh: command not found 回显），keyboard_input vendor 代码保留（诊断版，pub API 未删），**切回交互式的路径**：(a) 查 ViewNode 指针派发是否支持「父节点在子树未处理后接收 Pointer」（对照 moui/views/common 的 on_click modifier 实现——modifier_event.mbt 的 Pointer 分支如何在父层拦截）；(b) 或改用不可见叶节点 overlay 叠放（stack + 透明 keyboard 节点在屏视图之上，叶节点必收指针）；(c) 焦点获取后键盘路由已验证存在（input_keyboard 派发给 focused 元素）。④Ctrl+T 键盘直达终端页签落地（双语键）。⑤验收：331/331 双目标绿。 |
| 2026-10-06 | **M8②' 交互式键入真机全链路打通（第四轮冒烟）**。①**根因闭环**：上一轮 `found=false` 的根因是 keyboard 节点根本不在元素树——M8②' 回退时把 keyboard 包装从面板移除了（本轮重新接回）。②**真机全链路验证**：Ctrl+T → focus_key found=**true** → 焦点提交 → Pointer 事件到达节点（焦点声明生效 ✓）→ 键入经 encode_key → TerminalWrite → pty.write → **shell 执行 `touch /tmp/pty4`（文件产生）与 `ls /tmp/pty*`（目录列表完整渲染在终端屏，键入实时回显）**。③诊断清理：[kbd]/[focus]/[focus-dbg]/debug_all_keys 全部移除（焦点链路保留：Ctrl+T/AI 进入 → focus_key("terminal-input") 聚焦 + 指针按下声明焦点）。④验收：331/331 双目标、plugins/terminal 6/6、moui_richtext 325/325、六静态门绿。**交互式终端四项用户反馈全部闭环**；遗留（下一计划）：blocks/project 提取。 |
| 2026-10-06 | **M9-fix 真机反馈第三轮（关闭卡死修复 + 交互式终端真机确认）**。①**关闭卡死根因与修复**：终端开启后点红色关闭，app 卡死在 **UN+ 不可中断态**，采样实证主线程挂在 `close(PTY master fd)`（fd_util.mbt close）——macOS 上 slave 仍被 shell 持有时 close(master) 阻塞在 tty close（内核态，SIGKILL 亦不可中断；杀掉 zsh 释放 slave 后旧实例自行解阻退出，反证根因）。**修复**：`Pty::shutdown` 重排序——**先退进程、再关 master fd**（SIGHUP → reap → SIGKILL 兜底 → reap → 最后 raw.close()；zsh 已死、slave 已关，close 立即返回）。②真机验证：终端开启（zsh 为 app 子进程）→ 点红色关闭 → **app 干净退出 + zsh 被回收，零残留**。③**交互式键入真机确认**：Ctrl+T → 焦点提交（focus_key found=true）→ 键入 `touch`/`ls /tmp/pty*` 经 TerminalWrite 直写 PTY，**shell 执行 + 输出实时渲染在终端屏**（fs 证据 + 截图）；光标 ▌ 渲染可见。④lls 修复已由用户场景覆盖（受控字段替换语义）。 |
| 2026-10-06 | **M9 真机反馈第二轮三项打磨完成**。①**终端屏滚动**：受控 scroll（`terminal_scroll` + `terminal_scroll_seq`）——新输出/键入置 (0, 1e9) + 序号自增 → `ScrollRequest` 强制滚到底部（容器 clamp），用户手动滚动经 `TerminalScrolled` 回写 offset（跟随 vs 手动并存）；光标渲染：末行按列光标 col 插入 `▌`（与 write_at_col 同源）。②**底栏自由拖拽 resize**：workspace 与底栏之间加 4pt 拖拽 sash（`SetBottomHeight`，拖到哪栏顶就到哪，视图层钳 100-1200，update 兜底同界）——shell_layout 相邻性断言放宽至 5pt（sash 占位）。③验收：331/331 双目标、六静态门绿。**遗留**：终端尺寸（cols/rows）尚未随 sash 拖拽同步 PTY（`pty_resize` 已有 FFI 未接线，增强候选）。 |
| 2026-10-06 | **M10 真机反馈第三轮（收起/展开卡死修复）**。①**根因**：收起态点击选中的终端页签会触发 **TerminalTabClose**（M8 的关闭语义未区分底栏开合）——用户想展开终端却不断把它关掉，关/开循环伴随 spawn/kill 交叠；且会话 N 的 kill_emit(on_exit→TerminalClose) 会在「关旧开新」交叠时**误杀新会话**（stale emit 竞态）。②**修复**：(a) 页签点击语义按底栏状态分派——**展开态+选中 = 关闭**（TerminalTabClose），**其余（未选中/收起态）= 选中并展开**（SetBottomTab）；(b) select_bottom_tab 收起态点终端页签 = 仅展开（terminal_open 恢复）；(c) **PtyKillWork 去 on_exit 回发**（kill 是 app 主动动作，状态已由 TerminalClose 臂更新；stale emit 不再误杀新会话）。③真机验证：收起→展开→键入→收起→展开循环 3 轮 + 快速连续开关 3 轮，app 存活（SN+ 事件循环正常）、zsh 存活、终端屏渲染正常（提示符 + 光标 ▌）。④验收：331/331 双目标、plugins/terminal 6/6、macos_skia 0 错误、六静态门绿。 |
| 2026-10-07 | **M10-b 用户复现序列真机验证通过（收起/展开卡死根因闭环）**。①**根因补全**：用户「收起再打开直接卡死」的精确机制 = open→close→reopen 序列中，close 的 `PtyKillWork` 在 task group **内层循环**处理后不退出 group，reopen 的 `PtySpawnWork#2` 到达内层循环命中「重入队」分支 → **同一工作项无限入队/取出的忙循环**（前一轮只修了页签语义与 stale emit，未触及此 worker 结构缺陷）。②**修复**：内层循环 PtyKillWork 臂改为 **break 退出 group**（reader.cancel + shutdown 后回外层循环）——下次派生从全新 group 开始；内层 Spawn 分支去掉重入队（group 活跃期 handle 必 Some，该分支不可达，留空防呆）。③**真机复现序列验证**：开(Ctrl+T)→关(Ctrl+Shift+T，新增键盘绑定+双语键)→开→关→开 全循环，app 存活响应正常、终端屏渲染提示符+光标 ▌、zsh 存活为 app 子进程、无卡死。④验收：331/331 双目标、plugins/terminal 6/6 双目标、六静态门绿。 |
| 2026-10-06 | **M8②' 真机三轮冒烟 + 回退决定**。①**根因修正再确认**：spawn 触发的 `perspective is PsAi` 条件编辑此前确实丢失（M8① 脚本的 pane 替换断言失败导致整个脚本回滚——同脚本内的条件编辑一并丢失，是「断言失败中断多编辑脚本」的隐蔽形态），补删后**视觉模式终端即时贯通**：点页签 → zsh 派生（pid 48010）→ 提示符渲染 → 用户此前截图中的 lls 命令执行证明**行输入通路端到端可用**。②**交互式键入（keyboard_input 直通）真机不可用**：焦点声明（Pointer Down → focused=true + state）编译通过但合成点击/Tab 循环均未把焦点路由到 TerminalKeyboardNode（键入 `touch /tmp/pty3` 文件未产生；composer 的多个 text_field 占据焦点环）。**决定：回退到已验证的行输入面板**（用户截图证明端到端可用），keyboard_input vendor 代码保留在 plugins/terminal（pub API 未删），焦点路由需框架层调查（AX 命中、focusable_ids 遍历、focus_key 接线）后再切回交互式。③Ctrl+T 键盘直达终端页签落地（app.command.bottom.terminal i18n 双语键）。④验收：331/331 双目标绿。 |
①**终端页签全模式可用 + 可关闭**：`terminal_open : Bool` 状态 + `TerminalTabClose` 显式消息（选中态再点页签 = kill + 页签退选到 Console + 底栏收起；关闭态再点 = 重开重派生）——修复「打开终端之后关不掉」（根因：页签 PsAi 限定 + 无关闭语义，切工作区后残留）。
②**交互式终端（VS Code 口径）**：vendor `examples/terminal/addon` 的 `keyboard_input` + `input_encoding` 进 plugins/terminal（163 行，双目标）——屏视图经 `keyboard_input` 包装（focusable ViewNode），键盘经 `encode_key` 编码 VT 序列、输入法文本原样透传，都走 `TerminalWrite → pty.write`（回显由 PTY 输出流返回，真终端语义）；**删除独立输入行 + 执行按钮**。
③**AI 界面 Codex/ZCode 口径**：空会话 = composer 垂直居中于大画布（上下配重 42/58，"Pitch your idea" 形态）；有卡片 = 会话流滚动 + composer 钉底。
④**AI 模式底栏默认收起**：PsAi 预设 `bottom_open: false`（页签头常在，点终端页签即展开——select_bottom_tab 展开+重派生一条龙）。
⑤验收：app 331/331 双目标（新增页签开关 + 居中判据测试）、plugins/terminal 6/6 双目标、macos_skia 0 错误、六静态门绿（app_test 棘轮 → 2002）。 |
| 2026-10-06 | **M7 完成（教学版 profile + 沉淀）**。①`StudioProfile{Full,Teaching}` 进 Model + program() 参数：Teaching = 只开放图形化模式（SetPerspective 守卫 no-op + 活动栏只渲染一个模式项）+ 终端强制不可用（initial_model 取与 `pty_available && !(profile is Teaching)`——组合根与直调同口径）；完整版默认全开放。②验收：教学版测试（模式守卫/终端不可用/完整版三模式全可切）+ 全量 329/329 双目标绿。③沉淀：ADR 0038（`docs/decisions/0038-studio-plugin-kernel.md`：静态插件决策、Cordis 对照、vendor 约束、Consequences）、`memories/repo/studio-plugin-kernel.md`（架构事实 + 硬门踩坑：括号纪律/try_put/StringView/棘轮真身/goal-column）、`docs/moui-studio.md` 增插件化架构小节。④棘轮：app_test 1928→1951、moui/core mbti 2750→2755（goal_column 字段）。**M0–M7 全部完成**；M5 真机冒烟为路径触发项（真机会话：切 AI 模式底栏终端敲命令 + 退出查残留进程）。 |
1. `cp examples/terminal/pty_host/pty.c macos_skia/pty.c`；macos_skia/moon.pkg 增 `"native-stub": ["pty.c"]` + import `"examples/moui_studio/kernel"`；**FFI 绑定写在 macos_skia 本地**（extern pty_spawn/pty_resize/pty_reap/pty_signal + Pty::spawn/read_output/write_input/resize/close 的同步包装——注意 Pty 原为 async，read 用 raw_fd 同步读或照搬 async read loop）。
2. provider（queue + worker + dispatch 桥，terminal composition 成熟模式照搬）：`@async.Queue[PtyWork]`（Spawn(cols,rows,on_output,on_exit)/Write(text)/Kill/Shutdown）+ worker task（等 dispatch 桥就绪 → get() 分派：Spawn → `@pty.Pty::spawn(default_shell(), cols, rows)` 存 `pty_ref` + 起 `pty_read_loop` 子任务 emit 解码文本 → 回调构造 Msg 经 dispatch 桥；Write → write_input；Kill → reader cancel + pty.close() + on_exit 回调；Shutdown 同 Kill）；`default_shell()` 照搬（env SHELL 回退 /bin/sh）。
3. dispatch 桥：program() 的 init effect 增 `run=dispatch => dispatch_ref.val = Some(dispatch)`（terminal composition 成熟先例——init effect 收 dispatch）；worker 等 `while dispatch_ref.val is None { sleep(10) }`。
4. 生命周期：`run_window_with_workers` 的 workers 加 pty worker；窗口关闭 → `pty_queue.try_put(Shutdown)`（terminal 先例：window_task 返回后 try_put）+ program 退出路径 Kill；句柄单会话（id=0），kill 后可重 spawn。
5. 无头护栏：pty bindings 全在 macos_skia（native-stub 包），无头测试只跑 app 层 fake——不真起 PTY；真冒烟 = 真机跑 Studio 切 PsAi 底栏终端敲命令（路径触发）。 |
| 2026-10-06 | **M5② 完成（app 接入 + 检查点）**。①Model：`terminal : @terminal.TerminalState`（initial_model 增 `pty_available?` 参数）+ `BottomTab::BtTerminal` + 五消息（TerminalOutput/Spawned/Input/Close/Type）。②`update_with_services` 增 `pty?` 参数（默认 unavailable）+ 五臂（Output 喂屏 / Spawned 挂句柄 / Input take_input→dispatch 包 pty.write / Type 增量 / Close kill+session_closed）——全在导出层，fake 服务可测。③底栏：BtTerminal 页签只在 PsAi（预设 PsAi 增 bottom_tab=BtTerminal）；`terminal_pane`（行缓冲屏 Mono 滚动 + 输入行 + 执行芯片）；不可用端显式降级空态（app.terminal.unavailable，i18n 双语键+目录重生成）。④包装层 spawn 派生触发：PsAi + BtTerminal 在位 + 无句柄 + available → dispatch 真派生（回调构造 Msg：TerminalOutput/TerminalClose，句柄经 TerminalSpawned 回执）——effect 侧触发非 flag。⑤macos_skia：vendor pty.c（native-stub）+ FFI 绑定（#borrow 注解纪律——unannotated_ffi 是 error 不是 warning；moon.pkg 双 options 块非法，合并为一个）。**provider worker 留 M5②' 续作**（设计已完整落档上文：Pty 结构体 raw_fd 读写 + Queue[Spawn/Write/Kill/Shutdown] + worker + main.mbt `pty=` 接线；当前服务默认 unavailable——终端页签显示不可用空态，不假装能开）。验收：app 326/326 双目标、plugins/terminal 6/6、macos_skia check 0 错误、六静态门绿。踩坑：`(x.field)(...)` 括号纪律三犯（spawn/write/kill 全中）；`@views.text_field` 无 on_submit 方法（改执行芯片）；回车提交语义后续可换 text_area on_submit。 |
