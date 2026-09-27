///|
/// 纯状态转移：除文件对话框/读写外的一切。返回 (Model, Effect)。

///|
/// 当前语言的翻译器（视图与状态消息共用）。
pub fn translator(model : Model) -> @i18n.Translator {
  translator_for(model.language)
}

///|
/// 选中 handler 的程序对象（按 控件名@事件 反查）。
pub fn current_handler(model : Model) -> @ir.Handler? {
  let control = handler_control_of(model.selected_handler)
  let event = handler_event_of(model.selected_handler)
  match (control, event) {
    (Some(name), Some(tag)) =>
      match @ir.parse_event_kind(tag) {
        Some(event_kind) => @ir.find_handler(model.program, name, event_kind)
        None => None
      }
    _ => None
  }
}

///|
fn handler_control_of(key : String) -> String? {
  let chars : Array[Char] = []
  for c in key {
    chars.push(c)
  }
  let mut at = -1
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '@' {
      at = i
      break
    }
    i = i + 1
  }
  if at <= 0 {
    None
  } else {
    let buf = StringBuilder()
    let mut j = 0
    while j < at {
      buf.write_char(chars[j])
      j = j + 1
    }
    Some(buf.to_string())
  }
}

///|
fn handler_event_of(key : String) -> String? {
  let chars : Array[Char] = []
  for c in key {
    chars.push(c)
  }
  let mut at = -1
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '@' {
      at = i
      break
    }
    i = i + 1
  }
  if at < 0 || at + 1 >= chars.length() {
    None
  } else {
    let buf = StringBuilder()
    let mut j = at + 1
    while j < chars.length() {
      buf.write_char(chars[j])
      j = j + 1
    }
    Some(buf.to_string())
  }
}

///|
/// 控件支持的事件清单（供新建子程序下拉）。
pub fn control_events(control : @ir.Control) -> Array[@ir.EventKind] {
  let events : Array[@ir.EventKind] = []
  if control.kind.supports_event(@ir.OnClick) {
    events.push(@ir.OnClick)
  }
  if control.kind.supports_event(@ir.OnChange) {
    events.push(@ir.OnChange)
  }
  events
}

///|
/// 控件重命名：同步其 handler 的 control_name（程序内引用一致）。
fn rename_control_everywhere(
  program : @ir.MomaoProgram,
  from : String,
  to : String,
) -> @ir.MomaoProgram {
  let controls : Array[@ir.Control] = []
  for control in program.controls {
    if control.name == from {
      controls.push(@ir.Control::{ ..control, name: to, })
    } else {
      controls.push(control)
    }
  }
  let handlers : Array[@ir.Handler] = []
  for handler in program.handlers {
    if handler.control_name == from {
      handlers.push(@ir.Handler::{ ..handler, control_name: to, })
    } else {
      handlers.push(handler)
    }
  }
  @ir.MomaoProgram::{ ..program, controls, handlers, }
}

///|
/// 用当前语言的规范源码替换某 handler 的 body（代码视图提交）。
fn commit_code(model : Model) -> Model {
  match current_handler(model) {
    None => { ..model, code_error: "", }
    Some(handler) =>
      if model.code_draft.trim().to_string() == "" {
        { ..model, code_error: "", }
      } else {
        match
          @momao_lang.parse_handler_body(
            model.code_draft,
            model.language.dsl_language(),
          ) {
          Err(error) =>
            { ..model, code_error: error_message(translator(model), error), }
          Ok(body) => {
            let updated = @ir.Handler::{
              ..handler,
              body: body.map(t => t.stmt),
            }
            let handlers : Array[@ir.Handler] = []
            for existing in model.program.handlers {
              if existing.control_name == handler.control_name &&
                existing.event.tag() == handler.event.tag() {
                handlers.push(updated)
              } else {
                handlers.push(existing)
              }
            }
            {
              ..model,
              program: { ..model.program, handlers, },
              code_error: "",
            }
          }
        }
      }
  }
}

