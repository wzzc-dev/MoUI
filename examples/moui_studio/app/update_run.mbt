///|
/// 运行域状态转移：启动/停止/推进、闸门应答、运行期控件事件。

///|
/// 启动运行：解析当前 handler 源码 → 指令机。
fn start_run(model : Model) -> Model {
  let committed = commit_code(model)
  match current_handler(committed) {
    None => { ..committed, notice: "", }
    Some(handler) => {
      let language = committed.language.dsl_language()
      let body = match
        @studio_lang.parse_handler_body(committed.code_draft, language) {
        Ok(body) => body
        Err(error) =>
          return {
            ..committed,
            notice: error_message(translator(committed), error),
          }
      }
      let state = @studio_lang.start_run(
        body,
        committed.runtime_texts,
        committed.runtime_values,
        committed.runtime_rows,
      )
      for key in committed.runtime_selections.keys() {
        match committed.runtime_selections.get(key) {
          Some(index) => state.selections[key] = index
          None => ()
        }
      }
      let run = RunModel::{
        handler_label: "\{handler.control_name}@\{handler.event.tag()}",
        state,
        checks: Map([], capacity=8),
        single_step: false,
      }
      { ..committed, run: Some(run), mode: ModeRun, notice: "", }
    }
  }
}

///|
/// 编译轨启动：同一程序 IR → `compiled_runtime` 执行面（native 可达）。
/// 与解释轨共用控制名/事件查找；找不到 handler 与解释轨一样不动。
fn start_compiled_run(model : Model) -> Model {
  let committed = commit_code(model)
  if committed.code_error != "" {
    return { ..committed, notice: "", }
  }
  match
    @ir.parse_event_kind(
      handler_event_of(committed.selected_handler).unwrap_or(""),
    ) {
    None => { ..committed, notice: "", }
    Some(event) => {
      let control = handler_control_of(committed.selected_handler).unwrap_or("")
      match compiled_handler_for(committed, control, event) {
        None => { ..committed, notice: "", }
        Some(handler) => {
          let runtime = @compiled_runtime.runtime_for_program(committed.program)
          for key in committed.runtime_selections.keys() {
            match committed.runtime_selections.get(key) {
              Some(index) => runtime.selections[key] = index
              None => ()
            }
          }
          seed_compiled_runtime(runtime, committed)
          // 勾选框视觉状态是 app 层私有：切轨/重开事件时保留现值，
          // 不因启动一次新运行而丢弃。
          let checks : Map[String, Bool] = Map([], capacity=8)
          match committed.compiled_run {
            Some(previous) =>
              for key in previous.checks.keys() {
                match previous.checks.get(key) {
                  Some(value) => checks[key] = value
                  None => ()
                }
              }
            None => ()
          }
          ignore(@compiled_runtime.run_handler(runtime, handler))
          {
            ..committed,
            compiled_run: Some(CompiledRun::{
              handler_label: handler_key(control, event.tag()),
              runtime,
              checks,
            }),
            mode: ModeRun,
            notice: "",
          }
        }
      }
    }
  }
}

///|
/// 按当前程序查找 lower 后的编译轨 handler（无则 None，不兜底）。
/// 行号口径与解释轨 `start_run` 一致：解析 `code_draft` 得到带 Trace 的
/// 语句序列再 lower，使两轨审计 `(line, op, detail)` 同源。
fn compiled_handler_for(
  model : Model,
  control : String,
  event : @ir.EventKind,
) -> @compiled_runtime.Handler? {
  match @ir.find_handler(model.program, control, event) {
    None => None
    Some(_handler) =>
      match
        @studio_lang.parse_handler_body(
          model.code_draft,
          model.language.dsl_language(),
        ) {
        Err(_) => None
        Ok(body) => Some(@compiled_runtime.lower_traced_handler(body))
      }
  }
}

