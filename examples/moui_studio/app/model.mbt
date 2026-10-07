///|
/// MoUI Studio TEA 模型：程序 IR + 界面语言 + 三模式 + 运行态 +
/// 待采纳提案 + provider 会话内存。纯数据，无服务无视图。

///|
pub(all) enum Mode {
  ModeDesign
  ModeBlocks
  ModeCode
  ModePreview
  ModeHelp
  ModeRun
}

///|
pub(all) enum ProviderMode {
  Fake
  Real
}

///|
/// 产物旁路动作的种类：决定成功 toast 的文案。
/// 三个动作共用一条回执消息（`ArtifactActionDone`），来源必须显式带上。
pub(all) enum ArtifactAction {
  ArtifactCopy
  ArtifactReveal
  ArtifactLaunch
  /// 时间线消息复制（对白转录）：复用同一条回执通道，文案区分
  ArtifactAiCopy
}

///|
/// 双轨：解释轨（沙箱指令机）与编译轨（真编译闭包执行面）。
pub(all) enum RunTrack {
  Interpret
  Compile
}

///|
/// 运行态：当前子程序 + 指令机状态 + 勾选框 UI 态。
/// checks 只在 app 层（运行期视觉状态，不进指令机语义）。
pub(all) struct RunModel {
  handler_label : String
  state : @studio_lang.RunState
  checks : Map[String, Bool]
  // 单步模式：为真时 RunTick 不自动推进，仅 RunStep 走一条指令
  single_step : Bool
}

///|
/// 编译轨运行态：`compiled_runtime` 的 Runtime 本身携带跨事件活状态
/// （变量/文本/行/选中/审计/闸门），因此与解释轨的 RunModel 完全独立，
/// 两轨可以各自停在各自的位置，互不干扰。
pub(all) struct CompiledRun {
  handler_label : String
  runtime : @compiled_runtime.Runtime
  checks : Map[String, Bool]
}

///|
/// 待采纳提案：diff 预览 + 校验结果（valid=false 时展示全部原因）。
pub(all) struct PendingProposal {
  proposal : @proposals.ProposalV1
  diff : Array[@proposals.DiffEntry]
  /// 代码真源文本 diff（M6②）：handlers.mbt/form.mbt 前后逐行 ±，
  /// 显示层展示的是代码 diff 而非结构化条目。
  code_diff : Array[(String, String)]
  summary : String
  errors : Array[String]
  valid : Bool
}

///|
/// 撤销深度上限（快照式 undo 栈，超过丢弃最旧条目）。
pub const UNDO_DEPTH : Int = 50

///|
/// 最近修改保留条数（设计稿列表可见 4 条；多留几条供滚动）。
pub const RECENT_LIMIT : Int = 24

///|
/// 运行审计保留条数（会话内时间线，超出丢最旧）。
pub const AUDIT_LIMIT : Int = 200

///|
/// Console 日志保留条数。
pub const LOG_LIMIT : Int = 400

///|
/// 同屏 toast 上限（旧的在渲染层取最近 N 条）。
pub const TOAST_LIMIT : Int = 3

///|
/// toast 自动消失秒数（ToastTick 每秒老化一次）。
pub const TOAST_SECONDS : Int = 4

///|
/// 一条 toast：文案 + 是否警告色 + 已存活秒数。
pub(all) struct ToastEntry {
  text : String
  warning : Bool
  age : Int
}

///|
/// AI 会话卡保留条数。
pub const AI_CARD_LIMIT : Int = 24

///|
/// 积木画布单块行高（分类条滚动定位与命中共用）。
pub const BLOCK_ROW_HEIGHT : Double = 40.0

///|
/// 撤销条目：变更前的编辑快照（程序 + 选中态 + 代码草稿）。
/// coalesce_key 非空且与栈顶相同时连续同类编辑合并为一个还原点。
pub(all) struct UndoEntry {
  program : @ir.StudioProgram
  selected_control : String
  selected_handler : String
  code_draft : String
  coalesce_key : String
}

///|
pub type ProposalRecord = @ai.ProposalRecord

///|
/// 设计画布拖拽态：被拖控件 + 拖拽种类（移动/缩放）。
pub(all) struct DragState {
  control : String
  kind : DragKind
}

///|
/// 积木拖拽态：同层重排——list_path 定位语句列表，from/to 是
/// 兄弟下标与落槽（落槽 = 落在原下标 to 的语句之前）。
pub(all) struct BlocksDragState {
  /// 源语句所在的语句列表路径（拖动前算定）
  list_path : Array[Int]
  /// 源语句的**完整 IR 路径**（链下标在跨层移动时不够用：目标列表要用
  /// 路径寻址，而链下标随展开的装饰块变化）。
  from_path : Array[Int]
  from : Int
  /// 落槽位置。`to_list` 为空时是「同列表内重排」语义。
  to : Int
  /// **落点所在的列表路径**（可能跨层：拖进 C 形块的洞里）。
  /// 空数组 = 顶层。与 `list_path` 不同即为跨层移动——
  /// 那走 `@blocks.move_stmt_at`，同层仍走 `reorder_stack`。
  to_list : Array[Int]
  /// 当前落点**是否被语言规则接受**（`@blocks.drop_accepts_stmt`）。
  /// 拖拽过程中据此画拒绝反馈；松手时也据此决定要不要真的写 IR。
  valid : Bool
}

///|
/// 拖拽种类：移动（带按下点相对控件原点的偏移，拖拽跟随不跳变）/
/// 缩放（从该角拖拽，对角固定）。
pub(all) enum DragKind {
  Move(Int, Int)
  Resize(@ir.DragCorner)
}

///|
/// 中心工作区：可视化工作区（Live App / 积木多窗格）/ 代码工作区 / 空舞台。
/// 与旧 Mode 的关系：Mode 仍是「进入哪种工作台」的粗粒度路由（含运行、
/// 帮助、MoonBit 预览三个全屏页），WorkSpace 是可视化/代码两个编辑工作区
/// 内部的窗格编排状态——设计稿把三视图统一进一个可视工作区，切换成本从
/// 「换模式」降为「点图标」。
pub(all) enum WorkSpace {
  WsVisual
  WsCode
  /// 工程预览(M1):headless 帧重放画布(M2/M3 加 web/native 模式)
  WsPreview
  WsEmpty
} derive(Eq)

///|
pub extend WorkSpace with Eq::{not_equal, equal}

///|
/// 预览模式(M2-2):画布快览(模式一)/ web 实时(模式二,webview)。
pub(all) enum PreviewMode {
  PmFrame
  PmWeb
}

///|
/// 组合 profile（M7）：完整版（默认）/ 教学版（只保留图形化模式——
/// 无终端、无工程、会话精简；这是「无特权内核」的验收证明：教学版 =
/// 组合根少注册能力与模式，产品功能自洽地缺席而非崩溃）。
pub(all) enum StudioProfile {
  Full
  Teaching
} derive(Eq)

///|
pub extend StudioProfile with Eq::{not_equal, equal}

///|
/// 左栏视图：程序结构树 / 本地数据 / 工程资源管理器 / AI 会话列表 / 收起。
pub(all) enum LeftView {
  LeftTree
  LeftData
  LeftProject
  /// AI 会话列表（M3，AI 模式的预设左栏）
  LeftAiSessions
  LeftHidden
}

///|
/// 右栏 Context 页签：属性 / 状态 / 数据 / 动作 / 依赖 / 运行时。
pub(all) enum ContextTab {
  CtxProps
  CtxState
  CtxData
  CtxActions
  CtxDeps
  CtxRuntime
}

///|
/// 底栏页签：运行审计 / Console / 问题（诊断汇总）/ AI 输入条 / 终端。
/// 原来是 `bottom_audit : Bool` 两态开关，问题面板加入后升级为枚举。
///
/// `BtAi` 是**输入条的底栏落点**（`AiAnchor::AiBar`）：输入条与三个只读
/// 面板并列成页签，占用同一块底栏高度，不额外占据中心列。选中它时底栏
/// 里画出 composer（见 `ide_bottom_bar` 的 body 分派）。
pub(all) enum BottomTab {
  BtAudit
  BtConsole
  BtProblems
  /// 工作区全文搜索（G4 F3）
  BtSearch
  BtAi
  /// 真终端（M5，AI 模式专属页签）
  BtTerminal
}