///|
/// 初始播种：把选中子程序渲染成当前语言的源码草稿。
pub fn seed_code_draft(model : Model) -> Model {
  sync_code_draft(model)
}

///|
/// 选中 handler 变化时刷新代码草稿（用当前语言渲染）。
fn sync_code_draft(model : Model) -> Model {
  match current_handler(model) {
    None => { ..model, code_draft: "", code_error: "", }
    Some(handler) =>
      {
        ..model,
        code_draft: @momao_lang.render_handler(
          handler,
          model.language.dsl_language(),
        ),
        code_error: "",
      }
  }
}

///|
/// 启动运行：解析当前 handler 源码 → 指令机。
fn start_run(model : Model) -> Model {
  let committed = commit_code(model)
  match current_handler(committed) {
    None => { ..committed, notice: "", }
    Some(handler) => {
      let language = committed.language.dsl_language()
      let body = match
        @momao_lang.parse_handler_body(committed.code_draft, language) {
        Ok(body) => body
        Err(error) =>
          return {
            ..committed,
            notice: error_message(translator(committed), error),
          }
      }
      let state = @momao_lang.start_run(
        body,
        committed.runtime_texts,
        committed.runtime_values,
        @momao_lang.initial_rows(committed.program),
      )
      let run = RunModel::{
        handler_label: "\{handler.control_name}@\{handler.event.tag()}",
        state,
      }
      { ..committed, run: Some(run), mode: ModeRun, notice: "", }
    }
  }
}

///|
/// 运行推进：每次 tick 执行若干条指令（聚光灯可跟随）。
fn run_tick(model : Model) -> Model {
  match model.run {
    None => model
    Some(run) => {
      if run.state.status is @momao_lang.Running {
        let mut i = 0
        while i < 6 && run.state.status is @momao_lang.Running {
          @momao_lang.step_once(run.state)
          i = i + 1
        }
      }
      merge_run_back(model)
    }
  }
}

///|
/// 运行结束时把变量/控件文本并回活状态（下一次事件从这里继续）。
fn merge_run_back(model : Model) -> Model {
  match model.run {
    None => model
    Some(run) =>
      if run.state.status is @momao_lang.Completed ||
        run.state.status is @momao_lang.Failed {
        for key in run.state.vars.keys() {
          match run.state.vars.get(key) {
            Some(value) => model.runtime_values[key] = value
            None => ()
          }
        }
        for key in run.state.texts.keys() {
          match run.state.texts.get(key) {
            Some(text) => model.runtime_texts[key] = text
            None => ()
          }
        }
        model
      } else {
        model
      }
  }
}

///|
/// 采纳提案：校验链通过才应用；失败整单拒绝并展示全部原因。
fn accept_proposal(model : Model) -> Model {
  match model.pending {
    None => model
    Some(pending) =>
      if !pending.valid {
        {
          ..model,
          notice: text(translator(model), "app.status.proposal_invalid"),
        }
      } else {
        let next = @proposals.apply_proposal(model.program, pending.proposal)
        let cleared : Model = {
          ..model,
          program: next,
          pending: None,
          prompt_draft: "",
          selected_control: first_control_name(next.controls),
          run: None,
          runtime_values: @momao_lang.initial_values(next),
          runtime_texts: @momao_lang.initial_texts(next),
        }
        {
          ..cleared,
          notice: text(translator(cleared), "app.status.proposal_accepted"),
        }
      }
  }
}

///|
/// 生成提案：假模型（默认）或真实模型回填文案走同一条严格校验链。
/// 真实 provider 的网络副作用在 update_with_services 中发起；
/// 这里只负责把「已得到的补全文本」变成待采纳提案。
pub fn proposal_from_completion(model : Model, completion : String) -> Model {
  match @proposals.decode_proposal(completion) {
    Err(_) =>
      {
        ..model,
        prompt_error: text(translator(model), "app.status.proposal_invalid"),
      }
    Ok(proposal) => {
      let errors = @proposals.validate_proposal(model.program, proposal)
      let messages : Array[String] = []
      for error in errors {
        messages.push(proposal_error_text(translator(model), error))
      }
      let diff = @proposals.proposal_diff(model.program, proposal)
      let summary = match model.language {
        ZhHans => proposal.summary_zh
        En => proposal.summary_en
      }
      let pending : PendingProposal = {
        proposal,
        diff,
        summary,
        errors: messages,
        valid: errors.is_empty(),
      }
      { ..model, pending: Some(pending), prompt_error: "", }
    }
  }
}

