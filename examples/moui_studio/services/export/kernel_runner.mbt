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
    #|/// 领域内核（domain/ir、domain/studio_lang、domain/codec）与 Studio 逐字节同源，
    #|/// 因此解码与执行语义完全一致：点击控件触发对应事件子程序，指令机按
    #|/// start_run_stmts → run_to_end 推进；跑到 `提交数据`/`询问` 闸门会**暂停等
    #|/// 人工确认**（确认/拒绝是真实按钮），确认前零真实动作。审计日志逐步留痕。
    #|/// 离线即可完整跑通（假模型/确定性执行，无网络、无服务依赖）。
    #|
    #|///|
    #|pub(all) enum Msg {
    #|  Trigger(String, @ir.EventKind) // （控件名，事件）被触发
    #|  Pick(String, Int) // 列表/表格选中某行 → 内容改变
    #|  EditText(String, String) // 输入框文本改变 → 内容改变
    #|  ToggleCheck(String) // 勾选框切换（视觉态，指令机语义外）
    #|  Answer(Bool) // 闸门应答：true=确认，false=拒绝
    #|}
    #|
    #|///|
    #|pub(all) struct Model {
    #|  program : @ir.StudioProgram
    #|  texts : Map[String, String] // 控件当前文本（label/button/text_field）
    #|  values : Map[String, @studio_lang.Value] // DSL 变量
    #|  rows : Map[String, Array[String]] // 列表/表格行
    #|  selections : Map[String, Int] // 列表/表格选中行
    #|  checks : Map[String, Bool] // 勾选框视觉态（与 Studio 同口径，指令机外）
    #|  notice : String
    #|  run_label : String
    #|  run : @studio_lang.RunState?
    #|}
    #|
    #|///|
    #|/// 初始模型：解码内嵌项目，按初始文本/变量/行播种。
    #|pub fn Model::new() -> Model {
    #|  let (program, notice) = match @codec.decode_program(project_json()) {
    #|    Ok(decoded) => (decoded, "")
    #|    Err(errors) => (@ir.empty_program(), "项目数据无效：\{errors.length()} 个错误")
    #|  }
    #|  {
    #|    program,
    #|    texts: @studio_lang.initial_texts(program),
    #|    values: @studio_lang.initial_values(program),
    #|    rows: @studio_lang.initial_rows(program),
    #|    selections: Map([], capacity=4),
    #|    checks: Map([], capacity=4),
    #|    notice,
    #|    run_label: "",
    #|    run: None,
    #|  }
    #|}
    #|
    #|///|
    #|/// 触发某控件事件的子程序：启动指令机并一步运行到终止态（完成/闸门/失败）。
    #|/// texts/values/rows 与运行态共享引用，set_text/append_row/声明即时回写。
    #|fn run_handler(
    #|  model : Model,
    #|  control : String,
    #|  event : @ir.EventKind,
    #|) -> Model {
    #|  match @ir.find_handler(model.program, control, event) {
    #|    None => model
    #|    Some(handler) => {
    #|      let run = @studio_lang.start_run_stmts(
    #|        handler.body,
    #|        model.texts,
    #|        model.values,
    #|        model.rows,
    #|      )
    #|      // 列表/表格选中态：把当前选择灌进运行态（selected_row 读它）
    #|      for item in model.program.controls {
    #|        match model.selections.get(item.name) {
    #|          Some(index) => run.selections[item.name] = index
    #|          None => ()
    #|        }
    #|      }
    #|      @studio_lang.run_to_end(run)
    #|      {
    #|        ..model,
    #|        run: Some(run),
    #|        run_label: "\{handler.control_name}@\{handler.event.tag()}",
    #|        notice: "",
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn update(model : Model, msg : Msg) -> Model {
    #|  match msg {
    #|    Trigger(control, event) => run_handler(model, control, event)
    #|    Pick(control, index) => {
    #|      model.selections[control] = index
    #|      run_handler(model, control, @ir.OnChange)
    #|    }
    #|    EditText(control, new_text) => {
    #|      model.texts[control] = new_text
    #|      run_handler(model, control, @ir.OnChange)
    #|    }
    #|    ToggleCheck(control) => {
    #|      // 勾选是视觉态（与 Studio 同口径）：切换不触发子程序
    #|      model.checks[control] = !model.checks.get(control).unwrap_or(false)
    #|      model
    #|    }
    #|    Answer(decision) =>
    #|      match model.run {
    #|        None => model
    #|        Some(run) => {
    #|          @studio_lang.answer_gate(run, decision)
    #|          @studio_lang.run_to_end(run)
    #|          model
    #|        }
    #|      }
    #|  }
    #|}
    #|
    #|///|
    #|/// 运行舞台的绝对布局节点：按 IR 控件矩形给每个子控件分配帧（位置）。
    #|/// 尺寸由调用方的 `@views.frame` 包裹强制为设计宽高，因此子控件精确等于
    #|/// 设计稿所见即所得，且不依赖 core 的 tight 重测标志（导出产物只依赖
    #|/// 已发布的 `wzzc-dev/moui`，版本必须可用）。（与 Studio 的 StageLayout
    #|/// 同一手法，内联在此保持导出产物自包含、不依赖 Studio 应用包。）
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
    #|  let size = ctx.constraints.constrain(
    #|    @core.Size::new(
    #|      width=@ir.DESIGN_WIDTH.to_double(),
    #|      height=@ir.DESIGN_HEIGHT.to_double(),
    #|    ),
    #|  )
    #|  let frames : Array[@core.Rect] = []
    #|  for rect in self.rects {
    #|    frames.push(
    #|      @core.Rect::new(
    #|        x=rect.origin.x,
    #|        y=rect.origin.y,
    #|        width=rect.size.width,
    #|        height=rect.size.height,
    #|      ),
    #|    )
    #|  }
    #|  @core.ViewLayoutResult::new(size~, child_frames=frames)
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
    #|/// 单个控件的舞台渲染（表单应用域 6 类）：尺寸/位置由舞台帧驱动，
    #|/// 与设计画布同款观感。
    #|fn stage_widget(model : Model, control : @ir.Control) -> @moui.View[Msg] {
    #|  let value = model.texts.get(control.name).unwrap_or(control.text)
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
    #|      let items = model.rows.get(control.name).unwrap_or([])
    #|      let rows : Array[@moui.View[Msg]] = []
    #|      let mut index = 0
    #|      while index < items.length() && index < max_rows {
    #|        let selected = model.selections.get(control.name).unwrap_or(0) == index
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
    #|fn gate_card(gate : @studio_lang.Gate) -> @moui.View[Msg] {
    #|  let prompt = match gate.kind {
    #|    @studio_lang.Submit => "程序想把数据送到「\{gate.prompt}」，要送出的内容：\{gate.payload}。确认吗？"
    #|    @studio_lang.Ask => gate.prompt
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
    #|fn audit_dot(op : @studio_lang.StepOp) -> @moui.View[Msg] {
    #|  let color = match op {
    #|    @studio_lang.OpAssign => @graphics.Color::rgba(r=0.30, g=0.52, b=0.90)
    #|    @studio_lang.OpMessage => @graphics.Color::rgba(r=0.30, g=0.62, b=0.36)
    #|    @studio_lang.OpGate => @graphics.Color::rgba(r=0.78, g=0.26, b=0.20)
    #|    @studio_lang.OpCommand => @graphics.Color::rgba(r=0.55, g=0.40, b=0.75)
    #|    @studio_lang.OpCondition => @graphics.Color::rgba(r=0.85, g=0.55, b=0.16)
    #|    @studio_lang.OpLoop => @graphics.Color::rgba(r=0.20, g=0.55, b=0.58)
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
    #|pub fn view(model : Model) -> @moui.View[Msg] {
    #|  // 运行舞台：真实控件按设计坐标绝对布局（640×480，所见即所得）
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
    #|  let stage = @views.container(
    #|    stage_layout(stage_widgets, stage_rects),
    #|    width=@ir.DESIGN_WIDTH.to_double(),
    #|    height=@ir.DESIGN_HEIGHT.to_double(),
    #|    background=@graphics.Color::rgba(r=0.97, g=0.97, b=0.98),
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
    #|  let items : Array[@moui.View[Msg]] = [
    #|    @views.row([
    #|      @views.text(model.program.window.title).title(),
    #|      @views.text("由 MoUI Studio 导出", role=Caption),
    #|    ]),
    #|  ]
    #|  if model.notice != "" {
    #|    items.push(@views.text(model.notice))
    #|  }
    #|  items.push(stage)
    #|  match model.run {
    #|    None => ()
    #|    Some(run) => {
    #|      match run.gate {
    #|        Some(gate) => items.push(gate_card(gate))
    #|        None => ()
    #|      }
    #|      // 变量表：与 Studio 同一承诺（运行即讲解的数据面）
    #|      let names : Array[String] = []
    #|      for name in run.vars.keys() {
    #|        names.push(name)
    #|      }
    #|      names.sort()
    #|      if names.length() > 0 {
    #|        items.push(@views.text("变量").title())
    #|        for name in names {
    #|          match run.vars.get(name) {
    #|            Some(value) =>
    #|              items.push(
    #|                @views.row([
    #|                  @views.text(name, width=140.0),
    #|                  @views.text(@studio_lang.value_to_text(value), width=260.0),
    #|                ]),
    #|              )
    #|            None => ()
    #|          }
    #|        }
    #|      }
    #|      if run.messages.length() > 0 {
    #|        items.push(@views.text("消息").title())
    #|        for message in run.messages {
    #|          items.push(@views.text(message))
    #|        }
    #|      }
    #|      items.push(
    #|        @views.text("审计日志 · \{model.run_label}").title(),
    #|      )
    #|      for record in run.audit {
    #|        items.push(
    #|          @views.row([audit_dot(record.op), @views.text(record.detail, width=400.0)]),
    #|        )
    #|      }
    #|      match run.error {
    #|        Some(error) =>
    #|          items.push(
    #|            @views.text("运行错误（行 \{error.line()}）：\{error.a()}"),
    #|          )
    #|        None => ()
    #|      }
    #|    }
    #|  }
    #|  @views
    #|  .card(
    #|    @views.scroll_view(@views.column(items), width=920.0, height=560.0, shows_indicator=true),
    #|    width=960.0,
    #|    height=600.0,
    #|    padding=10.0,
    #|  )
    #|  // 品牌主题：与 MoUI Studio 同源朱砂色（印泥朱砂主色派生浅色全角色盘，
    #|  // 课堂/路演的确定性外观，不随系统深色漂移）
    #|  .theme(runner_theme())
    #|}
    #|
    #|///|
    #|/// 导出应用的品牌主题（与 Studio 的 studio_theme 同 seed 同 scheme；
    #|/// 内联在此避免 runner 依赖 app 包）。
    #|fn runner_theme() -> @core.Theme {
    #|  @views.theme(
    #|    palette=@core.ColorPalette::from_seed(
    #|      primary=@core.Color::rgba(r=0.78, g=0.26, b=0.20),
    #|      Light,
    #|    ),
    #|  )
    #|}
    #|
    #|///|
    #|/// TEA 组合根：无 IO、无服务依赖——导出的应用是纯本地的确定性执行器。
    #|pub fn program() -> @moui.Program[Model, Msg] {
    #|  @moui.Program::new(
    #|    init=() => (Model::new(), @moui.Effect::none()),
    #|    update=(model, msg) => (update(model, msg), @moui.Effect::none()),
    #|    view~,
    #|  )
    #|}
    #|
  source
}
