///|
/// MoMao 导出的可执行应用（通用 TEA runner）。
///
/// 领域内核（domain/ir、domain/momao_lang、domain/codec）与 Studio 逐字节同源，
/// 因此解码与执行语义完全一致：点击控件触发对应事件子程序，指令机按
/// start_run_stmts → run_to_end 推进；跑到 `提交数据`/`询问` 闸门会**暂停等
/// 人工确认**（确认/拒绝是真实按钮），确认前零真实动作。审计日志逐步留痕。
/// 离线即可完整跑通（假模型/确定性执行，无网络、无服务依赖）。

///|
pub(all) enum Msg {
  Trigger(String, @ir.EventKind) // （控件名，事件）被触发
  Pick(String, Int) // 列表/表格选中某行 → 内容改变
  EditText(String, String) // 输入框文本改变 → 内容改变
  Answer(Bool) // 闸门应答：true=确认，false=拒绝
}

///|
pub(all) struct Model {
  program : @ir.MomaoProgram
  texts : Map[String, String] // 控件当前文本（label/button/text_field）
  values : Map[String, @momao_lang.Value] // DSL 变量
  rows : Map[String, Array[String]] // 列表/表格行
  selections : Map[String, Int] // 列表/表格选中行
  notice : String
  run_label : String
  run : @momao_lang.RunState?
}

///|
/// 初始模型：解码内嵌项目，按初始文本/变量/行播种。
pub fn Model::new() -> Model {
  let (program, notice) = match @codec.decode_program(project_json()) {
    Ok(decoded) => (decoded, "")
    Err(errors) => (@ir.empty_program(), "项目数据无效：\{errors.length()} 个错误")
  }
  {
    program,
    texts: @momao_lang.initial_texts(program),
    values: @momao_lang.initial_values(program),
    rows: @momao_lang.initial_rows(program),
    selections: Map([], capacity=4),
    notice,
    run_label: "",
    run: None,
  }
}

///|
/// 触发某控件事件的子程序：启动指令机并一步运行到终止态（完成/闸门/失败）。
/// texts/values/rows 与运行态共享引用，set_text/append_row/声明即时回写。
fn run_handler(
  model : Model,
  control : String,
  event : @ir.EventKind,
) -> Model {
  match @ir.find_handler(model.program, control, event) {
    None => model
    Some(handler) => {
      let run = @momao_lang.start_run_stmts(
        handler.body,
        model.texts,
        model.values,
        model.rows,
      )
      // 列表/表格选中态：把当前选择灌进运行态（selected_row 读它）
      for item in model.program.controls {
        match model.selections.get(item.name) {
          Some(index) => run.selections[item.name] = index
          None => ()
        }
      }
      @momao_lang.run_to_end(run)
      {
        ..model,
        run: Some(run),
        run_label: "\{handler.control_name}@\{handler.event.tag()}",
        notice: "",
      }
    }
  }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Trigger(control, event) => run_handler(model, control, event)
    Pick(control, index) => {
      model.selections[control] = index
      run_handler(model, control, @ir.OnChange)
    }
    EditText(control, new_text) => {
      model.texts[control] = new_text
      run_handler(model, control, @ir.OnChange)
    }
    Answer(decision) =>
      match model.run {
        None => model
        Some(run) => {
          @momao_lang.answer_gate(run, decision)
          @momao_lang.run_to_end(run)
          model
        }
      }
  }
}

///|
/// 单个控件的极简渲染（表单应用域 6 类）。
fn control_view(model : Model, control : @ir.Control) -> @moui.View[Msg] {
  let value = model.texts.get(control.name).unwrap_or(control.text)
  match control.kind {
    @ir.Label => @views.text(value)
    @ir.Button =>
      @views.button(
        value,
        on_click=Trigger(control.name, @ir.OnClick),
        width=control.width.to_double(),
        height=control.height.to_double(),
      )
    @ir.TextField =>
      @views.text_field(
        value,
        on_input=new_text => EditText(control.name, new_text),
        width=control.width.to_double(),
      )
    @ir.CheckBox => @views.text("[ ] \{value}")
    @ir.ListBox | @ir.Table => {
      let items = model.rows.get(control.name).unwrap_or([])
      let rows : Array[@moui.View[Msg]] = []
      let mut index = 0
      while index < items.length() {
        let selected = model.selections.get(control.name).unwrap_or(0) == index
        let prefix = if selected { "▶ " } else { "· " }
        rows.push(
          @views.button(
            "\{prefix}\{items[index]}",
            on_click=Pick(control.name, index),
          ),
        )
        index = index + 1
      }
      @views.column(rows)
    }
  }
}

///|
/// 闸门卡：确认前零真实动作；展示「将要送出什么、送到哪」。
fn gate_card(gate : @momao_lang.Gate) -> @moui.View[Msg] {
  let prompt = match gate.kind {
    @momao_lang.Submit => "确认送出「\{gate.payload}」到 \{gate.prompt}？"
    @momao_lang.Ask => gate.prompt
  }
  @views.column([
    @views.text(prompt),
    @views.button("确认", on_click=Answer(true)),
    @views.button("拒绝", on_click=Answer(false)),
  ])
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  let items : Array[@moui.View[Msg]] = [
    @views.text(model.program.window.title).title(),
  ]
  if model.notice != "" {
    items.push(@views.text(model.notice))
  }
  for control in model.program.controls {
    items.push(control_view(model, control))
  }
  match model.run {
    None => ()
    Some(run) => {
      match run.gate {
        Some(gate) => items.push(gate_card(gate))
        None => ()
      }
      if run.messages.length() > 0 {
        items.push(@views.text("消息").title())
        for message in run.messages {
          items.push(@views.text(message))
        }
      }
      items.push(
        @views.text("审计日志 · \{model.run_label}").title(),
      )
      for record in run.audit {
        items.push(@views.text(record.detail))
      }
      match run.error {
        Some(error) =>
          items.push(
            @views.text("运行错误（行 \{error.line()}）：\{error.a()}"),
          )
        None => ()
      }
    }
  }
  @views.scroll_view(@views.column(items), width=680.0, height=560.0)
}

///|
/// TEA 组合根：无 IO、无服务依赖——导出的应用是纯本地的确定性执行器。
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::new(
    init=() => (Model::new(), @moui.Effect::none()),
    update=(model, msg) => (update(model, msg), @moui.Effect::none()),
    view~,
  )
}