///|
/// 提案错误的本地化文本（可读性/结构/语言分层）。
pub fn proposal_error_text(
  t : @i18n.Translator,
  error : @proposals.ProposalError,
) -> String {
  match error {
    @proposals.Readability(target) => "可读性：\{target}"
    @proposals.Structural(issue) => structural_error_text(t, issue)
    @proposals.LanguageIssue(name) => "语言层：\{name}"
    @proposals.UnknownControl(name) => "未知控件：\{name}"
    @proposals.UnknownHandler(name) => "未知子程序：\{name}"
    @proposals.DuplicateHandler(name) => "子程序重复：\{name}"
    @proposals.InvalidJson => "JSON 不合法"
    @proposals.BadVersion(_) => "提案版本不支持"
    @proposals.MissingField(field) => "缺少字段：\{field}"
    @proposals.BadControlKind(text) => "未知控件类型：\{text}"
    @proposals.BadEventKind(text) => "未知事件类型：\{text}"
    @proposals.BadStatement(text) => "语句不合法：\{text}"
    @proposals.BadExpr(text) => "表达式不合法：\{text}"
  }
}

///|
/// 结构错误本地化（IR 层）。
pub fn structural_error_text(
  t : @i18n.Translator,
  error : @ir.IrError,
) -> String {
  match error {
    @ir.DuplicateControlName(name) => "控件重名：\{name}"
    @ir.InvalidControlName(name) => "控件名不合法：\{name}"
    @ir.DuplicateVariableName(name) => "变量重名：\{name}"
    @ir.DuplicateHandler(name) => "子程序重复：\{name}"
    @ir.UnknownControlInHandler(name) =>
      "子程序指向不存在的控件：\{name}"
    @ir.UnsupportedEvent(control, _event) =>
      "控件 \{control} 不支持该事件"
    @ir.TooManyControls => "控件超出预算"
    @ir.TooManyVariables => "变量超出预算"
    @ir.TooManyHandlers => "子程序超出预算"
    @ir.TooManyStatements(_count) => "语句超出预算"
    @ir.LoopTooDeep(_depth) => "循环嵌套过深"
    @ir.ExprTooDeep(_depth) => "表达式过深"
  }
}

