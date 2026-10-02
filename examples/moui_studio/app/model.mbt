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
/// 提案历史条目：会话内回放「AI 干了什么」（采纳/拒绝 + 摘要 + diff）。
pub(all) struct ProposalRecord {
  summary : String
  diff : Array[@proposals.DiffEntry]
  accepted : Bool
  seq : Int
}

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
  list_path : Array[Int]
  from : Int
  to : Int
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
  WsEmpty
}

///|
/// 左栏视图：程序结构树 / 本地数据 / 收起。
pub(all) enum LeftView {
  LeftTree
  LeftData
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
/// 底栏页签：运行审计 / Console / 问题（诊断汇总）。
/// 原来是 `bottom_audit : Bool` 两态开关，问题面板加入后升级为枚举。
pub(all) enum BottomTab {
  BtAudit
  BtConsole
  BtProblems
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
} derive(Eq)

///|
pub extend ComposerMode with Eq::{not_equal, equal}

///|
/// AI 浮动层锚点：底部居中 / 左下 / 右下 / 停靠右栏。
pub(all) enum AiAnchor {
  AiCenter
  AiLeft
  AiRight
  AiDocked
}

///|
/// AI 会话卡的种类：Agent 计划 / diff 待审计 / 副作用确认 / 讲解 / 错误。
/// 卡是「Agent 干了什么」的可审计投影，不承载执行语义——采纳仍走既有
/// AcceptProposal / AnswerGate 通道。
pub(all) enum AiCardKind {
  CardPlan
  CardDiff
  CardSideEffect
  CardExplanation
  CardError
}

///|
/// AI 会话卡：会话内的可见工作记录（设计稿 threadStack）。
/// steps 只在计划卡非空；diff 行只在 diff 卡非空。
pub(all) struct AiCard {
  kind : AiCardKind
  title : String
  body : String
  // 计划卡：步骤文本 + 已完成步数 + 进度百分比
  steps : Array[String]
  steps_done : Int
  progress : Int
  // diff 卡：逐行 ± 文本
  diff_lines : Array[(String, String)]
  // 卡是否已被用户处理（接受/拒绝/确认）：处理过的卡降透明度显示
  settled : Bool
  settled_note : String
  // 单调递增序号：用于稳定 key 与「最新一张」判定
  seq : Int
}

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
pub(all) struct Model {
  program : @ir.StudioProgram
  language : UiLanguage
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
  prompt_draft : String
  composer_mode : ComposerMode
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
  // 会话内提案历史（不持久化）
  proposal_history : Array[ProposalRecord]
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
  // 右栏 Context 是否显示。左栏是「多视图 + 收起」所以用枚举；右栏只有
  // 一个视图，收起/展开就是布尔。
  right_visible : Bool
  // 沉浸式无边框：true 时顶栏之上多一条窗控条（信号点 + 拖拽区）。
  // 平台入口按自己有没有无边框窗口决定——Web 恒 false。
  immersive : Bool
  // 左栏结构树搜索查询
  tree_query : String
  // 结构树展开的分组集合（g 值文本；设计稿只在会话内记忆）
  tree_collapsed : Array[String]
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
  // AI 浮动层：锚点 / 是否药丸收起 / 线程卡是否折叠 / 上下文芯片
  ai_anchor : AiAnchor
  ai_pill : Bool
  ai_cards_folded : Bool
  ai_context_chips : Array[String]
  // AI 会话卡（会话内）
  ai_cards : Array[AiCard]
  ai_card_seq : Int
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
  ComposerRun
  RealGenerationFinished(Result[String, String])
  ExplainHandler
  RealExplanationFinished(Result[String, String])
  LanguageLoaded(String)
  EditBlock(String)
  CommitBlock
  DuplicateBlock
  DeleteBlock
  /// 打开/关闭语句插入面板（分类轨点击；Scratch 积木调色板口径）。
  /// 面板给出该分类可插入的**语句骨架**，点一条即插入到当前选中块之后
  /// （没有选中则插到末尾）。这是「无 AI 也能写程序」的核心入口——
  /// 此前 `commit_block` 只能**替换**已有语句，用户从零写不出任何逻辑。
  ToggleStatementPalette(Int)
  /// 插入一条语句骨架：参数是分类下标与分类内模板下标。
  InsertStatement(Int, Int)
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
  RunStep
  RunResume
  AuditJump(Int)
  BlocksCanvasTap(Double, Double)
  BlocksCanvasPress(Double, Double)
  BlocksCanvasDragTo(Double, Double)
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
  ExportRequested
  ExportDirPicked(@services.ServiceTaskResult[String])
  ExportFileWritten(@services.ServiceTaskResult[Unit])
  SetNotice(String)
  // === v4 IDE 壳消息 ===
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
  // 左栏：视图切换 / 关闭 / 搜索 / 分组展开折叠
  SetLeftView(LeftView)
  SetTreeQuery(String)
  ToggleTreeGroup(String)
  /// 显式设置右栏显隐。用**显式布尔**而不是 Toggle：关闭入口在右栏头的 ✕
  /// （只可能关），打开入口在图标栏（只可能开）。共用一个 Toggle 会让
  /// 「点击目标当前不可见」这类情况反向操作，语义不可预测。
  SetRightVisible(Bool)
  // 右栏 Context 页签
  SetContextTab(ContextTab)
  // 底栏：页签切换 / 展开折叠 / 高度拖拽
  SetBottomTab(BottomTab)
  // 问题面板：跳到某子程序草稿的某行（选中 handler + 光标 + 滚动对齐）
  GotoProblem(String, Int)
  ToggleBottom
  // 审计：点击条目（跳到对应积木）/ 处理副作用卡（settled 标记）
  AuditOpen(Int)
  AuditSettle(Int, String)
  AuditSettleAll(String)
  // 最近修改 / Console 清空
  ClearConsole
  // AI 浮动层：锚点循环 / 直接设置 / 药丸 / 折叠卡 / 上下文芯片
  // 沉浸式无边框窗口：三个窗控件 + 拖拽。native 映射到真实窗口请求，
  // Web/无边框未启用时是安全 no-op（不假装能关掉浏览器标签页）。
  WindowClose
  WindowMinimize
  WindowZoom
  WindowDragBy(Double)
  CycleAiAnchor
  SetAiAnchor(AiAnchor)
  ToggleAiPill
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
/// 初始模型：问候样例 + 中文界面 + 假模型；代码草稿按当前语言播种。
/// provider_config 非空时预填面板（key 仍只进会话内存）。
pub fn initial_model(
  provider_config? : ProviderConfig,
  compile_track_available? : Bool = false,
  export_available? : Bool = false,
  immersive? : Bool = false,
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
    prompt_draft: "",
    composer_mode: ComposeEdit,
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
    drag: None,
    runtime_values: @studio_lang.initial_values(program),
    runtime_texts: @studio_lang.initial_texts(program),
    runtime_rows: @studio_lang.initial_rows(program),
    runtime_selections: Map([], capacity=4),
    runtime_seed: @studio_lang.DEFAULT_SEED,
    timer_elapsed: 0,
    undo_stack: [],
    redo_stack: [],
    proposal_history: [],
    block_drag: None,
    workspace: WsVisual,
    pane_live: true,
    pane_blocks: true,
    split_ratio: 0.55,
    left_view: LeftTree,
    right_visible: true,
    immersive,
    tree_query: "",
    tree_collapsed: [],
    ctx_tab: CtxProps,
    bottom_open: false,
    bottom_height: 168.0,
    bottom_tab: BtAudit,
    audit_entries: initial_audit,
    audit_seq: initial_audit.length(),
    log_lines: boot_log_lines(program),
    log_seq: 3,
    recent_changes: [],
    recent_seq: 0,
    ai_anchor: AiCenter,
    ai_pill: false,
    ai_cards_folded: false,
    ai_context_chips: [],
    ai_cards: [],
    ai_card_seq: 0,
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
