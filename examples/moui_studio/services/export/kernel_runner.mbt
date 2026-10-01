///|
/// 导出的可执行 runner 源码（由 tools/sync_kernel 生成，勿手改）。
/// 模板位于 tools/export_runner_template/runner.mbt；
/// 模板改动不同步时 `--check` 会报 DRIFT。

///|
pub fn runner_source() -> String {
  let source =
    #|///|
    #|/// MoUI Studio 导出的可执行应用（通用 TEA runner）。
    #|///
    #|/// 领域内核（domain/ir、domain/studio_lang、domain/codec）与 Studio 逐字节同源。
    #|/// 但事件执行走**编译轨**：`app/generated_handlers.mbt` 是由 MoUI Studio 从
    #|/// 程序 IR 生成、真正参与 `moon build` 的 MoonBit 源码，由 `@compiled_runtime`
    #|/// 执行面直接执行（无指令流解释器）。跑到 `提交数据`/`询问` 闸门会**暂停等
    #|/// 人工确认**（确认/拒绝是真实按钮），确认前零真实动作。审计日志逐步留痕。
    #|/// 离线即可完整跑通（确定性执行，无网络、无服务依赖）。
    #|
    #|///|
    #|pub(all) enum Msg {
    #|  Trigger(String, @ir.EventKind) // （控件名，事件）被触发
    #|  Pick(String, Int) // 列表/表格选中某行 → 内容改变
    #|  EditText(String, String) // 输入框文本改变 → 内容改变
    #|  ToggleCheck(String) // 勾选框切换（视觉态，编译轨语义外）
    #|  Answer(Bool) // 闸门应答：true=确认，false=拒绝
    #|  ToggleDiag // 展开/收起诊断面板（变量 / 消息 / 审计）
    #|}
    #|
    #|///|
    #|pub(all) struct Model {
    #|  program : @ir.StudioProgram
    #|  machine : @compiled_runtime.Runtime // 编译轨运行状态（文本/变量/行/审计/闸门）
    #|  checks : Map[String, Bool] // 勾选框视觉态（与 Studio 同口径，执行面外）
    #|  notice : String
    #|  run_label : String
    #|  /// 诊断面板是否展开。**默认收起**——导出应用是一个「应用」，首屏应该是
    #|  /// 用户设计的那张表单；变量/审计是开发者视角，按需展开。
    #|  diag_open : Bool
    #|}
    #|
    #|///|
    #|/// 初始模型：解码内嵌项目，按程序初值播种编译轨运行时。
    #|pub fn Model::new() -> Model {
    #|  let (program, notice) = match @codec.decode_program(project_json()) {
    #|    Ok(decoded) => (decoded, "")
    #|    Err(errors) => (@ir.empty_program(), "项目数据无效：\{errors.length()} 个错误")
    #|  }
    #|  {
    #|    program,
    #|    machine: @compiled_runtime.runtime_for_program(program),
    #|    checks: Map([], capacity=4),
    #|    notice,
    #|    run_label: "",
    #|    diag_open: false,
    #|  }
    #|}
    #|
    #|///|
    #|/// 窗口标题：项目里写的那一个（native 组合根用它当窗口名）。
    #|/// 空标题回退产品名，避免出现一个没有标题的窗口。
    #|pub fn window_title() -> String {
    #|  let model = Model::new()
    #|  if model.program.window.title == "" {
    #|    "MoUI App"
    #|  } else {
    #|    model.program.window.title
    #|  }
    #|}
    #|
    #|///|
    #|/// 窗口尺寸：项目的设计尺寸（native 窗口按它开，与 Web 宿主页同口径）。
    #|pub fn window_size() -> (Double, Double) {
    #|  let model = Model::new()
    #|  (
    #|    model.program.window.width.to_double(),
    #|    model.program.window.height.to_double(),
    #|  )
    #|}
    #|
    #|///|
    #|/// 触发某控件事件的子程序：按 (控件, 事件) 分派到生成源码里的 handler，
    #|/// 由编译轨运行时推进到终止态（完成/闸门/失败）。
    #|///
    #|/// **事件起点推进随机种子**：`run_handler` 本身不重置 `rng`（那是宿主的
    #|/// 责任），所以这里必须显式接续——否则同一个按钮点十次都从同一个种子起算，
    #|/// `随机数` 给出十个相同结果，用户读到的是「点了没反应」。推进一格后
    #|/// `run_handler` 的快照记下这个起点，闸门重放仍逐位可复现。
    #|fn run_event(
    #|  model : Model,
    #|  control : String,
    #|  event : @ir.EventKind,
    #|) -> Model {
    #|  match studio_dispatch_handler(control, event.tag()) {
    #|    None => model
    #|    Some(handler) => {
    #|      model.machine.rng = @compiled_runtime.next_seed(model.machine.rng)
    #|      ignore(@compiled_runtime.run_handler(model.machine, handler))
    #|      {
    #|        ..model,
    #|        run_label: "\{control}@\{event.tag()}",
    #|        notice: "",
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn update(model : Model, msg : Msg) -> Model {
    #|  match msg {
    #|    Trigger(control, event) => run_event(model, control, event)
    #|    Pick(control, index) => {
    #|      model.machine.selections[control] = index
    #|      run_event(model, control, @ir.OnChange)
    #|    }
    #|    EditText(control, new_text) => {
    #|      model.machine.texts[control] = new_text
    #|      run_event(model, control, @ir.OnChange)
    #|    }
    #|    ToggleCheck(control) => {
    #|      // 勾选是视觉态（与 Studio 同口径）：切换不触发子程序
    #|      model.checks[control] = !model.checks.get(control).unwrap_or(false)
    #|      model
    #|    }
    #|    Answer(decision) => {
    #|      ignore(@compiled_runtime.answer_gate(model.machine, decision))
    #|      model
    #|    }
    #|    ToggleDiag => { ..model, diag_open: !model.diag_open, }
    #|  }
    #|}
    #|
    #|///|
    #|/// 运行舞台的绝对布局节点：按 IR 控件矩形给每个子控件分配帧（位置），
    #|/// 并按可用空间**等比缩放**。
    #|///
    #|/// 与 Studio 的 `StageLayout` 同一手法（内联在此保持导出产物自包含）：
    #|/// 舞台按 `fit_scale` 缩放后居中，子帧用 `child_frames_tight` 声明，
    #|/// 子树按最终帧重新测量。这样无论窗口多大，**设计稿的 640×480 都完整可
    #|/// 见**——旧版这里没有缩放、外层还写死 960×600 的卡片，于是 640×480 的
    #|/// 窗口把应用右缘与底部直接裁掉（实测溢出右 450pt、下 154pt，名单右半边
    #|/// 与审计标题都在窗口外）。
    #|priv struct StageLayout {
    #|  rects : Array[@core.Rect] // 与 children 一一对应（IR 控件 x/y/width/height）
    #|}
    #|
    #|///|
    #|impl @core.ViewNode for StageLayout with fn identity(_self) {
    #|  @core.ViewIdentity::new(kind="StageLayout")
    #|}
    #|
    #|///|
    #|impl @core.ViewNode for StageLayout with fn declaration(_self) {
    #|  @core.ViewDeclaration::constant()
    #|}
    #|
    #|///|
    #|impl @core.ViewNode for StageLayout with fn layout(self, ctx) {
    #|  // 缩放映射：舞台在可用空间内等比缩放后居中。三层（本节点、外层容器、
    #|  // 指针换算）没有第二份实现——导出应用不做命中换算，控件自己收事件。
    #|  let avail_w = (ctx.constraints.max.width).max(0.0)
    #|  let avail_h = (ctx.constraints.max.height).max(0.0)
    #|  let scale = fit_scale(
    #|    avail_w,
    #|    avail_h,
    #|    @ir.DESIGN_WIDTH.to_double(),
    #|    @ir.DESIGN_HEIGHT.to_double(),
    #|  )
    #|  let stage_w = @ir.DESIGN_WIDTH.to_double() * scale
    #|  let stage_h = @ir.DESIGN_HEIGHT.to_double() * scale
    #|  let ox = ((avail_w - stage_w) / 2.0).max(0.0)
    #|  let oy = ((avail_h - stage_h) / 2.0).max(0.0)
    #|  let size = ctx.constraints.constrain(
    #|    @core.Size::new(width=avail_w, height=avail_h),
    #|  )
    #|  let frames : Array[@core.Rect] = []
    #|  for rect in self.rects {
    #|    frames.push(
    #|      @core.Rect::new(
    #|        x=ox + rect.origin.x * scale,
    #|        y=oy + rect.origin.y * scale,
    #|        width=rect.size.width * scale,
    #|        height=rect.size.height * scale,
    #|      ),
    #|    )
    #|  }
    #|  @core.ViewLayoutResult::new(size~, child_frames=frames, child_frames_tight=true)
    #|}
    #|
    #|///|
    #|impl @core.ViewNode for StageLayout with fn semantics(_self) {
    #|  @core.ViewSemanticsInfo::new(composition=Transparent)
    #|}
    #|
    #|///|
    #|fn stage_layout(
    #|  children : Array[@moui.View[Msg]],
    #|  rects : Array[@core.Rect],
    #|) -> @moui.View[Msg] {
    #|  @core.View::from_node(StageLayout::{ rects, }, children=_node => children)
    #|}
    #|
    #|///|
    #|/// 「适应窗口」比例：min(可用宽/设计宽, 可用高/设计高)，钳在 [0.4, 1]。
    #|///
    #|/// 上限 1 = 不放大（放大只会让像素发虚）；下限 0.4 保证再小的窗口也还能
    #|/// 看清内容。与 Studio 的 `fit_scale` 同一口径。
    #|pub fn fit_scale(
    #|  avail_width : Double,
    #|  avail_height : Double,
    #|  design_w : Double,
    #|  design_h : Double,
    #|) -> Double {
    #|  if avail_width <= 0.0 ||
    #|    avail_height <= 0.0 ||
    #|    design_w <= 0.0 ||
    #|    design_h <= 0.0 {
    #|    1.0
    #|  } else {
    #|    (avail_width / design_w).min(avail_height / design_h).max(0.4).min(1.0)
    #|  }
    #|}
    #|
    #|///|
    #|/// 单个控件的舞台渲染（表单应用域 6 类）：尺寸/位置由舞台帧驱动，
    #|/// 与设计画布同款观感。
    #|fn stage_widget(model : Model, control : @ir.Control) -> @moui.View[Msg] {
    #|  let value = model.machine.texts.get(control.name).unwrap_or(control.text)
    #|  match control.kind {
    #|    @ir.Label => @views.text(value, align=TextStart)
    #|    @ir.Button =>
    #|      @views.button(value, on_click=Trigger(control.name, @ir.OnClick))
    #|    @ir.TextField =>
    #|      @views.text_field(
    #|        value,
    #|        on_input=new_text => EditText(control.name, new_text),
    #|      )
    #|    @ir.CheckBox =>
    #|      @views.checkbox(
    #|        value,
    #|        checked=model.checks.get(control.name).unwrap_or(false),
    #|        on_change=_checked => ToggleCheck(control.name),
    #|      )
    #|    @ir.ListBox | @ir.Table => {
    #|      // 列表框/表格是带视口的实物：行高 24，按设计高度截断可见行
    #|      let max_rows = if control.height < 24 {
    #|        1
    #|      } else {
    #|        control.height / 24
    #|      }
    #|      let items = model.machine.rows.get(control.name).unwrap_or([])
    #|      let rows : Array[@moui.View[Msg]] = []
    #|      let mut index = 0
    #|      while index < items.length() && index < max_rows {
    #|        let selected = model.machine.selections.get(control.name).unwrap_or(0) == index
    #|        let prefix = if selected { "▶ " } else { "· " }
    #|        rows.push(
    #|          @views.button(
    #|            "\{prefix}\{items[index]}",
    #|            on_click=Pick(control.name, index),
    #|            variant=Tonal,
    #|            height=24.0,
    #|          ),
    #|        )
    #|        index = index + 1
    #|      }
    #|      @views.column(rows, spacing=0.0)
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|/// 闸门卡：确认前零真实动作；展示「将要送出什么、送到哪」。
    #|fn gate_card(gate : @compiled_runtime.Gate) -> @moui.View[Msg] {
    #|  let prompt = match gate.kind {
    #|    @compiled_runtime.Submit => "程序想把数据送到「\{gate.prompt}」，要送出的内容：\{gate.payload}。确认吗？"
    #|    @compiled_runtime.Ask => gate.prompt
    #|  }
    #|  @views.column([
    #|    @views.callout("需要你的确认", prompt, tone=@style.Warning, width=420.0),
    #|    @views.row([
    #|      @views.button("确认送出", on_click=Answer(true), variant=Primary),
    #|      @views.button("拒绝", on_click=Answer(false), variant=Outline),
    #|    ]),
    #|  ])
    #|}
    #|
    #|///|
    #|/// 审计色点：与 Studio 同一套语义色（赋值蓝/信息框绿/闸门朱砂/命令紫/条件橙/循环青）。
    #|fn audit_dot(op : @compiled_runtime.StepOp) -> @moui.View[Msg] {
    #|  let color = match op {
    #|    @compiled_runtime.OpAssign => @graphics.Color::rgba(r=0.30, g=0.52, b=0.90)
    #|    @compiled_runtime.OpMessage => @graphics.Color::rgba(r=0.30, g=0.62, b=0.36)
    #|    @compiled_runtime.OpGate => @graphics.Color::rgba(r=0.78, g=0.26, b=0.20)
    #|    @compiled_runtime.OpCommand => @graphics.Color::rgba(r=0.55, g=0.40, b=0.75)
    #|    @compiled_runtime.OpCondition => @graphics.Color::rgba(r=0.85, g=0.55, b=0.16)
    #|    @compiled_runtime.OpLoop => @graphics.Color::rgba(r=0.20, g=0.55, b=0.58)
    #|  }
    #|  @views.container(
    #|    @views.empty(),
    #|    background=color,
    #|    corner_radius=4.0,
    #|    width=8.0,
    #|    height=8.0,
    #|  )
    #|}
    #|
    #|///|
    #|/// 应用主视图：**填满窗口**，舞台按可用空间等比缩放。
    #|///
    #|/// 旧版把整棵树塞进一张写死 960×600 的卡片，而窗口只有项目声明的
    #|/// 640×480——于是应用右缘与底部被窗口直接裁掉（实测溢出右 450pt、下
    #|/// 154pt：名单右半边、审计标题都在窗外）。现在：
    #|///
    #|/// 1. 根节点按**真实视口**定尺（`ViewEnvironment::viewport_size`），
    #|///    不再出现比窗口大的硬编码尺寸；
    #|/// 2. 舞台是唯一的伸缩区（吃满剩余高度），`StageLayout` 在里面等比缩放，
    #|///    所以 640×480 的设计永完整可见；
    #|/// 3. 变量/消息/审计收进**默认收起的诊断面板**——导出应用首屏应该是用户
    #|///    设计的那张表单，而不是开发者的调试台。需要时一键展开。
    #|pub fn view(model : Model) -> @moui.View[Msg] {
    #|  view_with_viewport(model, default_viewport_size())
    #|}
    #|
    #|///|
    #|/// 视口未知时的回退尺寸：项目声明的窗口大小（native 入口与 Web 宿主页
    #|/// 都按它开窗）。真实运行走 `runtime_view`，由运行时给出实际视口。
    #|pub fn default_viewport_size() -> @core.Size {
    #|  let model = Model::new()
    #|  @core.Size::new(
    #|    width=model.program.window.width.to_double(),
    #|    height=model.program.window.height.to_double(),
    #|  )
    #|}
    #|
    #|///|
    #|/// 带视口的主视图：壳的各段高度都按真实视口算。
    #|///
    #|/// **这是 native GUI 不裁内容的唯一入口**——写死任何尺寸都会在小窗口下
    #|/// 溢出。Web 端的 `main.mbt` 也调它（canvas 尺寸随窗口变）。
    #|pub fn view_with_viewport(model : Model, viewport : @core.Size) -> @moui.View[Msg] {
    #|  let width = if viewport.width > 0.0 {
    #|    viewport.width
    #|  } else {
    #|    640.0
    #|  }
    #|  let height = if viewport.height > 0.0 {
    #|    viewport.height
    #|  } else {
    #|    480.0
    #|  }
    #|  // 壳高分配：标题条 40 + 诊断条 32 + 内外边距 16。舞台吃剩下的全部高度。
    #|  let chrome = TITLE_BAR_HEIGHT + DIAG_BAR_HEIGHT + STAGE_INSET * 2.0
    #|  let stage_height = (height - chrome).max(120.0)
    #|  let stage = stage_view(model, (width - STAGE_INSET * 2.0).max(120.0), stage_height)
    #|  let bands : Array[@moui.View[Msg]] = [
    #|    title_bar(model, width),
    #|    diag_bar(model, width),
    #|    @views.padding_xy(stage, horizontal=STAGE_INSET, vertical=STAGE_INSET),
    #|  ]
    #|  if model.diag_open {
    #|    bands.push(diag_panel(model, height))
    #|  }
    #|  @views.container(
    #|    @views.column(bands, spacing=0.0).frame(width~, height~),
    #|    background=@graphics.Color::rgba(r=0.949, g=0.953, b=0.965),
    #|    width~,
    #|    height~,
    #|    padding=0.0,
    #|  )
    #|  // 产品主题：浅色 + IDE 蓝强调——与 Studio 的 studio_product_theme
    #|  // （app/theme.mbt）同一组值（跨 bundle 不能 import，改动必须两处同步），
    #|  // 课堂/路演的确定性外观，不随系统深色漂移
    #|  .theme(runner_theme())
    #|}
    #|
    #|///|
    #|/// 标题条高（含应用名与副标题）。
    #|pub const TITLE_BAR_HEIGHT : Double = 40.0
    #|
    #|///|
    #|/// 诊断条高（展开/收起按钮那一行）。
    #|pub const DIAG_BAR_HEIGHT : Double = 32.0
    #|
    #|///|
    #|/// 舞台四周留白（应用窗口不该贴着宿主窗口边缘）。
    #|pub const STAGE_INSET : Double = 8.0
    #|
    #|///|
    #|/// 标题条：应用名 + 由谁导出 + 诊断面板开关。
    #|fn title_bar(model : Model, width : Double) -> @moui.View[Msg] {
    #|  // 标题用**自然宽**（不写死）：`@views.text` 的 width 是**最小宽**，
    #|  // 给一个「够宽」的值反而把这一格撑成那个宽度，右侧按钮被推出窗口
    #|  // （实测写 `width-160` 时溢出 144pt）。行本身定宽后，权重 spacer 会
    #|  // 吸收多余空间，窄窗下先挤 spacer、再挤副标题。
    #|  let cells : Array[@moui.View[Msg]] = [
    #|    @views.text(model.program.window.title).title(),
    #|  ]
    #|  if width >= 560.0 {
    #|    cells.push(@views.text("由 MoUI Studio 导出 · 编译轨", role=Caption))
    #|  }
    #|  cells.push(@views.spacer(min_length=8.0, weight=1.0))
    #|  cells.push(
    #|    @views.button(
    #|      if model.diag_open { "收起诊断" } else { "变量与日志" },
    #|      on_click=ToggleDiag,
    #|      variant=Outline,
    #|      height=24.0,
    #|    ),
    #|  )
    #|  // **行必须显式定宽**：`@views.text` 的 width 是**最小宽**，一条没有
    #|  // 定宽的 row 只会量到「子节点宽度之和」，权重 spacer 分不到 slack，
    #|  // 右侧按钮就被推到窗口外（实测 640 宽时按钮落在 x=712）。这是 Studio
    #|  // `fill_row` 注释里记录的同一个陷阱，导出侧同样适用。
    #|  @views.padding_xy(
    #|    @views.row(cells, spacing=8.0, align=Center).frame(
    #|      width=(width - 24.0).max(80.0),
    #|    ),
    #|    horizontal=12.0,
    #|    vertical=0.0,
    #|  )
    #|}
    #|
    #|///|
    #|/// 诊断条：一行状态读数（运行子程序 + 变量数），展开时才有详情。
    #|///
    #|/// `width` 必须传：`@views.text` 的 width 是**最小宽**，内容比它宽就长出去
    #|/// 被窗口裁掉——窄窗口下左侧标签必须主动收窄，右侧读数干脆让位
    #|/// （实测 480 宽时「审计 N」越界 48pt）。
    #|fn diag_bar(model : Model, width : Double) -> @moui.View[Msg] {
    #|  let vars : Array[String] = []
    #|  for name in model.machine.vars.keys() {
    #|    vars.push(name)
    #|  }
    #|  let label = if model.run_label == "" {
    #|    "就绪 · 点击控件试试"
    #|  } else {
    #|    "最近事件：\{model.run_label}"
    #|  }
    #|  // 同 title_bar：自然宽，别把这一格撑大。
    #|  let cells : Array[@moui.View[Msg]] = [
    #|    @views.text(label, role=Caption),
    #|  ]
    #|  if width >= 560.0 {
    #|    cells.push(@views.spacer(min_length=8.0, weight=1.0))
    #|    cells.push(@views.text("变量 \{vars.length()}", role=Caption))
    #|    cells.push(@views.text("审计 \{model.machine.audit.length()}", role=Caption))
    #|  }
    #|  @views.padding_xy(
    #|    @views.row(cells, spacing=12.0, align=Center).frame(
    #|      width=(width - 24.0).max(80.0),
    #|    ),
    #|    horizontal=12.0,
    #|    vertical=0.0,
    #|  )
    #|}
    #|
    #|///|
    #|/// 舞台：真实控件按设计坐标绝对布局，缩放交给 `StageLayout`。
    #|///
    #|/// 外层容器给**可用盒**（不是设计尺寸）：`StageLayout` 在里面等比缩放并
    #|/// 居中，因此窗口比 640×480 小也不会裁掉内容。
    #|fn stage_view(
    #|  model : Model,
    #|  avail_width : Double,
    #|  avail_height : Double,
    #|) -> @moui.View[Msg] {
    #|  let stage_widgets : Array[@moui.View[Msg]] = []
    #|  let stage_rects : Array[@core.Rect] = []
    #|  for control in model.program.controls {
    #|    // frame 包裹把设计宽高变成紧约束：舞台帧给位置、frame 给尺寸。
    #|    stage_widgets.push(
    #|      @views.frame(
    #|        stage_widget(model, control),
    #|        width=control.width.to_double(),
    #|        height=control.height.to_double(),
    #|      ),
    #|    )
    #|    stage_rects.push(
    #|      @core.Rect::new(
    #|        x=control.x.to_double(),
    #|        y=control.y.to_double(),
    #|        width=control.width.to_double(),
    #|        height=control.height.to_double(),
    #|      ),
    #|    )
    #|  }
    #|  @views.container(
    #|    stage_layout(stage_widgets, stage_rects),
    #|    width=avail_width,
    #|    height=avail_height,
    #|    background=product_surface(),
    #|    corner_radius=10.0,
    #|    border=Some(
    #|      @graphics.BorderStyle::new(
    #|        brush=@graphics.Brush::solid(
    #|          @graphics.Color::rgba(r=0.75, g=0.77, b=0.82),
    #|        ),
    #|        width=1.5,
    #|      ),
    #|    ),
    #|    padding=0.0,
    #|  )
    #|}
    #|
    #|///|
    #|/// 应用窗口底色（舞台底板）。
    #|///
    #|/// 是函数而不是 `let`：`Color` 是 struct，MoonBit 的顶层 `let` 只收
    #|/// 常量构造式，`::rgba(...)` 调用不在此列（编译期会报 4029）。
    #|pub fn product_surface() -> @graphics.Color {
    #|  @graphics.Color::rgba(r=0.97, g=0.97, b=0.98)
    #|}
    #|
    #|///|
    #|/// 诊断面板（默认收起）：变量 / 消息 / 审计 / 闸门 / 错误。
    #|///
    #|/// 高度按可用高度扣掉舞台与壳之后给一个上限，内部滚动——面板再长也不会
    #|/// 把窗口顶出内容。
    #|fn diag_panel(model : Model, viewport_height : Double) -> @moui.View[Msg] {
    #|  let panel_height = (viewport_height * 0.38).max(120.0).min(280.0)
    #|  let items : Array[@moui.View[Msg]] = []
    #|  if model.notice != "" {
    #|    items.push(@views.text(model.notice))
    #|  }
    #|  match model.machine.gate {
    #|    Some(gate) => items.push(gate_card(gate))
    #|    None => ()
    #|  }
    #|  let names : Array[String] = []
    #|  for name in model.machine.vars.keys() {
    #|    names.push(name)
    #|  }
    #|  names.sort()
    #|  if names.length() > 0 {
    #|    items.push(@views.text("变量").title())
    #|    for name in names {
    #|      match model.machine.vars.get(name) {
    #|        Some(value) =>
    #|          items.push(
    #|            @views.row([
    #|              @views.text(name, width=140.0),
    #|              @views.text(@compiled_runtime.value_to_text(value), width=260.0),
    #|            ]),
    #|          )
    #|        None => ()
    #|      }
    #|    }
    #|  }
    #|  if model.machine.messages.length() > 0 {
    #|    items.push(@views.text("消息").title())
    #|    for message in model.machine.messages {
    #|      items.push(@views.text(message))
    #|    }
    #|  }
    #|  items.push(@views.text("审计日志 · \{model.run_label}").title())
    #|  for record in model.machine.audit {
    #|    items.push(
    #|      @views.row([audit_dot(record.op), @views.text(record.detail, width=400.0)]),
    #|    )
    #|  }
    #|  match model.machine.error {
    #|    Some(error) =>
    #|      items.push(@views.text("运行错误（行 \{error.line}）：\{error.a}"))
    #|    None => ()
    #|  }
    #|  @views.container(
    #|    @views.scroll_view(
    #|      @views.column(items, spacing=4.0),
    #|      width=viewport_height.max(200.0),
    #|      height=panel_height,
    #|      shows_indicator=true,
    #|    ),
    #|    background=product_surface(),
    #|    corner_radius=8.0,
    #|    height=panel_height,
    #|    padding=8.0,
    #|  )
    #|}
    #|
    #|///|
    #|/// 导出应用的产品主题（与 Studio 的 studio_product_theme 同值同 scheme；
    #|/// 内联在此避免 runner 依赖 app 包）。
    #|fn runner_theme() -> @core.Theme {
    #|  @views.theme(
    #|    palette=@core.ColorPalette::from_seed(
    #|      primary=@core.Color::rgba(r=0.208, g=0.455, b=0.941),
    #|      Light,
    #|    ),
    #|  )
    #|}
    #|
    #|///|
    #|/// TEA 组合根：无 IO、无服务依赖——导出的应用是纯本地的确定性执行器。
    #|///
    #|/// 用 `new_with_environment`（**不是** `new`）拿真实视口：`view` 需要知道
    #|/// 窗口到底多大，才能把舞台缩放到刚好装下。用 `new` 的话视图只能猜尺寸，
    #|/// 猜大了就被窗口裁掉——那正是「窗口显示不全」的根因。
    #|pub fn program() -> @moui.Program[Model, Msg] {
    #|  @moui.Program::new_with_environment(
    #|    init=() => (Model::new(), @moui.Effect::none()),
    #|    update=(model, msg) => (update(model, msg), @moui.Effect::none()),
    #|    view=(model, env) => view_with_viewport(model, env.viewport_size()),
    #|  )
    #|}
    #|
  source
}