///|
/// 纯转移（文件与网络相关消息由 update_with_services 处理）。
pub fn update_pure(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  match msg {
    SwitchLanguage => {
      let committed = commit_code(model)
      let switched = { ..committed, language: switch(model.language), }
      let next = if committed.code_error == "" {
        sync_code_draft(switched)
      } else {
        switched
      }
      (next, @moui.Effect::none())
    }
    SetMode(mode) => {
      let switched = sync_code_draft({ ..model, mode, })
      (switched, @moui.Effect::none())
    }
    SelectControl(name) =>
      ({ ..model, selected_control: name, }, @moui.Effect::none())
    CanvasPress(x, y) => {
      let hit = hit_test_control(model.program.controls, x, y)
      match hit {
        Some(control) => {
          // 命中即选中并建立拖拽态：记录按下点相对控件原点的偏移
          let drag = DragState::{
            control: control.name,
            offset_x: x.to_int() - control.x,
            offset_y: y.to_int() - control.y,
          }
          (
            { ..model, selected_control: control.name, drag: Some(drag), },
            @moui.Effect::none(),
          )
        }
        None =>
          ({ ..model, selected_control: "", drag: None, }, @moui.Effect::none())
      }
    }
    CanvasDragTo(x, y) =>
      // 拖拽移动选中控件；夹取规则在 @ir（控件完整落在设计画布内）
      match model.drag {
        None => (model, @moui.Effect::none())
        Some(drag) => {
          let controls : Array[@ir.Control] = []
          for control in model.program.controls {
            if control.name == drag.control {
              controls.push(
                control
                .with_rect_field(@ir.RectX, x.to_int() - drag.offset_x)
                .with_rect_field(@ir.RectY, y.to_int() - drag.offset_y),
              )
            } else {
              controls.push(control)
            }
          }
          (
            { ..model, program: { ..model.program, controls, }, },
            @moui.Effect::none(),
          )
        }
      }
    CanvasRelease(_x, _y) => ({ ..model, drag: None, }, @moui.Effect::none())
    SetControlText(name, value) => {
      let controls : Array[@ir.Control] = []
      for control in model.program.controls {
        if control.name == name {
          controls.push(@ir.Control::{ ..control, text: value, })
        } else {
          controls.push(control)
        }
      }
      (
        { ..model, program: { ..model.program, controls, }, },
        @moui.Effect::none(),
      )
    }
    SetControlName(name, value) => {
      if value == "" || @ir.find_control(model.program, value) is Some(_) {
        return (model, @moui.Effect::none())
      }
      if !@ir.control_name_syntax_valid(value) {
        return (model, @moui.Effect::none())
      }
      let program = rename_control_everywhere(model.program, name, value)
      let next = {
        ..model,
        program,
        selected_control: value,
        selected_handler: match handler_control_of(model.selected_handler) {
          Some(current) =>
            if current == name {
              handler_key(
                value,
                handler_event_of(model.selected_handler).unwrap_or("on_click"),
              )
            } else {
              model.selected_handler
            }
          None => model.selected_handler
        },
      }
      (sync_code_draft(next), @moui.Effect::none())
    }
    SetControlItems(name, value) => {
      let items = split_lines(value)
      let controls : Array[@ir.Control] = []
      for control in model.program.controls {
        if control.name == name {
          controls.push(@ir.Control::{ ..control, items, })
        } else {
          controls.push(control)
        }
      }
      (
        { ..model, program: { ..model.program, controls, }, },
        @moui.Effect::none(),
      )
    }
    SetControlRect(name, field, raw) =>
      // 属性框整数解析失败（空串/非数字）即忽略本次输入
      match parse_design_int(raw) {
        None => (model, @moui.Effect::none())
        Some(value) => {
          let controls : Array[@ir.Control] = []
          for control in model.program.controls {
            if control.name == name {
              controls.push(control.with_rect_field(field, value))
            } else {
              controls.push(control)
            }
          }
          (
            { ..model, program: { ..model.program, controls, }, },
            @moui.Effect::none(),
          )
        }
      }
    AddControl(kind) => {
      let id = @ir.next_control_id(model.program)
      let name = fresh_control_name(model.program, kind)
      let control = @ir.Control::{
        id,
        kind,
        name,
        text: "",
        x: 40 + id % 5 * 30,
        y: 40 + id % 7 * 30,
        width: match kind {
          @ir.Button => 100
          @ir.Label => 140
          @ir.TextField => 160
          @ir.CheckBox => 110
          @ir.ListBox => 140
          @ir.Table => 200
        },
        height: match kind {
          @ir.Button => 32
          @ir.Label => 30
          @ir.TextField => 30
          @ir.CheckBox => 26
          @ir.ListBox => 110
          @ir.Table => 120
        },
        items: [],
      }
      (
        {
          ..model,
          program: {
            ..model.program,
            controls: append_control(model.program.controls, control),
          },
          selected_control: name,
        },
        @moui.Effect::none(),
      )
    }
    DeleteControl(name) => {
      let controls : Array[@ir.Control] = []
      for control in model.program.controls {
        if control.name != name {
          controls.push(control)
        }
      }
      let handlers : Array[@ir.Handler] = []
      for handler in model.program.handlers {
        if handler.control_name != name {
          handlers.push(handler)
        }
      }
      (
        {
          ..model,
          program: { ..model.program, controls, handlers, },
          selected_control: "",
          selected_handler: match handler_control_of(model.selected_handler) {
            Some(current) =>
              if current == name {
                ""
              } else {
                model.selected_handler
              }
            None => model.selected_handler
          },
        },
        @moui.Effect::none(),
      )
    }
    SelectHandler(key) =>
      (
        sync_code_draft({ ..model, selected_handler: key, }),
        @moui.Effect::none(),
      )
    EditCode(source) => ({ ..model, code_draft: source, }, @moui.Effect::none())
    SetPrompt(value) =>
      (
        { ..model, prompt_draft: value, prompt_error: "", },
        @moui.Effect::none(),
      )
    ExplainHandler =>
      (
        { ..model, explanation: local_explanation(model), },
        @moui.Effect::none(),
      )
    SelectBlock(index) => {
      let blocks = block_chain_of(model)
      let draft = match block_at(blocks, index) {
        Some(item) =>
          if item.path.length() == 0 {
            ""
          } else {
            match current_handler(model) {
              None => ""
              Some(handler) =>
                match @blocks.stmt_at(handler.body, item.path) {
                  Some(stmt) =>
                    @momao_lang.render_stmts(
                      [stmt],
                      model.language.dsl_language(),
                    )
                    .trim_end()
                    .to_string()
                  None => ""
                }
            }
          }
        None => ""
      }
      (
        { ..model, selected_block: index, block_draft: draft, },
        @moui.Effect::none(),
      )
    }
    EditBlock(source) =>
      ({ ..model, block_draft: source, }, @moui.Effect::none())
    CommitBlock => (commit_block(model), @moui.Effect::none())
    DeleteBlock => (delete_block(model), @moui.Effect::none())
    GenerateProposal => {
      let completion = @proposals.fake_model_completion(
        model.prompt_draft,
        model.program,
      )
      (proposal_from_completion(model, completion), @moui.Effect::none())
    }
    AcceptProposal => (accept_proposal(model), @moui.Effect::none())
    RejectProposal =>
      (
        {
          ..model,
          pending: None,
          notice: text(translator(model), "app.status.proposal_rejected"),
        },
        @moui.Effect::none(),
      )
    SetProviderMode(mode) =>
      ({ ..model, provider_mode: mode, }, @moui.Effect::none())
    SetProviderEndpoint(value) =>
      ({ ..model, provider_endpoint: value, }, @moui.Effect::none())
    SetProviderModel(value) =>
      ({ ..model, provider_model: value, }, @moui.Effect::none())
    SetProviderKey(value) =>
      ({ ..model, provider_key: value, }, @moui.Effect::none())
    RunStart => (start_run(model), @moui.Effect::none())
    RunStop => ({ ..model, run: None, }, @moui.Effect::none())
    RunTick => (run_tick(model), @moui.Effect::none())
    AnswerGate(decision) =>
      match model.run {
        None => (model, @moui.Effect::none())
        Some(run) => {
          @momao_lang.answer_gate(run.state, decision)
          (merge_run_back(model), @moui.Effect::none())
        }
      }
    ControlClicked(name) => {
      let committed = commit_code(model)
      run_handler(committed, name, "on_click")
    }
    ControlChanged(name, value) => {
      let committed = commit_code(model)
      // 受控输入框：输入值必须先落进活状态文本表，否则字段显示回退、
      // 取文本 读到旧值。run.state.texts 与 runtime_texts 同一张表，
      // 双写使任一侧为真身时都成立。
      committed.runtime_texts[name] = value
      match committed.run {
        Some(run) => run.state.texts[name] = value
        None => ()
      }
      run_handler(committed, name, "on_change")
    }
    SelectTemplate(index) => {
      let samples = @proposals.all_samples()
      let program = if index >= 0 && index < samples.length() {
        samples[index]
      } else {
        model.program
      }
      let next = {
        ..model,
        program,
        pending: None,
        run: None,
        runtime_values: @momao_lang.initial_values(program),
        runtime_texts: @momao_lang.initial_texts(program),
      }
      (
        sync_code_draft({
          ..next,
          selected_control: first_control_name(program.controls),
          selected_handler: first_handler_key(program.handlers),
        }),
        @moui.Effect::none(),
      )
    }
    SetNotice(notice) => ({ ..model, notice, }, @moui.Effect::none())
    _ => (model, @moui.Effect::none())
  }
}

