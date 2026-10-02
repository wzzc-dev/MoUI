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
          return with_notice(
            committed,
            error_message(translator(committed), error),
            true,
          )
      }
      // 每次启动/派发都推进一格种子（与编译轨 run_handler 同一手法）：
      // 反复点同一个按钮要能看见不同的随机结果，否则「运行之后点按钮
      // 没反应」——那其实是有反应但每次都一样。
      let seed = @studio_lang.next_seed(committed.runtime_seed)
      let state = @studio_lang.start_run(
        body,
        committed.runtime_texts,
        committed.runtime_values,
        committed.runtime_rows,
        seed~,
        functions=committed.program.functions,
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
      // 启动是一条审计事实（不是每次 tick）：时间线要能回答「跑的是哪个
      // 子程序」，所以记子程序键而不是泛泛的「已启动」。
      let t = translator(committed)
      let logged = log_line(
        committed,
        LogLevel::LogInfo,
        text_with(t, "app.log.run_start", [("handler", run.handler_label)]),
      )
      let audited = push_audit(
        logged,
        AuditRun,
        text(t, "app.audit.run_start"),
        run.handler_label,
      )
      {
        ..audited,
        run: Some(run),
        mode: ModeRun,
        notice: "",
        runtime_seed: seed,
      }
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
          let runtime = @compiled_runtime.runtime_for_program(
            committed.program,
            lower=Some(@compiled_runtime.lower_user_function),
          )
          for key in committed.runtime_selections.keys() {
            match committed.runtime_selections.get(key) {
              Some(index) => runtime.selections[key] = index
              None => ()
            }
          }
          seed_compiled_runtime(runtime, committed)
          // 采样事件起点：编译轨的 Runtime 每次事件都重建，种子必须由 app
          // 显式接续（否则每次都从 RANDOM_SEED 起算 = 点十次同一个结果）。
          let seed = @compiled_runtime.next_seed(committed.runtime_seed)
          runtime.rng = seed
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
            runtime_seed: seed,
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
    @studio_lang.VInt(n) => @compiled_runtime.VInt(n)
    @studio_lang.VArr(items) => {
      let copy : Array[@compiled_runtime.Value] = []
      for item in items {
        copy.push(compiled_value(item))
      }
      @compiled_runtime.VArr(copy)
    }
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
    @compiled_runtime.VInt(n) => @studio_lang.VInt(n)
    @compiled_runtime.VArr(items) => {
      let copy : Array[@studio_lang.Value] = []
      for item in items {
        copy.push(interpreted_value(item))
      }
      @studio_lang.VArr(copy)
    }
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
      drain_broadcasts_interpret(merge_run_back(model))
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
        // 运行收尾是**唯一**的终态汇合点（tick / 单步 / 事件回灌都经过
        // 这里），所以审计只在这里记一次：失败记错误卡，成功记完成事实。
        // 散在各调用点记会重复计数，每次 tick 都刷一条。
        let t = translator(model)
        let settled = match run.state.status {
          @studio_lang.Failed => {
            let reason = match run.state.error {
              Some(error) => error_message(t, error)
              None => text(t, "app.audit.run_failed.detail")
            }
            push_audit_error(model, text(t, "app.audit.run_failed"), reason)
          }
          _ =>
            push_audit(
              model,
              AuditOk,
              text(t, "app.audit.run_done"),
              run.handler_label,
            )
        }
        settled
        // 停在副作用闸门：这一步会真的对外产生效果，必须先确认。
        // 闸门用 AuditWarn 卡呈现（与「待确认副作用」同一语义色）。
      } else if run.state.status is @studio_lang.WaitingGate &&
        !already_gated(model, run) {
        let t = translator(model)
        let detail = match run.state.gate {
          Some(gate) => gate.payload
          None => text(t, "app.audit.gate.detail")
        }
        push_audit_side_effect(model, text(t, "app.audit.gate"), detail)
      } else {
        model
      }
  }
}