///|
/// 树上的「非控件」选中目标：窗体 / 变量 / 数据文件。
///
/// 为什么单列一个类型：`selected_control` 与 `selected_handler` 是两条
/// 正交的字符串槽（控件用名字、子程序用 `控件@事件`），但窗体、变量、
/// 数据文件**没有可寻址的控件实体**——硬塞进 `selected_control` 会让
/// `find_selected_control` 查不到（右栏退化成「什么都没选」），还与控件名
/// 有撞名风险。用一个显式枚举表达「选中的是哪一个非控件对象」。
///
/// **互斥纪律**：任一时刻只有一条槽有效，所有入口经 `select_target` 与
/// `select_control_by_name` 单一漏斗（见 `update_selection.mbt`）。此前
/// `SelectHandler` 忘了清 `selected_control`，于是「点了子程序、右栏还显示
/// 上一个控件的属性」——正是缺少漏斗的直接后果。
pub(all) enum SideTarget {
  /// 窗体本身（标题 / 设计尺寸）。
  SideWindow
  /// 程序变量（名称 / 初值）。
  SideVariable(String)
  /// 本地数据条目（列表/表格控件的行，或变量集合）。
  SideData(String)
  /// **自定义积木**（Scratch 的「我的积木」）：名称 / 参数 / 函数体。
  /// 选中它之后右栏显示函数名，积木画布进入该函数的体（`current_handler`
  /// 的对称概念——`current_func`）。
  SideFunction(String)
}

///|
/// 输入条模式（设计稿 `#modeSeg`：修改 / 生成 / 解释 / 修复）。
/// 设计稿里它只是个高亮切换，没有行为；这里给它真语义——决定「发送」
/// 走哪条既有通道，所以四个模式都不引入新的执行路径：
/// - 修改/生成 → GenerateProposal（生成是「以空程序为基」的修改）
/// - 解释      → ExplainHandler（本地确定性讲解，native 可走真实模型）
/// - 修复      → RestoreCodeDraft（把代码草稿重置回 IR 的规范渲染）
pub(all) enum ComposerMode {
  ComposeEdit
  ComposeGenerate
  ComposeExplain
  ComposeRepair
  /// 纯聊天（G1）：不走提案校验链,回复为普通 markdown 消息
  ComposeChat
} derive(Eq)

///|
pub extend ComposerMode with Eq::{not_equal, equal}

///|
/// 任务模式（M2 三模式工作台）：活动栏唯一职责——「我在哪个任务里」。
/// 每个模式绑定一套全区域预设（左栏/中心/右栏/底栏页签，见计划的预设表），
/// 切换 = 一次性应用预设；模式内的临时收放不回写预设（契约 3）。
pub(all) enum StudioPerspective {
  /// 图形化编辑：左栏结构树 / 中心可视化（画布/预览胶囊）/ 右栏检查器 /
  /// 底栏 审计│Console│问题│AI 输入
  PsVisual
  /// 代码编辑：左栏工程文件树 / 中心代码编辑器 / 右栏 AI 停靠卡（VS Code 口径）/
  /// 底栏 审计│Console│问题
  PsCode
  /// AI 工作台：左栏会话列表(M3) / 中心全幅会话流 / 右栏默认不显示 /
  /// 底栏 真终端(M5)
  PsAi
} derive(Eq)

///|
pub extend StudioPerspective with Eq::{not_equal, equal}

///|
/// 右栏当前视图：取代旧 `right_visible`（布尔）与 `ai_anchor` 的 AiDocked 档
/// 的 2×2 组合——单一枚举消除两状态互拉（历史上出过「收起底栏 AI 自己跑
/// 去右栏」的事故，根因就是两个独立状态描述同一件事）。

///|
/// AI 工作区面板（RvWorkspace）的页签：更改（提案历史）/ 文件（工程树）。
pub(all) enum RightPanelTab {
  RpChanges
  RpFiles
} derive(Eq)

///|
pub extend RightPanelTab with Eq::{not_equal, equal}

///|
pub(all) enum RightView {
  /// Context 检查器占满右栏（AI 回落底栏页签）
  RvContext
  /// Context 页签 + AI 卡钉底（原 AiDocked 的布局）
  RvAi
  /// AI 模式工作区面板：更改（提案历史）/ 文件（工程树）双页签
  RvWorkspace
  /// 右栏不占宽（AI 回落底栏页签）
  RvHidden
} derive(Eq)

///|
pub extend RightView with Eq::{not_equal, equal}

///|
/// AI 卡与提案历史的类型定义已迁入 AI 插件包（M3 会话切片化：
/// `plugins/ai/ai_state.mbt`）；app 保留公开别名，既有引用零改动。
pub type AiCardKind = @ai.AiCardKind

///|
pub type AiCard = @ai.AiCard

///|
/// 运行审计条目种类：通过 / 运行 / 副作用待确认 / 错误。
pub(all) enum AuditKind {
  AuditOk
  AuditRun
  AuditWarn
  AuditError
}

///|
/// 运行审计条目：时间线上的一条事实（编译/启动/绑定/副作用/错误）。
/// 副作用卡（AuditWarn）是**告知 + 跳转**，不是第二条外发通道——
/// `提交数据` 的真实闸门仍在指令机里（AnswerGate）。
pub(all) struct AuditEntry {
  kind : AuditKind
  // 会话内递增序号（时间戳在视图层生成，模型不读时钟）
  seq : Int
  text : String
  // 副作用卡的补充描述（将写什么、目标当前几行）
  detail : String
  // 错误卡的调用栈文本
  stack : String
  // 是否已处理（确认/拒绝/已修复）：已处理条目降透明度
  settled : Bool
  settled_note : String
}

///|
/// Console 日志级别：INFO / WARN / ERROR。
pub(all) enum LogLevel {
  LogInfo
  LogWarn
  LogError
}

///|
/// Console 日志行：编译/运行/Agent 的原始痕迹（设计稿 consolePane）。
pub(all) struct LogLine {
  level : LogLevel
  // 会话内递增序号：稳定 key + 追加顺序
  seq : Int
  text : String
}

///|
/// 最近修改条目：谁在什么时候动了哪个对象（改属性/插控件/AI diff）。
/// 会话内 UI 事实，不进 IR、不持久化——它是「人做过什么」的教学材料。
pub(all) struct RecentChange {
  target : String
  // 作者标签（"你" / "Agent"）：i18n 在渲染层解析
  by_agent : Bool
  action : String
  seq : Int
}

///|
/// 被监视的运行时值：变量名 + 文本值 + 类型标签。
pub(all) struct WatchRow {
  name : String
  value : String
  type_label : String
}

///|
/// 积木画布分类条的一项：分类 + 该分类在画布中的首个块下标
/// （-1 = 当前子程序没有该分类的块，视图层灰显）。
pub(all) struct BlockCategoryEntry {
  category : @blocks.BlockCategory
  first_index : Int
}

///|
/// 本地数据文件（设计稿「本地数据」视图）：程序外挂数据面的只读投影。
/// 当前 IR 没有真实文件系统——条目由程序里的列表/表格控件与变量推导，
/// 让「数据从哪来」在界面上有落点，而不是假装有文件 IO。
pub(all) struct DataFileEntry {
  name : String
  meta : String
  locked : Bool
  // 预览文本（等宽展示，逐行）
  preview : String
}

///|
/// 代码编辑器的一行：行号 + 高亮 token 序列。
pub(all) struct CodeLine {
  number : Int
  tokens : Array[CodeToken]
}

///|
/// 高亮 token 种类（渲染层取色，模型只带语义分类）。
pub(all) enum CodeTokenKind {
  TokKeyword
  TokString
  TokNumber
  TokBuiltin
  TokComment
  TokPlain
}

///|
/// 高亮 token：种类 + 原文。
pub(all) struct CodeToken {
  kind : CodeTokenKind
  text : String
}

///|
/// 带源内偏移的高亮 token：`start` 是全文绝对偏移（编辑器 run 的
/// `source_range` 需要全文坐标，行内坐标会在换行处错位）。
pub(all) struct RangedToken {
  start : Int
  text : String
  kind : CodeTokenKind
}

///|
/// IR 语句 → 代码行的映射区段：语句路径 + 行区间（1 起的闭区间）。
/// 由「顺序渲染每条语句并取行区间」推导——不把行号写进 IR，
/// 映射是渲染的副产品（IR 仍是唯一事实来源）。
pub(all) struct IrLineSpan {
  path : Array[Int]
  kind : @blocks.BlockKind
  depth : Int
  first_line : Int
  last_line : Int
}

///|
/// 命令面板命令：id + 本地化标签 + 分组 + 快捷键提示 + 选中后发出的消息。
/// 设计稿的命令面包含「确认全部副作用 / 锚点循环 / 停靠 / 药丸 / 折叠底栏 /
/// 打开设置」等 Studio 自有命令，比 moui 文本命令协议的 10 个 id 更宽，
/// 所以这里用 Studio 自己的表（原 @core.ActionCommand 列表保留为视图控件
/// 的输入，两者共用 command_message 之外的独立映射）。
pub(all) struct StudioCommand {
  id : String
  label : String
  group : String
  hint : String
}

///|
/// 打开的工程文件 tab（G4 多标签:数组承载,随 tab 携带光标状态）。
/// saved_content 是脏标记的基准;draft 是编辑中的内容。
pub(all) struct OpenProjectFile {
  rel : String
  saved_content : String
  draft : String
  /// 该 tab 的光标/选区（受控编辑器回传,切换 tab 恢复,不串台）
  caret : Int
  selection : @core.TextRange?
}