///|
/// 运行指定控件事件的子程序（运行态入口）。
fn run_handler(
  model : Model,
  control : String,
  event_tag : String,
) -> (Model, @moui.Effect[Msg]) {
  match @ir.parse_event_kind(event_tag) {
    None => (model, @moui.Effect::none())
    Some(event) =>
      match @ir.find_handler(model.program, control, event) {
        None => (model, @moui.Effect::none())
        Some(handler) => {
          let state = @momao_lang.start_run_stmts(
            handler.body,
            model.runtime_texts,
            model.runtime_values,
            @momao_lang.initial_rows(model.program),
          )
          (
            {
              ..model,
              run: Some(RunModel::{
                handler_label: handler_key(control, event_tag),
                state,
              }),
              mode: ModeRun,
            },
            @moui.Effect::none(),
          )
        }
      }
  }
}

///|
fn switch(language : UiLanguage) -> UiLanguage {
  match language {
    ZhHans => En
    En => ZhHans
  }
}

///|
/// 新控件默认名：类型 + 序号（自解释命名，可读性契约的默认实践）。
fn fresh_control_name(
  program : @ir.MomaoProgram,
  kind : @ir.ControlKind,
) -> String {
  let base = match kind {
    @ir.Button => "按钮"
    @ir.Label => "标签"
    @ir.TextField => "输入框"
    @ir.CheckBox => "选择框"
    @ir.ListBox => "列表框"
    @ir.Table => "表格"
  }
  let mut index = 1
  let mut name = base
  while @ir.find_control(program, name) is Some(_) {
    index = index + 1
    name = "\{base}\{index}"
  }
  name
}