///|
/// 该次运行是否已经记过闸门卡：同一 handler 的同一步只记一次，
/// 否则每次 RunTick 都会再压一条（时间线会被同一条副作用刷屏）。
fn already_gated(model : Model, run : RunModel) -> Bool {
  for entry in model.audit_entries {
    if entry.kind is AuditWarn && entry.detail == run.handler_label {
      return true
    }
  }
  false
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
          // 事件派发同样推进随机种子：这是「点按钮有反应」的主要路径。
          let seed = @studio_lang.next_seed(model.runtime_seed)
          let state = @studio_lang.start_run_stmts(
            handler.body,
            model.runtime_texts,
            model.runtime_values,
            model.runtime_rows,
            seed~,
            functions=model.program.functions,
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
              runtime_seed: seed,
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
    // 真编译（moon check/build）是**显式动作**，与「切到运行视图」解耦：
    // 切轨只切片执行面，不隐式触发真编译；点「真编译」才排队。
    CompileRun =>
      if !model.compile_track_available {
        Some(
          (
            with_notice(
              model,
              text(translator(model), "app.track.unavailable_web"),
              true,
            ),
            @moui.Effect::none(),
          ),
        )
      } else if model.compile_busy {
        // 已在编译：忽略重复点击（一次显式动作只排一次真编译）。
        Some((model, @moui.Effect::none()))
      } else {
        let committed = commit_code(model)
        if committed.code_error != "" {
          // 源码草稿不合法时不把坏程序送去真编译（先修，再编译）。
          Some((committed, @moui.Effect::none()))
        } else {
          let t = translator(committed)
          Some(
            (
              with_notice(
                {
                  ..log_line(
                    committed,
                    LogLevel::LogInfo,
                    text(t, "app.log.compile_start"),
                  ),
                  compile_report: None,
                  compile_busy: true,
                  // 进度清空重来：上一轮的步骤点不能残留在新一转里。
                  compile_progress: [],
                  run_track: Compile,
                  mode: ModeRun,
                },
                text(t, "app.compile.running"),
                false,
              ),
              @moui.Effect::none(),
            ),
          )
        }
      }
    CompileRunFinished(report) => {
      // 编译结果进审计 + Console：审计记「发生了什么」，Console 记原始诊断。
      let t = translator(model)
      let logged = log_line(
        model,
        if report.ok {
          LogLevel::LogInfo
        } else {
          LogLevel::LogError
        },
        if report.ok {
          text(t, "app.log.compile_ok")
        } else {
          text(t, "app.log.compile_failed")
        },
      )
      let audited = if report.ok {
        push_audit(
          logged,
          AuditOk,
          text(t, "app.audit.compile_ok"),
          report.target,
        )
      } else {
        push_audit_error(
          logged,
          text(t, "app.audit.compile_failed"),
          report.diagnostics
          .map(d => "\{d.severity} \{d.file}:\{d.line}:\{d.column} \{d.text}")
          .join("\n"),
        )
      }
      Some(
        (
          with_notice(
            {
              ..audited,
              compile_report: Some(report),
              compile_busy: false,
              // 报告接手显示：进度条退场（两个读数同时在场会互相打架）。
              compile_progress: [],
            },
            if report.ok {
              text(t, "app.compile.ok")
            } else {
              text(t, "app.compile.failed")
            },
            !report.ok,
          ),
          @moui.Effect::none(),
        ),
      )
    }
    CompileRunFailed(message) =>
      // 执行器本身起不来（非工具链诊断）：如实进报告，不改路径。
      Some(
        (
          with_notice(
            {
              ..model,
              compile_report: Some(@export.CompileReport::{
                ok: false,
                exit_code: -1,
                target: "native",
                source_path: "",
                output: message,
                diagnostics: [],
                artifacts: [],
                work_root: "",
              }),
              compile_busy: false,
              compile_progress: [],
            },
            text(translator(model), "app.compile.failed"),
            true,
          ),
          @moui.Effect::none(),
        ),
      )
    CompileStopped =>
      // 停止真编译：只清当前报告/忙态，不切轨、不自动回退解释轨。
      //
      // 注意这**不终止 worker 进程**——编译轨的 `moon` 工具链进程在 worker
      // 上跑，UI 侧只放弃等待与展示。真正的取消需要执行器支持，本版不做；
      // 按钮的语义是「不再等这次编译」。完成后到达的结果会被
      // `compile_submit_needed` 之外的回执路径正常处理（报告照旧落库）。
      Some(
        (
          {
            ..model,
            compile_report: None,
            compile_busy: false,
            compile_progress: [],
          },
          @moui.Effect::none(),
        ),
      )

    // 编译诊断行号 → IR 语句路径 → 积木：先选中诊断所属子程序，
    // 再按路径定位块（路径是稳定坐标，链下标随展开块变化）。
    CompileJump(line) =>
      Some((jump_to_compile_line(model, line), @moui.Effect::none()))
    ToggleCompileOutput =>
      Some(
        (
          { ..model, compile_output_open: !model.compile_output_open, },
          @moui.Effect::none(),
        ),
      )
    // 进度累加：同一步的 started 会被后来的 finished 覆盖掉（见
    // `compile_step_states` 的归并规则），所以这里只做无脑追加——
    // 归并是纯函数，视图与测试读同一份结果。
    CompileProgress(progress) =>
      Some(
        (
          {
            ..model,
            compile_progress: append_progress(model.compile_progress, progress),
          },
          @moui.Effect::none(),
        ),
      )
    // 侧路动作（复制路径 / 在文件夹中打开 / 一键启动）落在 **service 流**
    // （`update_with_services`）：状态机不碰剪贴板、文件管理器与进程。
    // 这里显式返回 None 让链式分发把它交出去——自己 handle 再 send 回
    // 同一条消息会变成死循环。
    CopyArtifactPath(_)
    | RevealArtifact(_)
    | RunArtifact(_)
    | ArtifactActionDone(_, _) => None
    RunStart =>
      if current_track(model) is Compile {
        Some((start_compiled_run(model), @moui.Effect::none()))
      } else {
        Some((start_run(model), @moui.Effect::none()))
      }
    RunStop =>
      // 停止只停当前轨；另一轨的运行态原样保留。
      //
      // **必须同时离开全屏运行页**：`ModeRun` 是「运行/预览/帮助」三个
      // 全屏页之一（ide_root 的 fullscreen 分支），运行态一旦清空，
      // `run_form` 就渲染成空视图——整个中心区（含两侧栏）变成一片空白。
      // 实测点「停止」后窗口只剩顶栏与状态栏，用户读到的是「界面坏了」。
      // 回到可视化工作区是「停止 = 回到编辑」的自然语义。
      if current_track(model) is Compile {
        Some(
          (
            {
              ..model,
              compiled_run: None,
              mode: ModeDesign,
              workspace: WsVisual,
              pane_live: true,
            },
            @moui.Effect::none(),
          ),
        )
      } else {
        Some(
          (
            {
              ..model,
              run: None,
              mode: ModeDesign,
              workspace: WsVisual,
              pane_live: true,
            },
            @moui.Effect::none(),
          ),
        )
      }
    RunTick =>
      if current_track(model) is Compile {
        // 编译轨不渐进执行：编译产物一到即跑完（或停在闸门），
        // 计时器 tick 是空操作——这正是「真编译产物没有暂停指令」的语义。
        Some((model, @moui.Effect::none()))
      } else {
        Some((run_tick(model), @moui.Effect::none()))
      }
    TimerTick => Some((timer_tick(model), @moui.Effect::none()))
    ControlInputDone(name) => {
      // 完成输入（切片 G）：提交（Enter）即派发 on_input_done 处理器
      if gate_waiting(model) {
        Some((model, @moui.Effect::none()))
      } else {
        let committed = commit_code(model)
        if committed.code_error != "" {
          Some((committed, @moui.Effect::none()))
        } else {
          let (next, effect) = run_handler(committed, name, "on_input_done")
          Some((next, effect))
        }
      }
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
                drain_broadcasts_interpret(
                  merge_run_back({
                    ..model,
                    run: Some({ ..run, single_step: true, }),
                  }),
                ),
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
            Some((drain_broadcasts_compiled(merge_compiled_run_back(model)), @moui.Effect::none()))
          }
        }
      } else {
        match model.run {
          None => Some((model, @moui.Effect::none()))
          Some(run) => {
            @studio_lang.answer_gate(run.state, decision)
            Some(
              (drain_broadcasts_interpret(merge_run_back(model)), @moui.Effect::none()),
            )
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
        with_notice(
          model,
          text(translator(model), "app.track.unavailable_web"),
          true,
        )
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
          let runtime = @compiled_runtime.runtime_for_program(
            model.program,
            lower=Some(@compiled_runtime.lower_user_function),
          )
          seed_compiled_runtime(runtime, model)
          // 同 start_compiled_run：事件起点显式接续（Runtime 每次重建）。
          let seed = @compiled_runtime.next_seed(model.runtime_seed)
          runtime.rng = seed
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
            runtime_seed: seed,
          }
        }
      }
  }
}