///|
/// 代码视图外观（M5-5e）：中英 DSL 降级为显示外观，MoonBit 是默认显示——
/// IR 仍是唯一事实来源，两种外观都是 IR 的可再推导投影。
pub(all) enum CodeAppearance {
  AppMoonBit // MoonBit 子集源码（codegen 产物形状，代码真源的显示）
  AppDsl // 中英 DSL（教学显示外观；沿用 parse_handler_body 编辑提交）
}

///|
pub(all) struct Model {
  program : @ir.StudioProgram
  language : UiLanguage
  code_appearance : CodeAppearance
  /// 跨域事件出口（M1 插件化）：update 在事实发生处推进（见 app/events.mbt），
  /// 程序包装层每趟排空一次并经 kernel 事件总线翻译成后续消息。取代旧的
  /// pending_code_project / pending_build / build_seq 三个跨域 flag。
  outbox : Array[StudioEvent]
  /// 迁移写盘目录（M6③）：打开 .studio.json 时 = 旧文件所在目录；
  /// 由代码工程写盘事件的发出点消费（`emit_code_project_write`）。
  pending_open_dir : String?
  /// 预览模式一的画布/布局二分（M4 收尾）：true = 布局设计器画布。
  preview_design_open : Bool
  mode : Mode
  // 设计画布缩放：0 = 适应窗口（画布等比铺满画布列，默认行为）；
  // >0 = 固定比例（画布逻辑尺寸 640×zoom，超出视口由滚动接管）。
  design_zoom : Double
  selected_control : String
  selected_handler : String
  /// 非控件选中（窗体 / 变量 / 数据文件）。`None` = 选中落在控件或子程序上。
  /// 三条槽互斥，由 `select_target` / `select_control_by_name` 单一漏斗保证。
  side_target : SideTarget?
  code_draft : String
  code_error : String
  // 代码编辑器（richtext 受控面）的光标/选区/滚动：光标驱动脚注的行列
  // 读数与后续补全锚点；滚动是「行号槽 / IR 竖尺 ↔ 编辑面」同步的唯一事实。
  code_caret : Int
  code_selection : @core.TextRange?
  code_scroll : @geometry.Point
  // 当前草稿的实时语法诊断（编辑即校验；提交/切换时重算）
  code_diagnostics : Array[@code_editor.CodeDiagnostic]
  // 补全弹层（切片 H）：候选词与开关
  completions : Array[String]
  completion_open : Bool
  // 破坏性操作待确认卡（None = 无）。见 confirm.mbt 的纪律说明。
  pending_confirm : ConfirmKind?
  // 「打开项目」覆盖确认后的一次性放行标记（确认 → Effect 重投时绕过
  // dirty 守卫；OpenRequested 放行即复位）。
  open_confirmed : Bool
  // 运行时检查器：最近一次快照（入口注入的格式化文本）+ 摘要历史 +
  // 「回调不可用」标记（未注入快照通道的入口，如裸测试组合根）
  runtime_report : RuntimeInspectSample?
  runtime_missing : Bool
  runtime_history : Array[String]
  // 当前运行轨：顶栏显式切换；两轨运行态各自独立保存
  run_track : RunTrack
  // 编译轨是否可达（native 入口为真；Web 端显式声明只有解释轨 + 源码预览）
  compile_track_available : Bool
  // 解释轨运行态
  run : RunModel?
  // 编译轨运行态（native 入口可达；Web 恒为 None）
  compiled_run : CompiledRun?
  // 最近一次真编译（moon check/build）报告；失败诊断回渲染到代码/运行视图
  compile_report : @export.CompileReport?
  // 真编译进行中（执行器已入队/运行）：防重复排队，视图显示加载态
  compile_busy : Bool
  // 真编译进度（每一步开始/结束各推一条）：空 = 尚未开始或已收尾。
  // 只 busy 期间有内容——完成/失败后进度条让位给报告，避免两个读数打架。
  compile_progress : Array[@export.CompileProgress]
  // 工具链原始输出展开态（默认折叠：诊断优先，日志按需看）
  compile_output_open : Bool
  // 命令面板（技术风 IDE 的键盘优先入口）：显隐 + 过滤查询
  command_palette_open : Bool
  command_palette_query : String
  /// 命令面板中悬停的命令 id（"" = 无）。悬停是瞬态，与 IR 悬停同纪律。
  hover_studio_command : String
  /// 图标栏/动作簇的悬停提示（"" = 无）。图标按钮只有图形没有文字，
  /// 需要一条说明通路。采用 IDE 的成熟口径：**悬停时把说明写进状态栏**
  /// （VS Code / IDEA 都这么做），一处状态即可覆盖整簇图标，且键盘用户
  /// 同样可达。框架的 `@views.tooltip` 是可选替代（需逐元素 hover 状态）。
  hover_hint : String
  pending : PendingProposal?
  // AI 会话切片（M3 插件化）：草稿/线程卡/提案历史按会话隔离，
  // 见 plugins/ai；`pending` 提案与审计仍走全局通道（契约 4）
  ai_sessions : @ai.AiSessions
  composer_mode : ComposerMode
  // 模式下拉展开态（V4,VS Code 的 Agent ⌄ 口径）：收起 = 单芯片,
  // 展开 = 脚注原位切回四选一胶囊行；SetComposerMode 后收起。
  composer_mode_picker_open : Bool
  // AI 工作区面板（RvWorkspace）当前页签
  right_panel_tab : RightPanelTab
  prompt_error : String
  provider_mode : ProviderMode
  provider_endpoint : String
  provider_model : String
  provider_key : String
  // 密钥显隐（password_field 的展开态；掩码态下忽略输入防星号写穿）
  provider_key_revealed : Bool
  // 未保存标记：程序编码 ≠ 最近一次保存/打开/还原基线时为真，标题旁显示 ●
  dirty : Bool
  saved_encoding : String
  draft_encoding : String
  notice : String
  // 导出独立应用是否可达：native 有系统目录选择 + 写盘（NSOpenPanel）；
  // Web 的目录「选择」返回的是文件名列表而非可写路径，写盘必然失败——
  // 与 compile_track_available 同一口径：不可达就显式声明，不假装能导。
  export_available : Bool
  // 导出 bundle 剩余未落盘的文件数（>0 = 导出进行中；归零时才报「已导出」，
  // 否则 25 个文件各回一条完成消息，会把过程误报成 25 次成功）。
  export_pending : Int
  explanation : String
  // AI 请求进行中（真实 provider 生成/讲解）：面板显示加载态
  ai_busy : Bool
  // 积木视图编辑态：选中块（block_chain 下标，-1 = 无）与语句草稿
  selected_block : Int
  block_draft : String
  // 正在编辑的**值**：语句链下标 + 表达式路径 + 当前输入文本。
  // `None` = 没有值编辑在进行（此时画布不画行内输入框）。
  block_value_edit : (Int, Array[Int], String)?
  // `询问` 闸门的回答草稿（用户正在输入的内容）。
  gate_answer_draft : String
  // 悬停中的 IR 路径（None = 没有悬停）。绘制时与 `ir_highlight` 取并集。
  hover_path : Array[Int]?
  // 设计画布拖拽态：按下命中控件时建立，松开清除
  drag : DragState?
  // 运行期活状态：跨事件累积的变量值与控件文本（易语言式全局量）
  runtime_values : Map[String, @studio_lang.Value]
  runtime_texts : Map[String, String]
  runtime_rows : Map[String, Array[String]]
  runtime_selections : Map[String, Int]
  // 解释轨随机种子：每次事件推进一格后交给新的 RunState。
  // **必须跨事件保留**——每次事件都从同一个种子起算的话，同一个按钮点
  // 十次会得到十个相同的「随机」结果（点名册每次都是「王五」），用户读到
  // 的现象就是「运行之后点按钮没反应」。编译轨的种子在 Runtime.rng 里。
  runtime_seed : Int
  // 虚拟时钟（切片 G）：只在运行期间步进（TimerTick 每秒一次），
  // 累计到窗体 timer_interval 秒即触发一次 @定时器 处理器
  timer_elapsed : Int
  // 撤销/重做：变更前快照栈（深度 UNDO_DEPTH）与重做栈
  undo_stack : Array[UndoEntry]
  redo_stack : Array[UndoEntry]
  // 积木画布拖拽（同层重排）进行中
  block_drag : BlocksDragState?
  // === v4 IDE 壳工作区状态（全部会话内，不持久化）===
  // 中心工作区：可视化 / 代码 / 空舞台
  workspace : WorkSpace
  // Live App 窗格显隐（可视化工作区内的多窗格编排）
  pane_live : Bool
  // 积木窗格显隐
  pane_blocks : Bool
  // Live App 窗格占可视化工作区宽度的比例（分隔条拖拽，0.2–0.8）
  split_ratio : Double
  // 左栏视图（图标栏切换；收起时不占宽度）
  left_view : LeftView
  // 左/右栏宽度（列间 sash 拖拽改宽；默认 = LEFTBAR/RIGHTBAR_WIDTH，
  // `shell_chrome_widths` 按它们分配三列，中心列吃剩余）
  left_width : Double
  right_width : Double
  // 任务模式（M2 三模式工作台）：活动栏唯一职责，切换 = 应用预设
  perspective : StudioPerspective
  // 组合 profile（M7）：Teaching = 只开放图形化模式 + 无终端
  profile : StudioProfile
  // 右栏当前视图（M2）：取代 right_visible × ai_anchor 的 2×2 组合，
  // AI 宿主由它推导（RvAi=右栏停靠，否则底栏页签或 AI 模式中心）
  right_view : RightView
  // 沉浸式无边框：true 时顶栏之上多一条窗控条（信号点 + 拖拽区）。
  // 平台入口按自己有没有无边框窗口决定——Web 恒 false。
  immersive : Bool
  // 左栏结构树搜索查询
  tree_query : String
  // 结构树展开的分组集合（g 值文本；设计稿只在会话内记忆）
  tree_collapsed : Array[String]
  // === 工程工作台（M0）：导入的 MoonBit 工程（会话内，不持久化）===
  // 最近导入的在前；active_project 是资源管理器当前高亮的下标（-1 = 无）。
  // Studio 自身的 .studio.json 程序仍是主编辑上下文，真源切换在 M6。
  projects : Array[ProjectRecord]
  active_project : Int
  // 扫描进度读数（G2）：进行中 = 资源管理器头部一行「已扫描 N 目录」;
  // 完成即清 None。
  scan_progress : String?
  // 工程记录恢复中（G2 W3）：>0 = 还有 N 个 boot 重扫未回来（静默合并）;
  // 0 = 常规导入语义（带通知与预览 harness）。restore_active_root 是本次
  // 恢复要重新选中的工程根（全部重扫回来时落位）。
  projects_restore_pending : Int
  restore_active_root : String
  // 资源管理器:折叠的包(相对路径)与选中的文件(相对路径)
  project_tree_collapsed : Array[String]
  selected_project_file : String?
  /// 打开的工程文件 tabs（G4 多标签:数组 + active 下标,旧单槽退役）。
  /// rel = 工程相对路径;saved_content = 最近一次落盘/读取的内容（脏标记
  /// 的基准）;draft = 编辑中的内容;caret/selection 随 tab 走。
  open_project_files : Array[OpenProjectFile]
  open_file_index : Int
  // G4 文件 CRUD:inline 一行式输入态(新建/改名共用输入框草稿)。
  // file_create_open = 资源管理器顶部显示「新建文件」输入行;
  // file_rename_open = 正在改名的 rel(该文件行替换为输入行)。
  file_create_open : Bool
  file_rename_open : String?
  file_name_draft : String
  // G7.3 插件管理:禁用清单（静态装配的「启用/禁用」诚实形态——禁用 =
  // 组合根装配时过滤贡献项入口,不是运行时卸载）。id: ai / terminal / markdown
  plugin_disabled : Array[String]
  // G4 全文搜索:查询草稿 + 命中集 + 进行中标记（结果面板挂 BtSearch 页签）
  search_query : String
  search_hits : Array[SearchHit]
  search_busy : Bool
  // 构建服务(M0-7):最近一次构建报告(诊断汇进 Problems)与进行中标记。
  // 待执行请求已改事件驱动(M1):过门即发 EvBuildSubmit,不再存 pending_build。
  last_build : @build.BuildReport?
  build_busy : Bool
  // 预览 harness 落盘(M1):导入成功后逐文件写 .studio/preview(Export
  // 三段式同款——队列在 Model,回执推进游标),写完置 None
  preview_write : PreviewWriteState?
  // 预览帧(M1-2):FramePreview 构建回执解析出的可重放帧
  preview_frame : PreviewFrame?
  // 语义点选(M1-3):选中的语义节点下标(帧快照内稳定)+ label 编辑草稿
  selected_semantic : Int?
  semantic_draft : String
  // 表单设计器会话(M4-2):form.mbt 加载/编辑/保存
  form_designer : FormDesignerSession?
  selected_form_control : Int?
  // 预览模式条(M2-2):画布快览 / web 实时(webview)
  preview_mode : PreviewMode
  preview_web_url : String?
  preview_web_opened : Bool
  // 右栏 Context 页签
  ctx_tab : ContextTab
  // 底部横条展开态与高度（审计 + Console）
  bottom_open : Bool
  bottom_height : Double
  // 底部横条当前页签：审计 / Console / 问题
  bottom_tab : BottomTab
  // 运行审计时间线（会话内）
  audit_entries : Array[AuditEntry]
  audit_seq : Int
  // Console 日志（会话内）
  log_lines : Array[LogLine]
  log_seq : Int
  // 最近修改（会话内，最多保留 RECENT_LIMIT 条）
  recent_changes : Array[RecentChange]
  recent_seq : Int
  // 积木上下文菜单：打开时记录命中的链下标与锚点（画布局部坐标）
  block_menu : (Int, Double, Double)?
  // 正在从调色板拖动的骨架（分类下标, 模板下标）；None = 没在拖
  palette_drag : (Int, Int)?
  // 正在拖动的**报告块**（表达式模板下标）；None = 没在拖表达式。
  // 与 `palette_drag` 分开：语句拖放与表达式拖放的落点语义不同
  // （插一行 vs 换一个洞），合成一个字段就无法区分意图。
  expr_drag : Int?
  // 积木画布的滚动偏移（受控）。拖到画布上下缘附近时按 `Msg::BlocksAutoScroll`
  // 逐步推进——Scratch/Figma 的「拖到边缘自动滚动」，长链条拖拽的必需项
  // （不自动滚就只能拖到可视区内，链尾的块永远拖不动）。
  blocks_scroll_y : Double
  // AI 输入面：宿主由 right_view × perspective 推导（M2）/ 线程卡是否折叠
  ai_cards_folded : Bool
  // 流式生成进行中（M4）：StreamChunk 分片只在为真时追加（停止即截断）
  ai_streaming : Bool
  // 墙钟快照（对白转录）：组合根注入 wall_clock 闭包时每秒经 ClockUpdated
  // 刷新；默认常数钟（clock.mbt）——时间戳/时长/相对时间的唯一来源
  clock : StudioClock
  // AI 模式时间线的受控滚动（终端同款）：用户手动滚动回写 offset，
  // 新内容追加时按 seq 强制贴底；离底显示浮动「回到底部」
  mut transcript_scroll : @geometry.Point
  mut transcript_scroll_seq : Int
  // 自动贴底开关：用户上滚即关，点「回到底部」或手动滚到底即开
  mut transcript_follow : Bool
  // === 左栏会话列表（对白转录 M4）===
  // 搜索过滤（本地,title 子串）
  ai_sessions_search_open : Bool
  ai_sessions_query : String
  // 悬停中的会话行下标（-1 = 无）：✕/置顶动作只在悬停行出现
  ai_session_hover : Int
  // 行内改名编辑态:(下标, 草稿);None = 没有在改名
  session_rename : (Int, String)?
  // 终端插件状态切片（M5）：全模式底栏可用（M8）；web = unavailable 空态
  terminal : @terminal.TerminalState
  /// 终端页签开合（M8）：开 = 页签可选、选中显示交互终端；关 = 已 kill、
  /// 再点页签重开（重派生）。关闭动作 = 再点选中的终端页签。
  mut terminal_open : Bool
  /// 终端屏滚动（M8 用户反馈②）：受控 offset（跟随用户手动滚动）+
  /// 请求序号（新输出时自增 → 强制滚到底部，scroll 容器 clamp）
  mut terminal_scroll : @geometry.Point
  mut terminal_scroll_seq : Int
  ai_context_chips : Array[String]
  // 设置对话框 / AI 历史对话框
  settings_open : Bool
  ai_history_open : Bool
  // toast：文本 + 是否警告（会话内，最多 TOAST_LIMIT 条）
  toasts : Array[ToastEntry]
  // 命令面板 Canvas（设计稿把积木分类条单独成条：选中的分类下标，-1 = 全部）
  selected_category : Int
  // 语句插入面板：是否展开（分类轨点击）。展开时列出该分类可插入的语句骨架。
  statement_palette_open : Bool
  // 结构树里展开着「新建」菜单的分组（"" = 没有）。分组头的「+」点开它，
  // 列出该组可创建的对象——创建入口贴着它创建的东西，而不是面板底部
  // 一个与上下文无关的按钮块。
  tree_create_group : String
  // IR↔代码行映射高亮：当前高亮的语句路径（空 = 无）
  ir_highlight : Array[Int]
}