///|
/// 控件数组追加（spread 语法不可用，显式拷贝）。
fn append_control(
  controls : Array[@ir.Control],
  control : @ir.Control,
) -> Array[@ir.Control] {
  let copied : Array[@ir.Control] = []
  for existing in controls {
    copied.push(existing)
  }
  copied.push(control)
  copied
}

///|
/// 按换行切分并去空白行（控件选项编辑用）。
pub fn split_lines(value : String) -> Array[String] {
  let lines : Array[String] = []
  let current : Array[Char] = []
  let chars : Array[Char] = []
  for c in value {
    chars.push(c)
  }
  for c in chars {
    if c == '\n' {
      let line = chars_to_string(current).trim().to_string()
      if line != "" {
        lines.push(line)
      }
      let mut j = current.length()
      while j > 0 {
        ignore(current.pop())
        j = j - 1
      }
    } else {
      current.push(c)
    }
  }
  let tail = chars_to_string(current).trim().to_string()
  if tail != "" {
    lines.push(tail)
  }
  lines
}

///|
/// 属性框整数解析：仅接受 1-4 位纯数字（负号/小数/空串拒绝）。
fn parse_design_int(raw : String) -> Int? {
  if raw.length() == 0 || raw.length() > 4 {
    return None
  }
  let mut value = 0
  for c in raw {
    let code = c.to_int()
    if code < 0x30 || code > 0x39 {
      return None
    }
    value = value * 10 + (code - 0x30)
  }
  Some(value)
}

///|
fn chars_to_string(chars : Array[Char]) -> String {
  let buf = StringBuilder()
  for c in chars {
    buf.write_char(c)
  }
  buf.to_string()
}

///|
/// 首个控件名（空数组安全）。
pub fn first_control_name(controls : Array[@ir.Control]) -> String {
  if controls.length() > 0 {
    controls[0].name
  } else {
    ""
  }
}

///|
/// 首个子程序定位键（空数组安全）。
pub fn first_handler_key(handlers : Array[@ir.Handler]) -> String {
  if handlers.length() > 0 {
    handler_key(handlers[0].control_name, handlers[0].event.tag())
  } else {
    ""
  }
}