///|
/// 编译诊断行号 → 对应积木：在「预览即产物」的生成源码里按行号反查
/// `stmt_lines`（同一 `generate_source` 调用，行号与 bundle 内文件一致），
/// 命中则先切到该 handler 再选中块；未命中保持原模型（不瞎跳）。
fn jump_to_compile_line(model : Model, line : Int) -> Model {
  let generated = @export.moonbit_preview_with_lines(model.program)
  for handler in generated.handlers {
    for entry in handler.stmt_lines {
      if entry.line == line {
        let scoped = {
          ..model,
          selected_handler: handler_key(handler.control_name, handler.event_tag),
        }
        return select_block_by_path(scoped, entry.path)
      }
    }
  }
  model
}

///|
/// 真编译是否应当在本次 `CompileRun` 转移后真正入队：轨道可达、草稿无
/// 语法错、且刚从非忙态进入忙态（重复点击不重复排队）。副作用（入队）
/// 由组合根注入的 `CompileSubmit` 承担，状态机本身保持纯函数。
pub fn compile_submit_needed(before : Model, after : Model) -> Bool {
  after.compile_track_available &&
  after.code_error == "" &&
  !before.compile_busy &&
  after.compile_busy
}

///|
/// 进度追加：同一步的最后一条状态生效（started=false 覆盖 started=true）。
///
/// 为什么不在 `CompileProgress` 处理时原地覆盖：worker 的两条消息可能
/// 在同一帧里到达，视图可能在中间态渲染一次；保留追加语义让「归并」是
/// 纯函数，视图/测试/审计读同一份结果，不必各自实现一遍覆盖规则。
fn append_progress(
  existing : Array[@export.CompileProgress],
  progress : @export.CompileProgress,
) -> Array[@export.CompileProgress] {
  let next : Array[@export.CompileProgress] = []
  for item in existing {
    next.push(item)
  }
  next.push(progress)
  next
}

