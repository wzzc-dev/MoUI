# Plan: MoUI Studio AI 模式改造——对白转录工作台

- **Status**: active（M0–M6 已全部落地；真机交互走查待人工会话复核）
- **Goal**: 把 AI 模式从「Agent 工作卡投影(280px 小卡、prompt 不回显)」改造为对白
  转录工作台:右对齐用户气泡 + AI 消息(markdown)+ 工作卡时间线、composer 信息层
  (工程/模型/姿态)、会话列表(相对时间/分组/置顶/搜索/快捷键)、native 会话落盘。
  参考形态:Codex/ZCode 等成熟 agent 面板的对话态与空态两图(对话态 = 全幅对白
  时间线 + composer 钉底;空态 = 上下文芯片 + 提示行 + composer 垂直居中)。
- **Non-goals**: 麦克风/语音;图片与文件附件;插件市场(ADR 0038 静态架构);
  Automations/Customizations 导航区(ZCode 专属产品面,无对应物);git 工作树/分支
  读数(Studio 无 git 集成);Autopilot 全放行(与逐提案闸门哲学相反,只做姿态读数);
  真实 provider SSE 流式(provider_native 另行演进);Markdown 链接/表格富渲染
  (维持诚实降级)。

## 已核实事实(2026-10-07 探索,实施直接采信)

- prompt 不进任何记录:`app/update_ai.mbt:4-39` 只消费 prompt_draft;中心态线程被
  钳在 280px 小卡内(`ai_card_body`/`ai_center`)。有生产推送点的卡只有
  CardDiff(`proposal_from_completion` → `push_proposal_thread_card`,
  `update_ai.mbt:154`)与 CardExplanation(`app.mbt:1570-1581`);
  CardPlan/CardSideEffect/CardError 零生产点。
- `plugins/ai/ai_state.mbt`:`AiSession{title,prompt_draft,cards,card_seq,
  proposal_history}`;`AiSessions` 有 create/switch/remove/amend/append_to_last_card/
  list_entries;默认名「会话 N」单调序号;无 rename/置顶/时间戳/工程关联。
  卡片上限 `AI_CARD_LIMIT=24`。
- 墙钟:`HostWallClock` 在 `moui/runtime/wall_clock.mbt`(app 禁止 import runtime)。
  按 mo_desktop 先例(`examples/mo_desktop/app/program.mbt:5` + 组合根
  `composition.mbt`)在 app 自定义 StudioClock struct,由两个组合根映射各自 FFI
  注入 `program(wall_clock=…)`,TimerSource 1s 订阅派 ClockUpdated 写 Model.clock。
- 剪贴板:`AppServices::clipboard().write_text` 先例 `app.mbt:220-226`
  (CopyArtifactPath)。
- 滚动:`scroll_view(offset?/on_scroll?/request?)`;滚到底先例 = 终端
  (`ide_shell.mbt:1347-1364`,ScrollRequest offset (0,1e9) + seq 自增)。
- 文件持久化:FileServices read/write_text + `ServiceTask.effect(Msg)` 三段式先例
  = 导出(`app.mbt:856-935`);web 端 TextFile 语义不可靠 → 持久化 native-only、
  web 显式关闭(export_available 同口径)。
- 键盘:`program_commands.mbt` 的 bind() 每键注册 meta+control 双变体;Key 是
  String,"n"/"f" 空闲;Ctrl/Cmd+K 已被命令面板占用,保持不动。
- 图标:`IconName`(`style_api.mbt:224-256`)无 Copy/Pin——复制用 Clipboard,
  Pin 需新增 IconName + icon_path(views 层小改,带测试)。
- i18n:`app/i18n/{zh-Hans,en}.json` + `scripts/generate-i18n-catalogs.mjs --check`;
  generated 文件有行数棘轮(`checks/source-file-policy.json`),app_test.mbt 也有棘轮。