///|
/// 本地讲解（假模型路径）：note 作头 + 编号的规范步骤。
/// 语言中立、确定性、离线可用；真实 provider 讲解走网络路径。
pub fn local_explanation(model : Model) -> String {
  match current_handler(model) {
    None => ""
    Some(handler) => {
      let note = match model.language {
        ZhHans =>
          if handler.note_zh == "" {
            handler.note_en
          } else {
            handler.note_zh
          }
        En =>
          if handler.note_en == "" {
            handler.note_zh
          } else {
            handler.note_en
          }
      }
      let buf = StringBuilder()
      if note != "" {
        buf.write_string(note)
        buf.write_string("\n")
      }
      let mut index = 1
      for item in @blocks.block_chain(handler.body) {
        if item.text == "" {
          continue
        }
        buf.write_string("\{index}. ")
        buf.write_string(item.text)
        buf.write_string("\n")
        index = index + 1
      }
      buf.to_string()
    }
  }
}

///|
/// 当前选中 handler 的积木链（无选中子程序 = 空链）。
pub fn block_chain_of(model : Model) -> Array[@blocks.BlockItem] {
  match current_handler(model) {
    None => []
    Some(handler) => @blocks.block_chain(handler.body)
  }
}

///|
fn block_at(
  blocks : Array[@blocks.BlockItem],
  index : Int,
) -> @blocks.BlockItem? {
  if index < 0 || index >= blocks.length() {
    None
  } else {
    Some(blocks[index])
  }
}

///|
/// 积木编辑回写：草稿解析成单条语句 → 按路径替换 → IR 更新 →
/// 代码视图草稿与积木选择同步刷新（三视图同源）。
fn commit_block(model : Model) -> Model {
  match current_handler(model) {
    None => model
    Some(handler) => {
      let blocks = block_chain_of(model)
      match block_at(blocks, model.selected_block) {
        None => model
        Some(item) =>
          if item.path.length() == 0 {
            model
          } else {
            match
              @momao_lang.parse_handler_body(
                model.block_draft,
                model.language.dsl_language(),
              ) {
              Err(_) =>
                {
                  ..model,
                  notice: text(translator(model), "app.status.parse_error"),
                }
              Ok(body) =>
                if body.length() == 0 {
                  model
                } else {
                  let updated = @blocks.replace_stmt_at(
                    handler.body,
                    item.path,
                    body[0].stmt,
                  )
                  let next = replace_handler_body(model, handler, updated)
                  // 同步代码视图（同一份 IR 的另一种渲染）
                  let synced = sync_code_draft(next)
                  { ..synced, notice: "", }
                }
            }
          }
      }
    }
  }
}

///|
/// 积木删除回写：按路径删除语句并同步其他视图。
fn delete_block(model : Model) -> Model {
  match current_handler(model) {
    None => model
    Some(handler) => {
      let blocks = block_chain_of(model)
      match block_at(blocks, model.selected_block) {
        None => model
        Some(item) =>
          if item.path.length() == 0 {
            model
          } else {
            let updated = @blocks.delete_stmt_at(handler.body, item.path)
            let next = replace_handler_body(model, handler, updated)
            let synced = sync_code_draft(next)
            { ..synced, selected_block: -1, block_draft: "", }
          }
      }
    }
  }
}

///|
/// 用新 body 替换选中 handler（其余 handler 原样）。
fn replace_handler_body(
  model : Model,
  handler : @ir.Handler,
  body : Array[@ir.Stmt],
) -> Model {
  let updated = @ir.Handler::{ ..handler, body, }
  let handlers : Array[@ir.Handler] = []
  for existing in model.program.handlers {
    if existing.control_name == handler.control_name &&
      existing.event.tag() == handler.event.tag() {
      handlers.push(updated)
    } else {
      handlers.push(existing)
    }
  }
  { ..model, program: { ..model.program, handlers, }, }
}