///|
pub(all) enum Msg {
  Noop // 设计舞台展示态控件的兜底回调（输入被手势覆盖层拦截，正常不触发）
  SwitchLanguage
  CycleCodeAppearance // 代码视图外观切换：MoonBit（默认显示）⇄ 中英 DSL（M5-5e）
  SetCodeAppearance(CodeAppearance) // 直达目标外观（双芯片入口，实测反馈）
  ProjectFileLoaded(String, @services.ServiceTaskResult[String]) // 工程文件读取回执
  EditProjectFile(String) // 工程文件草稿编辑（active tab）
  ProjectFileCaretMoved(Int, @core.TextRange?) // 工程文件编辑器光标/选区上报（active tab）
  SaveProjectFile // 保存 active tab（写盘）
  SaveAllFiles // 保存全部脏 tab（G4 多标签）
  ProjectFileSaveFinished(String, @services.ServiceTaskResult[Unit]) // 保存回执(rel 定位 tab)
  // tab 导航（G4 多标签）：切换 / 关闭（脏 tab 经确认流放行）
  SelectFileTab(Int)
  CloseFileTab(Int)
  // === 文件 CRUD（G4）：新建 / 重命名（inline 输入 + 服务链）===
  // 新建 = write_text → 回执开 tab + 重扫;改名 = read→write→delete 三步链,
  // 每步回执驱动,失败结构化提示已到哪步（半完成不静默）。
  FileCreateStart
  FileCreateDraft(String)
  FileCreateCommit
  FileCreateDismiss
  FileRenameStart(String)
  FileRenameDraft(String)
  FileRenameCommit
  FileRenameDismiss
  ProjectFileCreated(String, @services.ServiceTaskResult[Unit])
  ProjectRenameRead(String, String, @services.ServiceTaskResult[String])
  ProjectRenameWritten(String, String, @services.ServiceTaskResult[Unit])
  ProjectRenameDeleted(String, String, @services.ServiceTaskResult[Unit])
  // === 全文搜索（G4 F3）：草稿 → 运行（服务链扫工程树）→ 命中集 → 跳转 ===
  TogglePlugin(String)
  PluginsLoaded(@services.ServiceTaskResult[String?])
  // 属性 v2（G7.2）：文本属性与布尔属性两条编辑通道
  SetControlPropText(String, String, String)
  ToggleControlProp(String, String)
  SearchQueryDraft(String)
  SearchRun
  SearchFinished(@services.ServiceTaskResult[Array[SearchHit]])
  SearchHitClicked(String)
  CodeProjectSaved(@services.ServiceTaskResult[Unit]) // 代码工程骨架落盘回执（M6①）
  SetMode(Mode)
  SetDesignZoom(Double)
  SelectControl(String)
  /// 选中一个**非控件**对象（窗体 / 变量 / 数据文件）——左栏结构树中
  /// 这三类行此前没有 `on_tap`，点了完全没反应。
  SelectSide(SideTarget)
  /// 修改窗体标题（右栏窗体属性）。运行舞台的拟真标题条与导出应用的
  /// 窗口标题都读它。
  SetWindowTitle(String)
  SetTimerInterval(String)
  /// 点开/收起某个分组头的新建菜单（"" = 全部收起；同一组再点 = 收起）。
  ToggleTreeCreate(String)
  /// 新建一个程序变量（分组头「变量 +」）。名称自动去重（`变量1`、`变量2`…），
  /// 初值取空串——与 `Declare` 语句的空文本初值同一口径。
  AddVariable
  /// 重命名变量（右栏属性）。所有引用该变量的表达式同步改名。
  RenameVariable(String, String)
  /// 修改变量初值（右栏属性）。
  SetVariableInit(String, String)
  /// 删除变量（右栏属性）。引用它的语句**不**自动清理（那会静默改写程序
  /// 语义）——由 `validate_program` 在编译/导出时如实报未声明变量。
  DeleteVariable(String)
  /// 清空选中（控件与事件子程序一起）。设计稿右栏 Context 的 `#clearSel`：
  /// 不给出这个出口的话，选中只能被**另一个选中**覆盖——用户没法回到
  /// 「什么都没选」的中性态，右栏会一直显示上一个对象的属性。
  ClearSelection
  CanvasPress(Double, Double)
  CanvasTap(Double, Double)
  CanvasDragTo(Double, Double)
  CanvasRelease(Double, Double)
  SetControlText(String, String)
  SetControlName(String, String)
  SetControlItems(String, String)
  SetControlRect(String, @ir.RectField, String)
  AddControl(@ir.ControlKind)
  DuplicateControl(String)
  DeleteControl(String)
  SelectHandler(String)
  CreateHandler(String, @ir.EventKind)
  EditCode(String)
  EditorCaretMoved(Int, @core.TextRange?)
  EditorScrolled(Double)
  // 运行时检查器：按需采样（打开页签 / 点击刷新）
  RuntimeRefresh
  // 代码情报（切片 H）：补全 / 应用补全 / 跳到声明
  TriggerCompletion
  ApplyCompletion(String)
  JumpToDeclaration
  DismissCompletion
  // 破坏性操作确认流：请求 / 接受（续行原消息）/ 取消
  RequestConfirm(ConfirmKind)
  ConfirmAccepted
  ConfirmDismissed
  Undo
  Redo
  SetPrompt(String)
  SetComposerMode(ComposerMode)
  /// 开/关 composer 的模式下拉（V4）：收起态单芯片 ↔ 展开态四选一胶囊行
  ToggleComposerModePicker
  /// 切换 AI 工作区面板页签（更改/文件）
  SetRightPanelTab(RightPanelTab)
  ComposerRun
  RealGenerationFinished(Result[String, String])
  /// 纯聊天回复回执（G1）：成功 = markdown 文本,失败 = 错误卡
  ChatSubmit
  RealChatFinished(Result[String, String])
  ExplainHandler
  RealExplanationFinished(Result[String, String])
  LanguageLoaded(String)
  EditBlock(String)
  CommitBlock
  DuplicateBlock
  DeleteBlock
  /// 键盘在积木链里上下移动选中（Scratch/IDE 口径：↑/↓ 走上/下一块）。
  /// 参数是步长（+1 / -1）。没有选中时从链首开始（+1）或链尾（-1）。
  SelectBlockStep(Int)
  /// 打开/关闭语句插入面板（分类轨点击；Scratch 积木调色板口径）。
  /// 面板给出该分类可插入的**语句骨架**，点一条即插入到当前选中块之后
  /// （没有选中则插到末尾）。这是「无 AI 也能写程序」的核心入口——
  /// 此前 `commit_block` 只能**替换**已有语句，用户从零写不出任何逻辑。
  ToggleStatementPalette(Int)
  /// 插入一条语句骨架：参数是分类下标与分类内模板下标。
  InsertStatement(Int, Int)
  /// 从调色板**开始拖**一条骨架（Scratch 的字面手势）。
  ///
  /// 调色板与画布是**兄弟视图**，各自只能看到自己的帧；拖动中的指针位置
  /// 由画布侧的消息补全。所以分两步：按下时记下「正在拖哪条骨架」，
  /// 画布收到拖动/松手时按指针算落点并派发 `DropStatement`。
  PaletteDragStart(Int, Int)
  /// 从调色板**开始拖**一个报告块（表达式）。与语句拖放分开：表达式只能
  /// 落进**洞**里（替换子表达式），不能插成一行。
  PaletteExprDragStart(Int)
  /// **只运行选中的那一条语句**（Scratch 的「点积木就跑它」）。
  ///
  /// 语义边界（刻意收窄，避免造出第二套执行模型）：
  /// - 只跑**该语句本身**，不跑它下面的兄弟——Scratch 的「点击运行」跑的是
  ///   整个脚本（栈），那是 `RunStart` 已有的语义；
  /// - 控制流语句（if/循环）会连带跑它的**体内**（那是这一条语句的一部分），
  ///   但不会跑它之后的兄弟；
  /// - 是一次**有界沙箱执行**（沿用 `DEFAULT_MAX_STEPS` 与闸门），不是新的
  ///   执行通道。
  RunSingleBlock
  /// 拖拽中指针停在画布上下缘附近 → 自动滚动一档（参数 = 方向：-1 上 / +1 下）。
  BlocksAutoScroll(Int)
  /// 用户手动滚动积木画布（受控偏移回报）。
  BlocksScrolled(Double)
  /// **新建自定义积木**（Scratch 的「制作一个积木」）。
  ///
  /// 语言层 / 解释器 / 编译运行时**早就支持** `FuncDef`（`return` 关键字、
  /// `functions` 参数、`lower_user_function` 都在），但只能从 JSON 进来——
  /// 界面上没有任何创建入口，所以「定义一个自己的积木」在积木界面里**做不到**。
  /// 这条消息补的就是这个入口，走 IR 手术（与 `AddVariable` 同一纪律）。
  AddFunction
  /// **给当前编辑目标写说明**（Scratch 的「给这段脚本加注释」）。
  ///
  /// `Handler` / `FuncDef` 早就有 `note_zh` / `note_en` 字段，AI 上下文
  /// （`update_ai.mbt` 的 `handler_note`）也一直在**读**它——但界面上没有
  /// 任何**写**的入口，所以这两个字段永远是空的。这条消息补上入口。
  ///
  /// 写当前界面语言那一份，另一份留空由读取端回退（`handler_note` 已有
  /// 「本语言为空则用另一语言」的回退逻辑）。
  EditTargetNote(String)
  /// 重命名自定义积木（并同步改写所有调用点的函数名）。
  RenameFunction(String, String)
  /// 点击积木上的一个**值**（叶子段）→ 就地编辑它（Scratch 的「点值改值」）。
  ///
  /// 参数：语句链下标、该值的表达式路径、值类型提示（数字/文本/布尔）。
  /// 与 `EditBlock`（改整行草稿）分开：值编辑只动那一个叶子，
  /// 不重新解析整行——整行草稿会把用户没碰的部分也重写一遍。
  EditBlockValue(Int, Array[Int])
  /// `询问` 闸门的**回答输入**（Scratch 的「询问并等待」要能打字）。
  ///
  /// 此前闸门卡片只给「确认/拒绝」两个按钮，`AnswerGate(Bool)` 也只带布尔
  /// ——所以 `询问` 的回答内容**根本无从输入**，它只能当「是/否」用，而那
  /// 不是它的语义。这条消息让用户把回答打进去。
  GateAnswerInput(String)
  /// 提交闸门回答（带当前输入的文本）。
  GateAnswerSubmit
  /// 值编辑的输入变化（正在编辑的文本）。
  BlockValueInput(String)
  /// 值编辑提交。
  BlockValueCommit
  /// 值编辑取消（Escape / 点别处）。
  BlockValueCancel
  /// 拖动报告块在画布上松手：**画布已解析出**目标洞（语句链下标 + 表达式
  /// 路径），这里只做落地。
  ///
  /// 为什么由画布解析而不是 update：洞的位置 = 逐段文本宽度累加，需要
  /// `TextSystem`；它只在**布局上下文**里，update 层拿不到。把解析放在
  /// 画布（与绘制同一份度量）才保证「画在哪就点在哪」。
  ExpressionDrop(Int, Array[Int])
  /// 从调色板**拖一个报告块（表达式）进洞**并落下。
  ///
  /// 参数：表达式模板下标、目标语句链下标、目标表达式路径。
  /// 与语句拖放分开：表达式**不能单独成为一条语句**，它只能替换某个
  /// 子表达式——所以落点语义是「换掉那个洞里的东西」而不是「插一行」。
  DropExpression(Int, Int, Array[Int])
  /// 画布上松手时**完成调色板拖放**：按指针算落点容器与位置。
  PaletteDrop(Double, Double, Double)
  /// 从调色板**拖一条骨架到画布**并落下（Scratch 的字面手势）。
  ///
  /// 参数：分类下标、模板下标、落点列表路径、落点位置。与
  /// `InsertStatement` 共用 `insert_statement_at` 的校验与手术——
  /// 拖放只是「落点由指针决定」的插入，不是第二套插入语义。
  DropStatement(Int, Int, Array[Int], Int)
  GenerateProposal
  AcceptProposal
  RejectProposal
  SetProviderMode(ProviderMode)
  SetProviderEndpoint(String)
  SetProviderModel(String)
  SetProviderKey(String)
  ToggleProviderKeyReveal
  DraftLoaded(@services.ServiceTaskResult[String?])
  RunStart
  RunStop
  SetRunTrack(RunTrack)
  CompileRun
  CompileRunFinished(@export.CompileReport)
  CompileRunFailed(String)
  /// 停止真编译：清报告与忙态，不切轨、不自动回退解释轨。
  CompileStopped
  CompileJump(Int)
  ToggleCompileOutput
  /// worker 推来的一条编译进度（步开始/步结束）
  CompileProgress(@export.CompileProgress)
  /// 复制某条产物的绝对路径到剪贴板
  CopyArtifactPath(String)
  /// 在系统文件管理器里定位某条产物（macOS=Finder）
  RevealArtifact(String)
  /// **一键启动**某条产物（GUI 应用）：脱离 Studio 生命周期起进程
  RunArtifact(String)
  /// 旁路动作的结果回来了。`what` 标明是哪一种（复制/打开/启动）——
  /// 成功文案各不相同，共用一个消息就必须带上来源，否则三种成功
  /// 只能显示同一句话（或再拆三个消息，那是同一件事的三份拷贝）。
  ArtifactActionDone(ArtifactAction, @services.ServiceTaskResult[Unit])
  CommandPaletteOpen
  CommandPaletteClose
  CommandPaletteQuery(String)
  /// 命令面板行悬停（瞬态）：高亮当前行。与 IR 悬停同纪律——离开即还原。
  /// 面板选中直接产 `StudioCommandRun(id)`（见 command_palette.mbt），
  /// 不再需要一条中转消息。
  HoverStudioCommand(String)
  /// 图标/动作悬停提示（瞬态）：指针进入时给出说明文案，离开清空。
  /// 说明文案由视图层解析好（i18n 只在这一层做），状态栏直接显示。
  HoverHint(String)
  RunTick
  TimerTick
  // toast 老化节拍（每秒一次；有 toast 时订阅才活跃）
  ToastTick
  ControlInputDone(String)
  /// 在积木上右键（Scratch/IDE 口径的上下文菜单）。参数是点中的**链下标**
  /// 与画布内坐标（菜单锚点）。下标 -1 = 点空白处（只显示画布级动作）。
  BlocksContextMenu(Int, Double, Double)
  /// 关闭积木上下文菜单（点其他地方 / Escape）。
  BlocksContextMenuClose
  /// 菜单动作：**先关菜单再执行动作**，一条消息搞定两件事。
  ///
  /// 为什么合成一条：`@views` 的 `on_tap` 每个视图只保留一个（后设的覆盖
  /// 先设的），所以「点行 = 关菜单 + 执行」不能靠串两次 `on_tap`——
  /// 实测只会触发最后一个。合成就没有这个歧义。
  BlocksMenuAction(Msg)
  RunStep
  RunResume
  AuditJump(Int)
  /// 积木画布的三个指针消息都带 `avail_width`（画布可用宽）。
  ///
  /// **为什么必须带**：命中与绘制必须用**同一组矩形**。绘制侧
  /// （`blocks_canvas`）用真实画布宽算块体宽度，而命中侧此前用默认常量
  /// `block_width = 430`——窄窗格里块被夹窄到 ~370，点在「块右缘到 430」
  /// 之间的空隙仍会被判成命中（点在空白处却选中了积木）。
  /// 宽度是视口派生的量，update 层算不出来，只能由视图侧随手势带上。
  BlocksCanvasTap(Double, Double, Double)
  BlocksCanvasPress(Double, Double, Double)
  BlocksCanvasDragTo(Double, Double, Double)
  BlocksCanvasRelease
  RunToggle(String, Bool)
  AnswerGate(Bool)
  ControlClicked(String)
  ControlPicked(String, Int)
  ControlChanged(String, String)
  SelectTemplate(Int)
  /// 新建空白程序（`empty_program`）。与打开文件/切模板同纪律：旧程序
  /// 进撤销栈可找回，运行态与选中态全部重置。
  NewBlankProgram
  SaveRequested
  SavePathPicked(@services.ServiceTaskResult[String])
  SaveCompleted(@services.ServiceTaskResult[Unit])
  OpenRequested
  OpenPathPicked(@services.ServiceTaskResult[String])
  OpenReadCompleted(@services.ServiceTaskResult[String])
  // === 工程工作台消息（M0）：导入 MoonBit 工程 ===
  // 链条：ImportProjectRequested（选目录）→ ProjectRootPicked（目录确定，
  // 走扫描任务）→ ProjectScanCompleted（扫描完：单模块或 moon.work 工作区）。
  ImportProjectRequested
  ProjectRootPicked(@services.ServiceTaskResult[String])
  ProjectScanCompleted(
    @services.ServiceTaskResult[Result[@project.ProjectScanOutput, String]]
  )
  // 扫描进度（节流回调）：资源管理器头部一行读数（G2）
  ProjectScanProgress(@project.WalkProgress)
  // 工程记录存储（G2 W3）：boot 读取回执 → 解码 → 逐 root 静默重扫；
  // 重扫回执走静默合并（不弹通知、不产 harness）；写盘请求/回执与
  // ai-sessions 同款纪律。
  ProjectsStoreLoaded(@services.ServiceTaskResult[String])
  ProjectRestoreScanCompleted(
    @services.ServiceTaskResult[Result[@project.ProjectScanOutput, String]]
  )
  ProjectsStoreWriteRequested
  ProjectsStoreSaved(@services.ServiceTaskResult[Unit])
  // 资源管理器导航(纯状态):选中工程 / 折叠包 / 选中文件 / 会话内移除工程
  SetActiveProject(Int)
  ToggleProjectPackage(String)
  SelectProjectFile(String)
  RemoveProject(Int)
  // 文件删除(确认后续行 + 服务回执;M0-6b)
  ProjectFileDeleteRun(String)
  ProjectFileDeleted(String, @services.ServiceTaskResult[Unit])
  // 构建服务(M0-7):UI 请求(kind)→ busy 置位 → 包装层派发注入的
  // build_submit → 回执落 last_build(诊断汇进 Problems)
  ProjectBuildRun(@build.BuildKind)
  ProjectBuildFinished(@build.BuildKind, Result[@build.BuildReport, String])
  // 预览 harness 落盘回执(成功推进游标;全部写完 = 预览就绪)
  PreviewFileWritten(@services.ServiceTaskResult[Unit])
  // 语义点选 + 字面量属性补丁(M1-3)
  SelectSemanticNode(Int)
  SemanticLabelInput(String)
  SemanticLabelCommit
  SemanticPatchFinished(Result[String, String])
  // 表单设计器(M4-2):打开(读 form.mbt)/加载回执/拖拽结束(span 补丁+写回)
  SelectFormControl(Int)
  SetPreviewDesignOpen(Bool)
  FormDesignOpen
  FormDesignLoaded(@services.ServiceTaskResult[String])
  FormDesignDragEnd(Int, Double, Double)
  FormDesignResizeEnd(Int, Double, Double)
  FormDesignSaved(@services.ServiceTaskResult[Unit])
  // 外部改动重载（M8）：手动刷新入口读 form.mbt → 比对 → 提示/重载
  FormDesignExternalCheck
  FormDesignExternalChecked(@services.ServiceTaskResult[String])
  // 预览模式条(M2-2):Frame/Web 切换;Web 构建回执后 wrapper 派发
  // navigate/reload(经注入的 webview 控制器闭包)
  SetPreviewMode(PreviewMode)
  PreviewNavigate(String)
  PreviewReload
  ExportRequested
  ExportDirPicked(@services.ServiceTaskResult[String])
  ExportFileWritten(@services.ServiceTaskResult[Unit])
  SetNotice(String)
  // === v4 IDE 壳消息 ===
  // 事件驱动消息（M1 内核化）：由 outbox 事件经总线翻译而来，副作用在
  // 程序包装层的臂里经服务容器执行。
  /// 代码工程骨架写盘（EvCodeProjectWrite 的翻译）：目录 + form.mbt + handlers.mbt
  CodeProjectWriteRequested(String, String, String)
  /// 构建请求派发（EvBuildSubmit 的翻译）
  BuildDispatchRequested(ProjectBuildRequest)
  /// AI 会话操作（M3 插件化）：新建/切换/删除，经 Feature::scope 委托
  /// 给 plugins/ai 的状态切片
  AiSessionOp(@ai.AiSessionMsg)
  /// 终端（M5 插件）：PTY 输出增量 / 派生回执 / 提交输入行 / 关闭会话
  TerminalOutput(String)
  TerminalSpawned(Int?)
  TerminalInput
  TerminalClose
  /// 终端输入行键入（受控 text_field 增量）
  TerminalType(String)
  /// 终端直连键入（M8 交互式：键盘/文本输入经 keyboard_input 透传给 PTY）
  TerminalWrite(String)
  /// 终端页签开关（M8）：再点选中的终端页签 = 关闭（kill + 收起）；关闭态
  /// 再点 = 重开（重派生）
  TerminalTabClose
  /// 请求宿主把键盘焦点交给终端（M8：经注入的 focus_terminal 回调调
  /// runtime.focus_key("terminal-input")——app 不接触 runtime）
  FocusTerminalRequest
  /// 流式分片到达（M4）：追加进当前会话的流式卡；已停止则忽略
  StreamChunk(String)
  /// 流式完成（正常结束）
  StreamFinished
  /// 停止生成（用户动作）：截断流式，卡片标记已停止
  StopGeneration
  /// 墙钟刷新（组合根注入 wall_clock 时 1s 一次，仅 AI 模式订阅）：
  /// 时间线 HH:MM、相对时间、「已工作 N 秒」随之走动。
  ClockUpdated(StudioClock)
  /// 复制时间线里的一条消息（参数 = 卡 seq）：走系统剪贴板。
  CopyAiMessage(Int)
  /// 把一条用户提问回填进 composer 草稿（对白转录气泡的「编辑」）。
  EditUserPrompt(Int)
  /// 重发一轮：把该条 AI 消息**之前的用户提问**回填草稿并立即重跑
  /// （ComposerRun 语义，不是第二条执行通道）。
  RetryUserPrompt(Int)
  /// 时间线受控滚动回写（终端同款）。
  TranscriptScrolled(@geometry.Point)
  /// 「回到底部」浮动按钮：强制贴底 + 恢复自动跟随。
  TranscriptScrollToBottom
  // === 左栏会话列表（M4）===
  /// 开/关会话搜索过滤行（关闭时清空查询）
  ToggleAiSessionSearch
  /// 会话过滤查询输入
  SetAiSessionsQuery(String)
  /// 悬停进入/离开某会话行（参数 = 下标, 是否进入）
  AiSessionHover(Int, Bool)
  /// 行内改名：进入编辑态（参数 = 会话下标）
  AiSessionRenameStart(Int)
  /// 行内改名草稿
  AiSessionRenameDraft(String)
  /// 行内改名提交（Enter）
  AiSessionRenameCommit
  /// 行内改名放弃（Escape / 点击别处）
  AiSessionRenameDismiss
  /// 会话存储读取回执（M5,仅组合根配置了存储路径时发起）
  AiSessionsStoreLoaded(@services.ServiceTaskResult[String])
  /// 会话存储写盘请求（总线从 EvAiSessionsDirty 翻译而来）
  AiSessionsStoreWriteRequested
  /// 会话存储写盘回执
  AiSessionsStoreSaved(@services.ServiceTaskResult[Unit])
  // 工作区编排：图标栏切换（同一工作区再点一次 = 空舞台）
  SetWorkSpace(WorkSpace)
  TogglePaneLive
  TogglePaneBlocks
  /// 幂等地**显示**窗格（设计稿 `#btnAddLive` / `#btnAddBlocks`）。
  /// 空舞台用它们做恢复入口——那里必须是「打开」而不是「取反」，
  /// 否则从空舞台点一次反而会把已经为真的开关关掉。
  ShowPaneLive
  ShowPaneBlocks
  // 分隔条拖拽：比例（0.2–0.8，越界由 update 钳制）
  SetSplitRatio(Double)
  // 任务模式切换（M2）：进模式按预设置位四区域；同值再点 no-op
  SetPerspective(StudioPerspective)
  // 左栏：视图切换 / 关闭 / 搜索 / 分组展开折叠
  SetLeftView(LeftView)
  SetTreeQuery(String)
  ToggleTreeGroup(String)
  /// 显式设置右栏当前视图（M2）：关闭入口在右栏头的 ✕（只可能关 →
  /// RvHidden），重开与换视图走命令面板逃生口（studio.right.* / studio.ai.*）。
  SetRightView(RightView)
  /// 列间 sash 拖拽改宽（VS Code 口径）：指针位置 → 目标宽度在**视图层**
  /// 换算并夹取（界限依赖当帧布局），update 只再兜底夹一次。布局手势，
  /// 不产生撤销点、不标脏。
  ResizeLeftPanel(Double)
  ResizeRightPanel(Double)
  // 右栏 Context 页签
  SetContextTab(ContextTab)
  // 底栏：页签切换 / 展开折叠 / 高度拖拽
  SetBottomTab(BottomTab)
  /// 底栏高度拖拽（M8 用户反馈③）：sash 位置 → 钳制后的高度
  SetBottomHeight(Double)
  /// 终端屏滚动（M8②）：用户手动滚动（受控 offset 跟随）
  TerminalScrolled(@geometry.Point)
  // 问题面板：跳到某子程序草稿的某行（选中 handler + 光标 + 滚动对齐）
  GotoProblem(String, Int)
  ToggleBottom
  // 审计：点击条目（跳到对应积木）/ 处理副作用卡（settled 标记）
  AuditOpen(Int)
  AuditSettle(Int, String)
  AuditSettleAll(String)
  // 最近修改 / Console 清空
  ClearConsole
  // AI 浮动层：药丸 / 折叠卡 / 上下文芯片（落点已由 right_view 推导，M2）
  // 沉浸式无边框窗口：三个窗控件 + 拖拽。native 映射到真实窗口请求，
  // Web/无边框未启用时是安全 no-op（不假装能关掉浏览器标签页）。
  WindowClose
  WindowMinimize
  WindowZoom
  WindowDragBy(Double)
  ToggleAiCardsFold
  // 快速操作：对齐左/居中/对齐右（设计稿 x=24 边距口径）
  AlignControlLeft(String)
  AlignControlCenter(String)
  AlignControlRight(String)
  // 对话框 / 历史 / toast
  ToggleSettings
  ToggleAiHistory
  DismissToast(Int)
  // 命令面板 Studio 命令（比 10 个文本命令更宽的自有表）
  StudioCommandRun(String)
  // 积木分类条：选中分类（-1 = 全部）
  SelectBlockCategory(Int)
  // IR↔代码行映射高亮：按语句路径
  HighlightIrPath(Array[Int])
  // 悬停联动（设计稿 `irHl`）：指针进/出代码行或积木块时高亮对应路径。
  // 与 `HighlightIrPath` 分开是因为语义不同——悬停是**瞬态**的（离开即
  // 撤销），点击是**驻留**的（再点一次才取消）。两者共用一个高亮槽位，
  // 悬停不写槽位，只在 `hover_path` 里记临时值。
  HoverIrPath(Array[Int]?)
  // 代码草稿回归 IR 渲染（丢弃手改）——高亮区永远来自 IR 投影，
  // 草稿与 IR 分叉时由用户显式决定放弃哪边
  RestoreCodeDraft
}