///|
/// 单步状态：`None` 未开始 / `Some(true)` 进行中 / `Some(false)` 已完成。
///
/// 编译进度条的唯一读取口径——视图与测试都走这里，避免「两处各算一份」
/// 让进度格与真实执行错位。
pub fn compile_step_state(
  progress : Array[@export.CompileProgress],
  phase : @export.CompilePhase,
) -> Bool? {
  let mut state : Bool? = None
  for item in progress {
    if item.phase.tag() == phase.tag() {
      // 后到的覆盖先到的：finished(false) 最终胜出
      state = Some(item.started)
    }
  }
  state
}

///|
/// 已**完成**的步数（进度条点满的格数）与总步数。
pub fn compile_progress_counts(
  progress : Array[@export.CompileProgress],
) -> (Int, Int) {
  let mut done = 0
  for phase in @export.compile_phases() {
    match compile_step_state(progress, phase) {
      Some(false) => done = done + 1
      _ => ()
    }
  }
  (done, @export.compile_phase_total())
}

///|
/// 当前正在执行的步（最后一条 started=true 且尚未 finished 的步）。
/// 全部未开始或全部结束时返回 None。
pub fn compile_active_phase(
  progress : Array[@export.CompileProgress],
) -> @export.CompilePhase? {
  let mut active : @export.CompilePhase? = None
  for phase in @export.compile_phases() {
    match compile_step_state(progress, phase) {
      Some(true) => active = Some(phase)
      _ => ()
    }
  }
  active
}

