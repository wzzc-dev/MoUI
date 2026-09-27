///|
/// MoMao Studio TEA 模型：程序 IR + 界面语言 + 三模式 + 运行态 +
/// 待采纳提案 + provider 会话内存。纯数据，无服务无视图。

///|
pub(all) enum Mode {
  ModeDesign
  ModeBlocks
  ModeCode
  ModePreview
  ModeRun
}

///|
pub(all) enum ProviderMode {
  Fake
  Real
}

///|
/// 运行态：当前子程序 + 指令机状态 + 勾选框 UI 态。
/// checks 只在 app 层（运行期视觉状态，不进指令机语义）。
pub(all) struct RunModel {
  handler_label : String
  state : @momao_lang.RunState
  checks : Map[String, Bool]
  // 单步模式：为真时 RunTick 不自动推进，仅 RunStep 走一条指令
  single_step : Bool
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
  program : @ir.MomaoProgram
  selected_control : String
  selected_handler : String
  code_draft : String
  coalesce_key : String
}

///|
/// 设计画布拖拽态：被拖控件 + 拖拽种类（移动/缩放）。
pub(all) struct DragState {
  control : String
  kind : DragKind
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
  program : @ir.MomaoProgram
  language : UiLanguage
  mode : Mode
  selected_control : String
  selected_handler : String
  code_draft : String
  code_error : String
  run : RunModel?
  pending : PendingProposal?
  prompt_draft : String
  prompt_error : String
  provider_mode : ProviderMode
  provider_endpoint : String
  provider_model : String
  provider_key : String
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
  runtime_values : Map[String, @momao_lang.Value]
  runtime_texts : Map[String, String]
  // 撤销/重做：变更前快照栈（深度 UNDO_DEPTH）与重做栈
  undo_stack : Array[UndoEntry]
  redo_stack : Array[UndoEntry]
}

///|
pub(all) enum Msg {
  SwitchLanguage
  SetMode(Mode)
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
  RunStart
  RunStop
  RunTick
  RunStep
  RunResume
  RunToggle(String, Bool)
  AnswerGate(Bool)
  ControlClicked(String)
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
pub fn empty_program() -> @ir.MomaoProgram {
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
/// 初始模型：问候样例 + 中文界面 + 假模型；代码草稿按当前语言播种。
/// provider_config 非空时预填面板（key 仍只进会话内存）。
pub fn initial_model(provider_config? : ProviderConfig) -> Model {
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
  let model = {
    program,
    language: ZhHans,
    mode: ModeDesign,
    selected_control: "按钮",
    selected_handler: handler_key("按钮", "on_click"),
    code_draft: "",
    code_error: "",
    run: None,
    pending: None,
    prompt_draft: "",
    prompt_error: "",
    provider_mode: Fake,
    provider_endpoint: endpoint,
    provider_model: model_name,
    provider_key: config.api_key,
    notice: "",
    explanation: "",
    ai_busy: false,
    selected_block: -1,
    block_draft: "",
    drag: None,
    runtime_values: @momao_lang.initial_values(program),
    runtime_texts: @momao_lang.initial_texts(program),
    undo_stack: [],
    redo_stack: [],
  }
  seed_code_draft(model)
}