///|
/// handler 定位键：控件名@事件标签（选中态在模型里用字符串携带）。
pub fn handler_key(control : String, event : String) -> String {
  "\{control}@\{event}"
}

///|
/// 空程序（新建项目的起点）。
pub fn empty_program() -> @ir.StudioProgram {
  @ir.empty_program()
}

///|
/// provider 运行时配置（来自 gitignored .config.json；缺省即空配置）。
pub(all) struct ProviderConfig {
  endpoint : String
  model : String
  api_key : String
}

///|
pub fn empty_provider_config() -> ProviderConfig {
  { endpoint: "", model: "", api_key: "", }
}

///|
/// 草稿自动保存的 settings 键（编码后的程序 JSON；随会话持久化）。
pub const DRAFT_SETTINGS_KEY : String = "studio.draft"

///|
/// 插件启用态的 settings 键（G7.3）：值为逗号连接的禁用 id 列表
/// （空串 = 全部启用）。
pub const PLUGINS_SETTINGS_KEY : String = "studio.plugins"

///|
/// 初始模型：问候样例 + 中文界面 + 假模型；代码草稿按当前语言播种。
/// provider_config 非空时预填面板（key 仍只进会话内存）。
pub fn initial_model(
  provider_config? : ProviderConfig,
  compile_track_available? : Bool = false,
  export_available? : Bool = false,
  immersive? : Bool = false,
  pty_available? : Bool = false,
  profile? : StudioProfile = Full,
) -> Model {
  let program = @proposals.sample_hello()
  let config = match provider_config {
    Some(value) => value
    None => empty_provider_config()
  }
  let endpoint = if config.endpoint == "" {
    "https://api.stepfun.com/step_plan/v1"
  } else {
    config.endpoint
  }
  let model_name = if config.model == "" {
    "step-5-preview"
  } else {
    config.model
  }
  let encoding = @codec.encode_program(program)
  let initial_audit = boot_audit_entries(program)
  let model = {
    program,
    language: ZhHans,
    code_appearance: AppMoonBit,
    outbox: [],
    pending_open_dir: None,
    preview_design_open: false,
    mode: ModeDesign,
    design_zoom: 0.0,
    selected_control: "按钮",
    selected_handler: handler_key("按钮", "on_click"),
    side_target: None,
    code_draft: "",
    code_error: "",
    code_caret: 0,
    code_selection: None,
    code_scroll: @geometry.Point::new(x=0.0, y=0.0),
    code_diagnostics: [],
    completions: [],
    completion_open: false,
    pending_confirm: None,
    open_confirmed: false,
    runtime_report: None,
    runtime_missing: false,
    runtime_history: [],
    run_track: Interpret,
    compile_track_available,
    run: None,
    compiled_run: None,
    compile_report: None,
    compile_busy: false,
    compile_progress: [],
    compile_output_open: false,
    command_palette_open: false,
    command_palette_query: "",
    hover_studio_command: "",
    hover_hint: "",
    pending: None,
    ai_sessions: @ai.AiSessions::new(),
    profile,
    composer_mode: ComposeEdit,
    composer_mode_picker_open: false,
    right_panel_tab: RpChanges,
    prompt_error: "",
    provider_mode: Fake,
    provider_endpoint: endpoint,
    provider_model: model_name,
    provider_key: config.api_key,
    provider_key_revealed: false,
    dirty: false,
    saved_encoding: encoding,
    draft_encoding: encoding,
    notice: "",
    export_available,
    export_pending: 0,
    explanation: "",
    ai_busy: false,
    selected_block: -1,
    hover_path: None,
    block_draft: "",
    block_value_edit: None,
    gate_answer_draft: "",
    drag: None,
    runtime_values: @studio_lang.initial_values(program),
    runtime_texts: @studio_lang.initial_texts(program),
    runtime_rows: @studio_lang.initial_rows(program),
    runtime_selections: Map([], capacity=4),
    runtime_seed: @studio_lang.DEFAULT_SEED,
    timer_elapsed: 0,
    undo_stack: [],
    redo_stack: [],
    block_drag: None,
    workspace: WsVisual,
    pane_live: true,
    pane_blocks: true,
    split_ratio: 0.55,
    left_view: LeftTree,
    left_width: LEFTBAR_WIDTH,
    right_width: RIGHTBAR_WIDTH,
    perspective: PsVisual,
    right_view: RvContext,
    immersive,
    tree_query: "",
    tree_collapsed: [],
    projects: [],
    active_project: -1,
    scan_progress: None,
    projects_restore_pending: 0,
    restore_active_root: "",
    project_tree_collapsed: [],
    selected_project_file: None,
    open_project_files: [],
    open_file_index: -1,
    file_create_open: false,
    file_rename_open: None,
    file_name_draft: "",
    plugin_disabled: [],
    search_query: "",
    search_hits: [],
    search_busy: false,
    last_build: None,
    build_busy: false,
    preview_write: None,
    preview_frame: None,
    selected_semantic: None,
    semantic_draft: "",
    form_designer: None,
    selected_form_control: None,
    preview_mode: PmFrame,
    preview_web_url: None,
    preview_web_opened: false,
    ctx_tab: CtxProps,
    // 底栏默认**展开且选中 AI 页签**：图形化模式的 AI 输入条由底栏承载
    // （右栏预设是检查器），底栏收着输入条就看不见——初始状态必须让
    // 「问 AI」第一眼可达。三个只读面板仍在同一行，一次点击可达。
    bottom_open: true,
    bottom_height: 168.0,
    bottom_tab: BtAi,
    audit_entries: initial_audit,
    audit_seq: initial_audit.length(),
    log_lines: boot_log_lines(program),
    log_seq: 3,
    recent_changes: [],
    recent_seq: 0,
    block_menu: None,
    palette_drag: None,
    expr_drag: None,
    blocks_scroll_y: 0.0,
    ai_cards_folded: false,
    ai_streaming: false,
    clock: default_studio_clock(),
    transcript_scroll: @geometry.Point::new(x=0.0, y=0.0),
    transcript_scroll_seq: 0,
    transcript_follow: true,
    ai_sessions_search_open: false,
    ai_sessions_query: "",
    ai_session_hover: -1,
    session_rename: None,
    // 教学版 profile 强制无终端（组合根与直调 initial_model 的测试同口径）
    terminal: @terminal.TerminalState::new(
      available=pty_available && !(profile is Teaching),
    ),
    terminal_open: true,
    terminal_scroll: @geometry.Point::new(x=0.0, y=0.0),
    terminal_scroll_seq: 0,
    ai_context_chips: [],
    settings_open: false,
    ai_history_open: false,
    toasts: [],
    selected_category: -1,
    statement_palette_open: false,
    tree_create_group: "",
    ir_highlight: [],
  }
  seed_code_draft(model)
}