- 既有测试锚点:`ui_regression_wbtest.mbt:198-208`「空闲卡 ≤140」、
  `ai_bar_layout_wbtest`、`shell_layout_wbtest:1055-1171`——M2 改中心态时迁移。

## 里程碑

### M1 时钟 + 数据模型
- app 定义 `StudioClock{year,month,day,hour,minute,second}`(不 import runtime,
  默认常数钟,测试可手动置 `Model.clock`)+ TimerSource 1s 订阅 `ClockUpdated`。
- `AiCard` 加 `at : Int`(civil_seconds 戳);`AiCardKind` 加 `CardUserPrompt`。
- `AiSession` 加 `project/pinned/updated`;`AiSessions` 加 rename/set_pinned
  (经 AiSessionMsg + 既有 scope 委托,死消息门合规)。
- `composer_run` 提交时默认名会话以 prompt 首行(~18 字)置题、盖 active_project 工程戳。

### M2 对白转录(核心)
- `ComposerRun` 路由前 push `CardUserPrompt`(body=prompt 原文,at=now)。
- `ai_center` 重写:空会话 = composer 居中(42/58)+ 提示行;有内容 = 全幅时间线
  scroll_view + composer 钉底。
- 时间线:用户气泡右对齐(强调色淡底、宽 ≤70%)+ [复制][编辑](回填草稿)+ HH:MM;
  AI 消息(markdown_blocks_view)+ [复制][重发](该轮用户文本回填并重派 ComposerRun)
  + HH:MM;diff 卡保留卡内 [采纳][拒绝];prompt_error 与真实 provider 失败路由为
  CardError 卡(给死种类真实 push 点);相邻工作卡成「已工作 N 秒」折叠组。
- 滚动:on_scroll 回写 + 新内容自动贴底 + 离底浮动 (↓)(ScrollRequest 模式)。
- 右栏停靠/底栏 BtAi 紧凑宿主不动(仍走 ai_card_body);「空闲卡 ≤140」断言迁移为
  紧凑宿主口径 + 新增 center 转录预算测试。

### M3 composer 信息层
- 输入盒上方上下文芯片行(工程芯片 = active_project 名;模型芯片 = 「离线模型」或
  provider config 的 model 名,点击走 studio.settings;无内容 0 高、宽卡 ≥420 才显示)。
- 脚注姿态读数「待审计 N」(pending_ai_cards>0 时警告色)。
- 空态提示行「AI 只产出结构化提案——逐条 diff,采纳前不动程序」。
- 四模式胶囊与 ghost 停靠/历史保留。i18n 双语 + 目录重生成。

### M4 左栏会话列表(ai_session_list 重写)
- 区头「会话 + [新建](⌘N 徽标)+ [搜索]切换过滤行」(title 子串过滤,本地)。
- 置顶组 + 按 project 分组(组头计数徽标),组内按 updated 倒序。
- 行 = 标题 + 相对时间(刚刚/N分前/N小时前/N天前,text_with 插值,30s timer 刷新)
  + hover 显示 ✕ 与置顶切换(on_hover 框架能力已有);改名走既有对话框模式。

### M5 持久化(native-only)
- `moui.studio.ai-sessions v1` JSON codec 纯函数放 plugins/ai(往返测试;未知
  version 结构化拒绝)。
- `program()` 新参 `sessions_store_path?`;macos 传 `.studio/ai_sessions.json`
  (登记根 .gitignore);web 不传 = 关闭且 UI 无入口。
- init 加载(read_text.effect,坏文件 with_notice 不静默);结构性事件(新建/切换/
  删除/置顶/提交/采纳/拒绝/流式完成)后保存——草稿键入不触发保存也不盖 updated 戳。

### M6 键盘 + 视觉收口
- Ctrl/Cmd+N 新建会话、Ctrl/Cmd+F 切过滤行(bind 双修饰键惯例,新命令同步
  studio_commands 表);Ctrl/Cmd+K 命令面板不动。