///|
/// 编译轨活状态播种：控件文本/变量/行沿用 app 运行期活状态
/// （与解释轨 start_run_stmts 的入参同一口径）。
fn seed_compiled_runtime(
  runtime : @compiled_runtime.Runtime,
  model : Model,
) -> Unit {
  for key in model.runtime_texts.keys() {
    match model.runtime_texts.get(key) {
      Some(value) => runtime.texts[key] = value
      None => ()
    }
  }
  for key in model.runtime_values.keys() {
    match model.runtime_values.get(key) {
      Some(value) => runtime.vars[key] = compiled_value(value)
      None => ()
    }
  }
  for key in model.runtime_rows.keys() {
    match model.runtime_rows.get(key) {
      Some(rows) => {
        let copied : Array[String] = []
        for row in rows {
          copied.push(row)
        }
        runtime.rows[key] = copied
      }
      None => ()
    }
  }
}

///|
/// 解释轨值 → 编译轨值（两轨 Value 枚举同构，显式转换防锯齿）。
fn compiled_value(value : @studio_lang.Value) -> @compiled_runtime.Value {
  match value {
    @studio_lang.VNum(n) => @compiled_runtime.VNum(n)
    @studio_lang.VStr(text) => @compiled_runtime.VStr(text)
    @studio_lang.VBool(flag) => @compiled_runtime.VBool(flag)
    @studio_lang.VUnit => @compiled_runtime.VUnit
  }
}

