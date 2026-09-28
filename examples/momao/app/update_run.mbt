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
        checks: Map([], capacity=8),
        single_step: false,
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
      // 单步模式下计时器不自动推进（RunStep 负责走一条指令）
      if run.state.status is @momao_lang.Running && !run.single_step {
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
                checks: Map([], capacity=8),
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
fn update_run_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    RunStart => Some((start_run(model), @moui.Effect::none()))
    RunStop => Some(({ ..model, run: None, }, @moui.Effect::none()))
    RunTick => Some((run_tick(model), @moui.Effect::none()))
    RunStep =>
      // 单步：走一条指令并进入单步模式（自动推进停止，直到 继续）
      match model.run {
        None => Some((model, @moui.Effect::none()))
        Some(run) => {
          if run.state.status is @momao_lang.Running {
            @momao_lang.step_once(run.state)
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
    RunResume =>
      // 继续：退出单步模式，恢复自动推进
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
    AuditJump(index) =>
      // 审计 → 积木：切到积木视图并选中该条目对应的语句。
      // detail 是规范文本，与积木链 item.text 同一来源（聚光灯同款匹配）。
      match model.run {
        None => Some((model, @moui.Effect::none()))
        Some(run) => {
          let detail = match run.state.audit.get(index) {
            Some(record) => record.detail
            None => ""
          }
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
      }
    RunToggle(name, value) =>
      // 勾选框是运行期 UI 态：就地写入当前 run 的 checks 表
      match model.run {
        None => Some((model, @moui.Effect::none()))
        Some(run) => {
          run.checks[name] = value
          Some((model, @moui.Effect::none()))
        }
      }
    AnswerGate(decision) =>
      match model.run {
        None => Some((model, @moui.Effect::none()))
        Some(run) => {
          @momao_lang.answer_gate(run.state, decision)
          Some((merge_run_back(model), @moui.Effect::none()))
        }
      }
    ControlClicked(name) => {
      let committed = commit_code(model)
      Some(run_handler(committed, name, "on_click"))
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
      Some(run_handler(committed, name, "on_change"))
    }
    _ => None
  }
}