///|
/// 启动审计：把「程序已就绪」这件事在时间线上如实说一遍（设计稿首屏三条）。
/// 内容是程序事实的派生（窗体尺寸、控件数、子程序数），不写死演示文案。
fn boot_audit_entries(program : @ir.StudioProgram) -> Array[AuditEntry] {
  let entries : Array[AuditEntry] = [
    AuditEntry::{
      kind: AuditRun,
      seq: 1,
      text: "app.audit.boot",
      detail: "",
      stack: "",
      settled: false,
      settled_note: "",
    },
    AuditEntry::{
      kind: AuditOk,
      seq: 2,
      text: "app.audit.controls",
      detail: "",
      stack: "",
      settled: false,
      settled_note: "",
    },
    AuditEntry::{
      kind: AuditOk,
      seq: 3,
      text: "app.audit.handlers",
      detail: "",
      stack: "",
      settled: false,
      settled_note: "",
    },
  ]
  ignore(program)
  entries
}

///|
/// 启动 Console：三条 INFO 说明当前会话的边界（轨、编译可达性、安全叙事）。
fn boot_log_lines(program : @ir.StudioProgram) -> Array[LogLine] {
  ignore(program)
  [
    LogLine::{ level: LogInfo, seq: 1, text: "app.log.ready", },
    LogLine::{ level: LogInfo, seq: 2, text: "app.log.track", },
    LogLine::{ level: LogWarn, seq: 3, text: "app.log.gate", },
  ]
}