///|
/// 编译轨运行结束（完成/失败）时把活状态并回 app 层。
fn merge_compiled_run_back(model : Model) -> Model {
  match model.compiled_run {
    None => model
    Some(run) =>
      if run.runtime.status is @compiled_runtime.Completed ||
        run.runtime.status is @compiled_runtime.Failed {
        for key in run.runtime.texts.keys() {
          match run.runtime.texts.get(key) {
            Some(text) => model.runtime_texts[key] = text
            None => ()
          }
        }
        for key in run.runtime.vars.keys() {
          match run.runtime.vars.get(key) {
            Some(value) => model.runtime_values[key] = interpreted_value(value)
            None => ()
          }
        }
        for key in run.runtime.rows.keys() {
          match run.runtime.rows.get(key) {
            Some(rows) => {
              let copied : Array[String] = []
              for row in rows {
                copied.push(row)
              }
              model.runtime_rows[key] = copied
            }
            None => ()
          }
        }
        for key in run.runtime.selections.keys() {
          match run.runtime.selections.get(key) {
            Some(index) => model.runtime_selections[key] = index
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
fn interpreted_value(value : @compiled_runtime.Value) -> @studio_lang.Value {
  match value {
    @compiled_runtime.VNum(n) => @studio_lang.VNum(n)
    @compiled_runtime.VStr(text) => @studio_lang.VStr(text)
    @compiled_runtime.VBool(flag) => @studio_lang.VBool(flag)
    @compiled_runtime.VUnit => @studio_lang.VUnit
  }
}

///|
/// 运行推进：每次 tick 执行若干条指令（聚光灯可跟随）。
fn run_tick(model : Model) -> Model {
  match model.run {
    None => model
    Some(run) => {
      // 单步模式下计时器不自动推进（RunStep 负责走一条指令）
      if run.state.status is @studio_lang.Running && !run.single_step {
        let mut i = 0
        while i < 6 && run.state.status is @studio_lang.Running {
          @studio_lang.step_once(run.state)
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
      if run.state.status is @studio_lang.Completed ||
        run.state.status is @studio_lang.Failed {
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
        for key in run.state.rows.keys() {
          match run.state.rows.get(key) {
            Some(rows) => {
              let copied : Array[String] = []
              for row in rows {
                copied.push(row)
              }
              model.runtime_rows[key] = copied
            }
            None => ()
          }
        }
        for key in run.state.selections.keys() {
          match run.state.selections.get(key) {
            Some(index) => model.runtime_selections[key] = index
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
/// A pending gate owns the interaction until it is answered.
fn gate_waiting(model : Model) -> Bool {
  match model.run {
    Some(run) => run.state.status is @studio_lang.WaitingGate
    None =>
      match model.compiled_run {
        Some(run) => run.runtime.status is @compiled_runtime.WaitingGate
        None => false
      }
  }
}

///|
/// Table rows expose click semantics; list selection is a change event.
fn picked_event_tag(model : Model, control : String) -> String {
  match @ir.find_control(model.program, control) {
    Some(item) => if item.kind is @ir.Table { "on_click" } else { "on_change" }
    None => "on_change"
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
          let state = @studio_lang.start_run_stmts(
            handler.body,
            model.runtime_texts,
            model.runtime_values,
            model.runtime_rows,
          )
          for key in model.runtime_selections.keys() {
            match model.runtime_selections.get(key) {
              Some(index) => state.selections[key] = index
              None => ()
            }
          }
          // `checks` is presentation state owned by the app, not by the
          // interpreter. Starting another event handler must keep current
          // checkbox values; otherwise RunToggle's mutation is discarded
          // when this fresh RunModel is installed.
          let checks : Map[String, Bool] = Map([], capacity=8)
          match model.run {
            Some(previous) =>
              for key in previous.checks.keys() {
                match previous.checks.get(key) {
                  Some(value) => checks[key] = value
                  None => ()
                }
              }
            None => ()
          }
          (
            {
              ..model,
              run: Some(RunModel::{
                handler_label: handler_key(control, event_tag),
                state,
                checks,
                single_step: false,
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
/// 运行域消息处理：未命中的消息返回 None 交还链式分发。
/// 顶栏显式切轨；两轨运行态互不干扰（各自的 RunModel / CompiledRun）。
fn update_run_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    SetRunTrack(track) =>
      Some((set_run_track(model, track), @moui.Effect::none()))
    RunStart =>
      if current_track(model) is Compile {
        Some((start_compiled_run(model), @moui.Effect::none()))
      } else {
        Some((start_run(model), @moui.Effect::none()))
      }
    RunStop =>
      // 停止只停当前轨；另一轨的运行态原样保留。
      if current_track(model) is Compile {
        Some(({ ..model, compiled_run: None, }, @moui.Effect::none()))
      } else {
        Some(({ ..model, run: None, }, @moui.Effect::none()))
      }
    RunTick =>
      if current_track(model) is Compile {
        // 编译轨不渐进执行：编译产物一到即跑完（或停在闸门），
        // 计时器 tick 是空操作——这正是「真编译产物没有暂停指令」的语义。
        Some((model, @moui.Effect::none()))
      } else {
        Some((run_tick(model), @moui.Effect::none()))
      }
    RunStep =>
      if current_track(model) is Compile {
        Some((model, @moui.Effect::none()))
      } else {
        match model.run {
          None => Some((model, @moui.Effect::none()))
          Some(run) => {
            if run.state.status is @studio_lang.Running {
              @studio_lang.step_once(run.state)
            }
            Some(
              (
                merge_run_back({
                  ..model,
                  run: Some({ ..run, single_step: true, }),
                }),
                @moui.Effect::none(),
              ),
            )
          }
        }
      }
    RunResume =>
      if current_track(model) is Compile {
        Some((model, @moui.Effect::none()))
      } else {
        match model.run {
          None => Some((model, @moui.Effect::none()))
          Some(run) =>
            Some(
              (
                { ..model, run: Some({ ..run, single_step: false, }), },
                @moui.Effect::none(),
              ),
            )
        }
      }
    // 审计 → 积木：detail 是两轨同一来源的规范文本，匹配口径一致。
    AuditJump(index) => {
      let detail = current_audit_detail(model, index)
      let mut block_index = -1
      if detail != "" {
        let blocks = block_chain_of(model)
        let mut i = 0
        for item in blocks {
          if block_index == -1 && item.text == detail {
            block_index = i
          }
          i = i + 1
        }
      }
      Some(
        (
          select_block({ ..model, mode: ModeBlocks, }, block_index),
          @moui.Effect::none(),
        ),
      )
    }
    RunToggle(name, value) =>
      // 勾选框既更新视觉状态，也触发其 on_change 子程序。
      if model.run is None && model.compiled_run is None {
        Some((model, @moui.Effect::none()))
      } else if gate_waiting(model) {
        Some((model, @moui.Effect::none()))
      } else {
        let committed = commit_code(model)
        if committed.code_error != "" {
          Some((committed, @moui.Effect::none()))
        } else {
          match toggled(model, committed, name, value) {
            Some(next) => Some((next, @moui.Effect::none()))
            None => Some((committed, @moui.Effect::none()))
          }
        }
      }
    AnswerGate(decision) =>
      if current_track(model) is Compile {
        match model.compiled_run {
          None => Some((model, @moui.Effect::none()))
          Some(run) => {
            ignore(@compiled_runtime.answer_gate(run.runtime, decision))
            Some((merge_compiled_run_back(model), @moui.Effect::none()))
          }
        }
      } else {
        match model.run {
          None => Some((model, @moui.Effect::none()))
          Some(run) => {
            @studio_lang.answer_gate(run.state, decision)
            Some((merge_run_back(model), @moui.Effect::none()))
          }
        }
      }
    ControlClicked(name) => {
      if gate_waiting(model) {
        return Some((model, @moui.Effect::none()))
      }
      let committed = commit_code(model)
      if committed.code_error != "" {
        // Never dispatch a runtime event against stale IR when the visible
        // code draft failed to parse; keep the draft and its localized error
        // in place for repair.
        Some((committed, @moui.Effect::none()))
      } else if current_track(committed) is Compile {
        Some(
          (
            dispatch_compiled_event(committed, name, "on_click"),
            @moui.Effect::none(),
          ),
        )
      } else {
        Some(run_handler(committed, name, "on_click"))
      }
    }
    ControlPicked(name, index) => {
      if gate_waiting(model) {
        return Some((model, @moui.Effect::none()))
      }
      let committed = commit_code(model)
      if committed.code_error != "" {
        Some((committed, @moui.Effect::none()))
      } else {
        committed.runtime_selections[name] = index
        match committed.run {
          Some(run) => run.state.selections[name] = index
          None => ()
        }
        match committed.compiled_run {
          Some(run) => run.runtime.selections[name] = index
          None => ()
        }
        let tag = picked_event_tag(committed, name)
        if current_track(committed) is Compile {
          Some(
            (
              dispatch_compiled_event(committed, name, tag),
              @moui.Effect::none(),
            ),
          )
        } else {
          Some(run_handler(committed, name, tag))
        }
      }
    }
    ControlChanged(name, value) => {
      if gate_waiting(model) {
        return Some((model, @moui.Effect::none()))
      }
      let committed = commit_code(model)
      if committed.code_error != "" {
        Some((committed, @moui.Effect::none()))
      } else {
        // 受控输入框：输入值必须先落进活状态文本表，否则字段显示回退、
        // 取文本 读到旧值。双写使两侧视图都为真身时都成立。
        committed.runtime_texts[name] = value
        match committed.run {
          Some(run) => run.state.texts[name] = value
          None => ()
        }
        match committed.compiled_run {
          Some(run) => run.runtime.texts[name] = value
          None => ()
        }
        if current_track(committed) is Compile {
          Some(
            (
              dispatch_compiled_event(committed, name, "on_change"),
              @moui.Effect::none(),
            ),
          )
        } else {
          Some(run_handler(committed, name, "on_change"))
        }
      }
    }
    _ => None
  }
}

///|
/// 顶栏切轨：只切换当前轨，不清任何一侧的运行态（两轨互不干扰）。
/// Web 端（compile_track_available=false）切到编译轨时给出显式提示，
/// 不隐藏事实：编译轨在本端不可达。
fn set_run_track(model : Model, track : RunTrack) -> Model {
  match track {
    Compile =>
      if !model.compile_track_available {
        {
          ..model,
          notice: text(translator(model), "app.track.unavailable_web"),
        }
      } else {
        { ..model, run_track: Compile, }
      }
    Interpret => { ..model, run_track: Interpret, }
  }
}

///|
/// 审计操作类型序号（解释轨）：两轨 StepOp 枚举逐项同构，差分测试与
/// 视图比对用同一序号口径，避免依赖跨包枚举相等。
pub fn audit_op_rank(op : @studio_lang.StepOp) -> Int {
  match op {
    @studio_lang.OpAssign => 0
    @studio_lang.OpMessage => 1
    @studio_lang.OpGate => 2
    @studio_lang.OpCommand => 3
    @studio_lang.OpCondition => 4
    @studio_lang.OpLoop => 5
  }
}

///|
/// 审计操作类型序号（编译轨）：与 `audit_op_rank` 同一张表的同一序号。
pub fn compiled_audit_op_rank(op : @compiled_runtime.StepOp) -> Int {
  match op {
    @compiled_runtime.OpAssign => 0
    @compiled_runtime.OpMessage => 1
    @compiled_runtime.OpGate => 2
    @compiled_runtime.OpCommand => 3
    @compiled_runtime.OpCondition => 4
    @compiled_runtime.OpLoop => 5
  }
}

///|
fn current_track(model : Model) -> RunTrack {
  match model.run_track {
    Compile => if model.compile_track_available { Compile } else { Interpret }
    Interpret => Interpret
  }
}

///|
fn current_audit_detail(model : Model, index : Int) -> String {
  if current_track(model) is Compile {
    match model.compiled_run {
      Some(run) =>
        match run.runtime.audit.get(index) {
          Some(record) => record.detail
          None => ""
        }
      None => ""
    }
  } else {
    match model.run {
      Some(run) =>
        match run.state.audit.get(index) {
          Some(record) => record.detail
          None => ""
        }
      None => ""
    }
  }
}

///|
/// 勾选框切换：两轨各自更新 checks 与宿主活状态文本。
fn toggled(
  model : Model,
  committed : Model,
  name : String,
  value : Bool,
) -> Model? {
  match model.run_track {
    Interpret =>
      match committed.run {
        Some(run) => {
          run.checks[name] = value
          let (next, _effect) = run_handler(committed, name, "on_change")
          Some(next)
        }
        None => None
      }
    Compile =>
      match committed.compiled_run {
        Some(run) => {
          run.checks[name] = value
          Some(dispatch_compiled_event(committed, name, "on_change"))
        }
        None => None
      }
  }
}

///|
/// 编译轨事件派发：按 (控件, 事件) 找 lower 后的 handler 重新开跑；
/// 找不到就保持现状（与解释轨一致，不静默兜底）。
fn dispatch_compiled_event(
  model : Model,
  control : String,
  event_tag : String,
) -> Model {
  match @ir.parse_event_kind(event_tag) {
    None => model
    Some(event) =>
      match compiled_handler_for(model, control, event) {
        None => {
          ignore(event)
          model
        }
        Some(handler) => {
          let runtime = @compiled_runtime.runtime_for_program(model.program)
          seed_compiled_runtime(runtime, model)
          let checks : Map[String, Bool] = Map([], capacity=8)
          match model.compiled_run {
            Some(previous) =>
              for key in previous.checks.keys() {
                match previous.checks.get(key) {
                  Some(flag) => checks[key] = flag
                  None => ()
                }
              }
            None => ()
          }
          ignore(@compiled_runtime.run_handler(runtime, handler))
          {
            ..model,
            compiled_run: Some(CompiledRun::{
              handler_label: handler_key(control, event_tag),
              runtime,
              checks,
            }),
            mode: ModeRun,
          }
        }
      }
  }
}