///|
/// 广播总线（切片 G）：事件收尾时排空——每条广播文案依次投递给
/// 全部 `@广播消息` 窗体级处理器；文案经伪变量 `消息文本` 传递。
/// 解释轨：子 RunState 以活状态播种、跑完并回（与事件同口径）。
fn drain_broadcasts_interpret(model : Model) -> Model {
  match model.run {
    None => model
    Some(run) => {
      let mut budget = 0
      while run.state.broadcasts.length() > 0 && budget < 32 {
        budget = budget + 1
        let text = run.state.broadcasts.remove(0)
        for handler in model.program.handlers {
          if handler.control_name == "" && handler.event is @ir.OnBroadcast {
            let texts = Map([], capacity=8)
            for key in run.state.texts.keys() {
              match run.state.texts.get(key) {
                Some(value) => texts[key] = value
                None => ()
              }
            }
            texts["消息文本"] = text
            let sub = @studio_lang.start_run_stmts(
              handler.body,
              texts,
              run.state.vars,
              run.state.rows,
              functions=model.program.functions,
            )
            @studio_lang.run_to_end(sub)
            for key in sub.vars.keys() {
              match sub.vars.get(key) {
                Some(value) => run.state.vars[key] = value
                None => ()
              }
            }
            for key in sub.texts.keys() {
              match sub.texts.get(key) {
                Some(value) => run.state.texts[key] = value
                None => ()
              }
            }
          }
        }
      }
      model
    }
  }
}

///|
/// 编译轨广播排空：同一 Runtime 上逐条投递（文案经 `消息文本` 文本槽）。
fn drain_broadcasts_compiled(model : Model) -> Model {
  match model.compiled_run {
    None => model
    Some(run) => {
      let mut budget = 0
      while run.runtime.broadcasts.length() > 0 && budget < 32 {
        budget = budget + 1
        let text = run.runtime.broadcasts.remove(0)
        run.runtime.texts["消息文本"] = text
        for handler in model.program.handlers {
          if handler.control_name == "" && handler.event is @ir.OnBroadcast {
            let compiled_handler = @compiled_runtime.lower_handler(handler.body)
            let _ = @compiled_runtime.run_handler(run.runtime, compiled_handler)
          }
        }
      }
      model
    }
  }
}

///|
/// 虚拟时钟（切片 G）：每秒步进一次；累计满窗体 timer_interval 秒即
/// 触发一次 @定时器 窗体级处理器（两轨按当前轨道派发）。
/// 只在运行期间累加——设计态订阅不活跃，这就是「虚拟」。
fn timer_tick(model : Model) -> Model {
  let interval = model.program.window.timer_interval
  if interval <= 0 || !app_running(model) {
    return model
  }
  let elapsed = model.timer_elapsed + 1
  if elapsed < interval {
    return { ..model, timer_elapsed: elapsed, }
  }
  let reset = { ..model, timer_elapsed: 0, }
  // 触发 @定时器：与点击事件同一套纪律（先提交草稿）
  let committed = commit_code(reset)
  if committed.code_error != "" {
    return committed
  }
  let (fired, _) = run_handler(committed, "", "on_timer")
  fired
}