- `IconName` 加 Pin(+icon_path,带测试)。
- 中心态 composer 圆角 10 + 用户气泡强调色淡底(右栏/底栏嵌入宿主维持扁平——
  原「扁平」实测口径限定于嵌入面板)。
- i18n/app_test 棘轮按需抬升;六静态门全绿。

## 硬约束

- 每个新 Msg 变体必须有真实构造点(死消息门);命令面板命令表同步。
- app 包不 import moui/runtime;时间/文件/剪贴板全部走组合根注入闭包 + ServiceTask。
- 双目标(native + wasm-gc)全绿;web 缺能力时显式降级,不出现假按钮。
- 新断言写完故意破坏一次确认会红;每步跑
  `moon test examples/moui_studio/app|plugins/ai --target native|wasm-gc`;
  收尾跑六静态门 + i18n --check + sync_kernel --check(未动 kernel 也跑,确认零漂移)。

## 验收

1. 双目标测试全绿 + 六静态门绿。
2. 真机走查(native):提交 → 用户气泡回显 → 流式回复 → diff 卡采纳 → 审计落账;
   重启后会话恢复、相对时间正确、置顶/分组/改名保持;Ctrl+N/Ctrl+F/Ctrl+K、
   搜索过滤、删除、↓回底可用。
3. web 构建绿:持久化/墙钟缺席时显式降级,无死 UI。

## 实施记录（2026-10-07）

- M1–M6 全部落地：app 357/357、plugins/ai 12/12、markdown 8/8、kernel 11/11、export 24/24
  （均双目标）；六静态门 + 死消息门 + i18n --check + sync_kernel --check 全绿；
  web_wasm wasm-gc 构建出片；native 组合根真机启动探针通过（进程稳定渲染后干净退出）。
- 相对时间刷新复用 AI 模式的 1s ClockUpdated 订阅，未另加 30s 计时器。
- 会话列表整块从 ide_ai.mbt 拆到 app/ai_sessions_pane.mbt（ide_ai 1814 行触线）；
  AI_SESSION_HEADER_HEIGHT 随块落位。
- Pin 图标新增 IconName.Pin + icon_path（moui/views），带 24×24 视图框边界测试；
  会话行置顶用图标而非文字字形（避免字体缺字形的渲染风险）。
- 本轮发现并修复一处**既有** kernel 快照格式漂移（kernel_*.mbt 的 moon fmt 风格，
  sync_kernel 已同步，--check 转绿）。
- 待人工验证：真机交互走查（提交→气泡→流式→采纳；重启恢复；Ctrl+N/F/K 实测）。
  后台会话截获原生窗口受限（见 memories/repo/moui-studio.md 的既有记录）。

## Decision log

| 日期 | 决定 |
|---|---|
| 2026-10-07 | 时间线复用 AiCard 管线(新 CardUserPrompt 种类)而非新增 messages 数组——push/amend/seq/上限/流式追加全部复用,手术面最小。 |
| 2026-10-07 | 墙钟走「app 自定义 StudioClock + 组合根映射注入」,不 import runtime(P 边界);测试用常数钟手动置 Model.clock。 |
| 2026-10-07 | 持久化 native-only:web 的 TextFile 写语义不可靠,与 export_available/compile_track 同口径显式关闭。 |
| 2026-10-07 | updated 戳与持久化保存只在结构性事件触发,草稿键入不触发——避免每键写盘与会话列表排序抖动。 |
| 2026-10-07 | 写盘走事件总线:结构性事件 push EvAiSessionsDirty → 组合根按路径注册监听器翻译为写盘请求——web/裸测试组合根不注册,排空零开销。 |
| 2026-10-07 | 中心态 composer 圆角 10、嵌入宿主扁平——「扁平」实测口径限定于嵌入面板,与截图对齐只作用于 AI 模式大画布。 |
| 2026-10-07 | 会话行置顶用新增 IconName.Pin,不用 ★ 文字字形(字体覆盖风险);图标带视图框边界测试。 |
