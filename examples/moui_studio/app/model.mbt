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
pub(all) struct Model {
  program : @ir.StudioProgram
  language : UiLanguage
  mode : Mode
  // 设计画布缩放：0 = 适应窗口（画布等比铺满画布列，默认行为）；
  // >0 = 固定比例（画布逻辑尺寸 640×zoom，超出视口由滚动接管）。
  design_zoom : Double
  selected_control : String
  selected_handler : String
  code_draft : String
  code_error : String
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
  // 工具链原始输出展开态（默认折叠：诊断优先，日志按需看）
  compile_output_open : Bool
  // 命令面板（技术风 IDE 的键盘优先入口）：显隐 + 过滤查询
  command_palette_open : Bool
  command_palette_query : String
  pending : PendingProposal?
  prompt_draft : String
  prompt_error : String
  provider_mode : ProviderMode
  provider_endpoint : String
  provider_model : String
  provider_key : String
  // 密钥显隐（password_field 的展开态；掩码态下忽略输入防星号写穿）
  provider_key_revealed : Bool
  // AI 面板「模型设置」折叠态（默认收起，常驻三输入框太占面板）
  provider_settings_open : Bool
  // 未保存标记：程序编码 ≠ 最近一次保存/打开/还原基线时为真，标题旁显示 ●
  dirty : Bool
  saved_encoding : String
  draft_encoding : String
  notice : String
  explanation : String
  // AI 请求进行中（真实 provider 生成/讲解）：面板显示加载态
  ai_busy : Bool
  // 积木视图编辑态：选中块（block_chain 下标，-1 = 无）与语句草稿
  selected_block : Int
  block_draft : String
  // 设计画布拖拽态：按下命中控件时建立，松开清除
  drag : DragState?
  // 运行期活状态：跨事件累积的变量值与控件文本（易语言式全局量）
  runtime_values : Map[String, @studio_lang.Value]
  runtime_texts : Map[String, String]
  runtime_rows : Map[String, Array[String]]
  runtime_selections : Map[String, Int]
  // 撤销/重做：变更前快照栈（深度 UNDO_DEPTH）与重做栈
  undo_stack : Array[UndoEntry]
  redo_stack : Array[UndoEntry]
  // 会话内提案历史（不持久化）
  proposal_history : Array[ProposalRecord]
  // 积木画布拖拽（同层重排）进行中
  block_drag : BlocksDragState?
}

///|
pub(all) enum Msg {
  Noop // 设计舞台展示态控件的兜底回调（输入被手势覆盖层拦截，正常不触发）
  SwitchLanguage
  SetMode(Mode)
  SetDesignZoom(Double)
  SelectControl(String)
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
  Undo
  Redo
  SetPrompt(String)
  RealGenerationFinished(Result[String, String])
  ExplainHandler
  RealExplanationFinished(Result[String, String])
  LanguageLoaded(String)
  SelectBlock(Int)
  EditBlock(String)
  CommitBlock
  DeleteBlock
  GenerateProposal
  AcceptProposal
  RejectProposal
  SetProviderMode(ProviderMode)
  SetProviderEndpoint(String)
  SetProviderModel(String)
  SetProviderKey(String)
  ToggleProviderKeyReveal
  ToggleProviderSettings
  DraftLoaded(@services.ServiceTaskResult[String?])
  RunStart
  RunStop
  SetRunTrack(RunTrack)
  CompileRun
  CompileRunFinished(@export.CompileReport)
  CompileRunFailed(String)
  CompileStopped
  CompileJump(Int)
  ToggleCompileOutput
  CommandPaletteOpen
  CommandPaletteClose
  CommandPaletteQuery(String)
  CommandPaletteRun(@core.CommandIntent)
  RunTick
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
  let model = {
    program,
    language: ZhHans,
    mode: ModeDesign,
    design_zoom: 0.0,
    selected_control: "按钮",
    selected_handler: handler_key("按钮", "on_click"),
    code_draft: "",
    code_error: "",
    run_track: Interpret,
    compile_track_available,
    run: None,
    compiled_run: None,
    compile_report: None,
    compile_busy: false,
    compile_output_open: false,
    command_palette_open: false,
    command_palette_query: "",
    pending: None,
    prompt_draft: "",
    prompt_error: "",
    provider_mode: Fake,
    provider_endpoint: endpoint,
    provider_model: model_name,
    provider_key: config.api_key,
    provider_key_revealed: false,
    provider_settings_open: false,
    dirty: false,
    saved_encoding: encoding,
    draft_encoding: encoding,
    notice: "",
    explanation: "",
    ai_busy: false,
    selected_block: -1,
    block_draft: "",
    drag: None,
    runtime_values: @studio_lang.initial_values(program),
    runtime_texts: @studio_lang.initial_texts(program),
    runtime_rows: @studio_lang.initial_rows(program),
    runtime_selections: Map([], capacity=4),
    undo_stack: [],
    redo_stack: [],
    proposal_history: [],
    block_drag: None,
  }
  seed_code_draft(model)
}
