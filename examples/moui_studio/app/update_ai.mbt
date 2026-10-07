///|
/// 「发送」按当前模式分流到既有通道——模式只改**入口路由**，不新增
/// 执行路径（提案仍走 proposals 校验链，讲解仍是确定性函数）。
///
/// 提交是**结构性事件**：先给当前会话盖戳（默认名置题 + 工程戳 + updated
/// 时间戳），再进模式路由——草稿键入不经过这里，列表排序不随打字抖动。
fn composer_run(model : Model) -> (Model, @moui.Effect[Msg]) {
  let stamped = stamp_session_submit(model)
  // 用户提问进时间线（对白转录）：气泡卡在路由前推送——无论走哪条模式，
  // 「用户说了什么」都留下可审计的记录。空 prompt 不推（没有可回显的内容）。
  let prompt = stamped.ai_sessions.current().prompt_draft
  let with_prompt = if prompt != "" {
    push_ai_card(stamped, AiCard::{
      kind: CardUserPrompt,
      title: "",
      body: prompt,
      steps: [],
      steps_done: 0,
      progress: 0,
      diff_lines: [],
      settled: true,
      settled_note: "",
      seq: 0,
      at: 0,
    })
  } else {
    stamped
  }
  mark_ai_sessions_dirty(with_prompt)
  match with_prompt.composer_mode {
    // 解释需要「当前子程序」才有话说：没选中就先选第一个子程序
    // （与左栏点选同一语义），否则讲解恒为空——点了没反应。
    ComposeExplain => {
      let targeted = if current_handler(with_prompt) is None &&
        with_prompt.program.handlers.length() > 0 {
        let first = with_prompt.program.handlers[0]
        update_pure(
          with_prompt,
          SelectHandler(handler_key(first.control_name, first.event.tag())),
        )
      } else {
        (with_prompt, @moui.Effect::none())
      }
      update_pure(targeted.0, ExplainHandler)
    }
    ComposeRepair => update_pure(with_prompt, RestoreCodeDraft)
    // 生成 = 以空程序为基底的修改：清空控件与子程序让提案从零重建，
    // 走的还是同一个 proposals 校验链（不是「另一条生成通道」）。
    ComposeGenerate => {
      let cleared = {
        ..with_prompt,
        program: @ir.StudioProgram::{
          ..with_prompt.program,
          controls: [],
          handlers: [],
          functions: [],
          structs: [],
        },
      }
      update_pure(cleared, GenerateProposal)
    }
    ComposeEdit => update_pure(with_prompt, GenerateProposal)
  }
}

///|
/// 提交盖戳：默认名（「会话 N」形态）的会话以 prompt 首行置题（用户改过
/// 的名字不覆盖）；工程戳 = active_project 的 module_name（无工程保持
/// 原值）；updated = 当前墙钟。
fn stamp_session_submit(model : Model) -> Model {
  let session = model.ai_sessions.current()
  let project = match active_project_of(model) {
    Some(record) => record.module_name
    None => session.project
  }
  let title = if is_default_session_title(session.title) {
    session_title_from_prompt(session.prompt_draft, session.title)
  } else {
    session.title
  }
  model.ai_sessions.amend({
    ..session,
    title,
    project,
    updated: civil_seconds(model.clock),
  })
  model
}

///|
/// 默认名形态判定（「会话 N」，N 全为数字）：只有它会被提交置题覆盖。
/// 用户改名成「会话 3」的边缘情况接受被覆盖——自动命名与手动命名的
/// 区分不做第二个状态位，判定保持单一来源。
fn is_default_session_title(title : String) -> Bool {
  if !title.has_prefix("会话 ") {
    return false
  }
  let rest = title[3:]
  if rest.length() == 0 {
    return false
  }
  let mut all_digits = true
  for ch in rest {
    if !(ch >= '0' && ch <= '9') {
      all_digits = false
      break
    }
  }
  all_digits
}

///|
/// 从 prompt 首行取会话标题：按字符取前 18 个（中英文混排同一口径），
/// 空 prompt 保持原名。
fn session_title_from_prompt(prompt : String, fallback : String) -> String {
  let mut first_line = ""
  for line in prompt.split("\n") {
    first_line = line.trim().to_owned()
    break
  }
  if first_line == "" {
    return fallback
  }
  let buf = StringBuilder()
  let mut taken = 0
  for ch in first_line {
    if taken >= 18 {
      break
    }
    buf.write_char(ch)
    taken = taken + 1
  }
  buf.to_string()
}

///|
/// AI 提案域状态转移：生成/采纳/拒绝、provider 设置、本地讲解。

///|
/// 采纳提案：校验链通过才应用；失败整单拒绝并展示全部原因。
fn accept_proposal(model : Model) -> Model {
  match model.pending {
    None => model
    Some(pending) =>
      if !pending.valid {
        with_notice(
          model,
          text(translator(model), "app.status.proposal_invalid"),
          true,
        )
      } else {
        let next = @proposals.apply_proposal(model.program, pending.proposal)
        let cleared : Model = {
          ..model,
          program: next,
          pending: None,
          selected_control: first_control_name(next.controls),
          run: None,
          runtime_values: @studio_lang.initial_values(next),
          runtime_texts: @studio_lang.initial_texts(next),
          runtime_rows: @studio_lang.initial_rows(next),
          runtime_selections: Map([], capacity=4),
        }
        // 采纳（M6②）：IR 已更新 → 代码真源骨架随之重新生成落盘
        //（EvCodeProjectWrite 事件（M1）由组合根监听器消费：handlers.mbt
        // 全量 codegen——文件尚为 codegen 所有，重生成即 span 补丁的超集；
        // form.mbt 同理）。
        let accepted = settle_newest_thread_card(
          record_history(cleared, pending, true),
          text(translator(model), "app.ai.card.applied"),
        )
        // 采纳后清空当前会话的提问草稿（原语义：草稿已被消费）
        accepted.ai_sessions.amend({
          ..accepted.ai_sessions.current(),
          prompt_draft: "",
        })
        // 语义事件（M3）：采纳事实进事件总线（扩展点，当前无消费者）
        accepted.outbox.push(EvProposalAccepted(0, pending.summary))
        let accepted = emit_code_project_write(accepted)
        // 采纳是一条**大事实**：审计留痕 + 最近修改记「Agent」+ toast 回执，
        // 三处都从这一条事件派生（教学上「Agent 改了什么」必须可追溯）。
        let t = translator(accepted)
        let logged = log_line(
          accepted,
          LogLevel::LogInfo,
          text_with(t, "app.log.proposal_accepted", [
            ("count", pending.diff.length().to_string()),
          ]),
        )
        let audited = push_audit(
          logged,
          AuditOk,
          text(t, "app.audit.proposal_accepted"),
          text_with(t, "app.audit.proposal_accepted.detail", [
            ("count", pending.diff.length().to_string()),
          ]),
        )
        let tracked = push_recent(
          audited,
          pending.summary,
          text(t, "app.recent.action.agent_accept"),
          true,
        )
        // 采纳回执走 with_notice 单一漏斗（notice 字段 + toast 一处搞定，
        // 不再 push_toast 与 notice 各写一份）。必须吃进 tracked（审计+最近
        // 修改之后的状态）——吃进更早的 accepted 会把审计/最近修改整段丢掉。
        let accepted = with_notice(
          tracked,
          text(t, "app.toast.proposal_accepted"),
          false,
        )
        mark_ai_sessions_dirty(accepted)
        accepted
      }
  }
}

///|
/// 会话存储错误本地化（加载失败如实提示,不静默吞掉坏文件）。
pub fn store_error_text(
  t : @i18n.Translator,
  error : @ai.AiStoreError,
) -> String {
  match error {
    @ai.StoreBadJson => text(t, "app.ai.store.bad_json")
    @ai.StoreBadFormat => text(t, "app.ai.store.bad_format")
    @ai.StoreBadVersion(_) => text(t, "app.ai.store.bad_version")
    @ai.StoreBadPayload => text(t, "app.ai.store.bad_payload")
  }
}

///|
/// 会话结构性变化的统一出口：进 outbox 事件,由总线翻译成写盘请求
/// （未配置存储路径的组合根不注册监听器 → 排空零开销）。
pub fn mark_ai_sessions_dirty(model : Model) -> Unit {
  model.outbox.push(EvAiSessionsDirty)
}

///|
/// 错误进时间线（对白转录）：解析/校验/网络失败都推一张 CardError 卡——
/// 给这个卡种类真实的生产推送点，失败在会话流里可见可回溯（decision_bar
/// 的错误行仍保留给紧凑宿主）。
fn push_error_card(model : Model, message : String) -> Model {
  push_ai_card(model, AiCard::{
    kind: CardError,
    title: text(translator(model), "app.ai.card.error"),
    body: message,
    steps: [],
    steps_done: 0,
    progress: 0,
    diff_lines: [],
    settled: false,
    settled_note: "",
    seq: 0,
    at: 0,
  })
}

///|
/// 生成提案：假模型（默认）或真实模型回填文案走同一条严格校验链。
/// 真实 provider 的网络副作用在 update_with_services 中发起；
/// 这里只负责把「已得到的补全文本」变成待采纳提案。
pub fn proposal_from_completion(model : Model, completion : String) -> Model {
  match @proposals.decode_proposal(completion) {
    Err(_) => {
      let message = text(translator(model), "app.status.proposal_invalid")
      push_error_card({ ..model, prompt_error: message, }, message)
    }
    Ok(proposal) => {
      let errors = @proposals.validate_proposal(model.program, proposal)
      let messages : Array[String] = []
      for error in errors {
        messages.push(proposal_error_text(translator(model), error))
      }
      let diff = @proposals.proposal_diff(model.program, proposal)
      // 代码真源文本 diff（M6②）：把提案应用到 IR 副本，前后各生成一次
      // 代码工程文本，行级 ± 即用户在 diff 卡看到的「改了哪几行」。
      // 校验链不变：apply_proposal 只在纯函数副本上预演。
      let code_diff = code_text_diff(
        code_project_text(model.program),
        code_project_text(@proposals.apply_proposal(model.program, proposal)),
      )
      let summary = match model.language {
        ZhHans => proposal.summary_zh
        En => proposal.summary_en
      }
      let pending : PendingProposal = {
        proposal,
        diff,
        code_diff,
        summary,
        errors: messages,
        valid: errors.is_empty(),
      }
      {
        ..push_proposal_thread_card(
          { ..model, pending: Some(pending), prompt_error: "", },
          pending,
        ),
        pending: Some(pending),
        prompt_error: "",
      }
    }
  }
}

///|
/// 把**最新的未处理线程卡**标记为已处理（采纳/拒绝时调用），并写上回执。
/// 只动最新一张：一次提案对应一张卡，标记更早的会把历史卡的语义搞混。
fn settle_newest_thread_card(model : Model, note : String) -> Model {
  let cards = model.ai_sessions.current().cards
  let mut index = cards.length() - 1
  while index >= 0 {
    let card = cards[index]
    if !card.settled && (card.kind is CardDiff || card.kind is CardSideEffect) {
      cards[index] = AiCard::{ ..card, settled: true, settled_note: note, }
      break
    }
    index = index - 1
  }
  // 卡数组是共享引用：上面的原位标记已经生效（M3 会话切片共享语义）
  model
}

///|
/// 提案到位时把一张 **diff 线程卡**推进会话线程（设计稿 `threadStack`）。
///
/// 此前 `push_ai_card` 没有调用方，`ai_cards` 恒为空——于是线程区、折叠条、
/// `#seeAll`、药丸的「待审计 N」全是永远不出现的死 UI。会话线程是设计稿 AI
/// 层的核心（「Agent 干了什么」的可见记录），必须由真实事件驱动：
/// 唯一的提案入口就是这里。
fn push_proposal_thread_card(model : Model, pending : PendingProposal) -> Model {
  let t = translator(model)
  let lines : Array[(String, String)] = []
  for entry in pending.diff {
    lines.push(
      (
        match entry.op {
          @proposals.Added => "+"
          @proposals.Removed => "-"
          @proposals.Changed => "~"
        },
        entry.path + "  " + entry.new_text,
      ),
    )
  }
  // 代码 diff 卡（M6②）：显示层展示 handlers.mbt/form.mbt 的行级 ±，
  // 结构化条目降级为代码 diff 为空时的兜底（纯 form 外变更）。
  let code_lines : Array[(String, String)] = if pending.code_diff.length() > 0 {
    pending.code_diff
  } else {
    lines
  }
  push_ai_card(model, AiCard::{
    kind: CardDiff,
    title: pending.summary,
    body: text_with(t, "app.ai.card.diff", [
      ("count", pending.diff.length().to_string()),
    ]),
    steps: [],
    steps_done: 0,
    progress: 100,
    diff_lines: code_lines,
    settled: false,
    settled_note: "",
    seq: 0,
    at: 0,
  })
}

///|
/// 提案错误的本地化文本（可读性/结构/语言分层）。
pub fn proposal_error_text(
  t : @i18n.Translator,
  error : @proposals.ProposalError,
) -> String {
  match error {
    @proposals.Readability(target) =>
      text_with(t, "err.proposal_readability", [("target", target)])
    @proposals.Structural(issue) => structural_error_text(t, issue)
    @proposals.LanguageIssue(name) =>
      text_with(t, "err.proposal_language", [("name", name)])
    @proposals.UnknownControl(name) =>
      text_with(t, "err.proposal_unknown_control", [("name", name)])
    @proposals.UnknownHandler(name) =>
      text_with(t, "err.proposal_unknown_handler", [("name", name)])
    @proposals.DuplicateHandler(name) =>
      text_with(t, "err.proposal_duplicate_handler", [("name", name)])
    @proposals.InvalidJson => text(t, "err.proposal_invalid_json")
    @proposals.BadVersion(_) => text(t, "err.proposal_bad_version")
    @proposals.MissingField(field) =>
      text_with(t, "err.proposal_missing_field", [("field", field)])
    @proposals.BadControlKind(kind) =>
      text_with(t, "err.proposal_bad_control_kind", [("kind", kind)])
    @proposals.BadEventKind(kind) =>
      text_with(t, "err.proposal_bad_event_kind", [("kind", kind)])
    @proposals.BadStatement(statement) =>
      text_with(t, "err.proposal_bad_statement", [("statement", statement)])
    @proposals.BadExpr(expr) =>
      text_with(t, "err.proposal_bad_expr", [("expr", expr)])
  }
}

///|
/// 结构错误本地化（IR 层）。
pub fn structural_error_text(
  t : @i18n.Translator,
  error : @ir.IrError,
) -> String {
  match error {
    @ir.DuplicateControlName(name) =>
      text_with(t, "err.duplicate_control", [("name", name)])
    @ir.InvalidControlName(name) =>
      text_with(t, "err.invalid_control_name", [("name", name)])
    @ir.InvalidVariableName(name) =>
      text_with(t, "err.invalid_variable_name", [("name", name)])
    @ir.DuplicateVariableName(name) =>
      text_with(t, "err.duplicate_variable", [("name", name)])
    @ir.InvalidControlRect(name) =>
      text_with(t, "err.invalid_control_rect", [("name", name)])
    @ir.DuplicateHandler(name) =>
      text_with(t, "err.duplicate_handler", [("name", name)])
    @ir.UnknownControlInHandler(name) =>
      text_with(t, "err.unknown_handler_control", [("name", name)])
    @ir.UnsupportedEvent(control, event) =>
      text_with(t, "err.unsupported_event", [
        ("control", control),
        ("event", event),
      ])
    @ir.TooManyControls => text(t, "err.too_many_controls")
    @ir.TooManyVariables => text(t, "err.too_many_variables")
    @ir.TooManyHandlers => text(t, "err.too_many_handlers")
    @ir.TooManyStatements(_) => text(t, "err.too_many_statements")
    @ir.LoopTooDeep(_) => text(t, "err.loop_too_deep")
    @ir.ExprTooDeep(_) => text(t, "err.expr_too_deep")
    @ir.DuplicateFunctionName(name) =>
      text_with(t, "err.duplicate_function", [("name", name)])
    @ir.InvalidFunctionName(name) =>
      text_with(t, "err.invalid_function_name", [("name", name)])
    @ir.DuplicateParam(func, param) =>
      text_with(t, "err.duplicate_param", [("a", func), ("b", param)])
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
/// AI 域消息处理：未命中的消息返回 None 交还链式分发。
fn update_ai_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    SetPrompt(value) => {
      // 草稿进**当前会话**（M3 会话切片化）
      model.ai_sessions.amend({
        ..model.ai_sessions.current(),
        prompt_draft: value,
      })
      Some(({ ..model, prompt_error: "", }, @moui.Effect::none()))
    }
    ExplainHandler =>
      Some(
        (
          { ..model, explanation: local_explanation(model), },
          @moui.Effect::none(),
        ),
      )
    // 选模式即收起下拉（V4）：脚注从四选一胶囊行切回单芯片
    SetComposerMode(mode) =>
      Some(
        (
          { ..model, composer_mode: mode, composer_mode_picker_open: false, },
          @moui.Effect::none(),
        ),
      )
    SetRightPanelTab(tab) =>
      Some(({ ..model, right_panel_tab: tab, }, @moui.Effect::none()))
    ToggleComposerModePicker =>
      Some(
        (
          {
            ..model,
            composer_mode_picker_open: !model.composer_mode_picker_open,
          },
          @moui.Effect::none(),
        ),
      )
    // 「发送」按当前模式分流到既有通道——模式只改**入口路由**，
    // 不新增执行路径（提案仍走校验链，讲解仍是确定性函数）。
    ComposerRun => Some(composer_run(model))
    GenerateProposal => {
      let completion = @proposals.fake_model_completion(
        model.ai_sessions.current().prompt_draft,
        model.program,
      )
      Some((proposal_from_completion(model, completion), @moui.Effect::none()))
    }
    AcceptProposal =>
      // 采纳是程序变更：过撤销点（提案未改变 IR 时为 no-op 不入栈）
      Some(
        (
          with_undo_point(model, "", m => accept_proposal(m)),
          @moui.Effect::none(),
        ),
      )
    RejectProposal =>
      Some(
        (
          match model.pending {
            None => model
            Some(pending) => {
              let t = translator(model)
              let rejected = settle_newest_thread_card(
                record_history(model, pending, false),
                text(t, "app.ai.card.rejected"),
              )
              let logged = log_line(
                rejected,
                LogLevel::LogWarn,
                text(t, "app.log.proposal_rejected"),
              )
              let tracked = push_recent(
                logged,
                pending.summary,
                text(t, "app.recent.action.agent_reject"),
                true,
              )
              let toasted = push_toast(
                tracked,
                text(t, "app.toast.proposal_rejected"),
                true,
              )
              let rejected = { ..toasted, pending: None, }
              mark_ai_sessions_dirty(rejected)
              rejected
            }
          },
          @moui.Effect::none(),
        ),
      )
    // 真实 provider 结果是纯状态转移（网络已完成）：走与假模型同一条
    // proposal_from_completion 校验链。此前 RealGenerationFinished 没有
    // 处理器、结果被静默丢弃（404 时代从未成功所以未暴露）。
    RealGenerationFinished(result) =>
      match result {
        Ok(completion) =>
          Some(
            (
              { ..proposal_from_completion(model, completion), ai_busy: false, },
              @moui.Effect::none(),
            ),
          )
        Err(message) =>
          Some(
            (
              push_error_card(
                { ..model, prompt_error: message, ai_busy: false, },
                message,
              ),
              @moui.Effect::none(),
            ),
          )
      }
    RealExplanationFinished(result) =>
      match result {
        Ok(explanation) =>
          Some(
            ({ ..model, explanation, ai_busy: false, }, @moui.Effect::none()),
          )
        Err(message) =>
          Some(
            (
              { ..model, explanation: message, ai_busy: false, },
              @moui.Effect::none(),
            ),
          )
      }
    SetProviderMode(mode) =>
      Some(({ ..model, provider_mode: mode, }, @moui.Effect::none()))
    SetProviderEndpoint(value) =>
      Some(({ ..model, provider_endpoint: value, }, @moui.Effect::none()))
    SetProviderModel(value) =>
      Some(({ ..model, provider_model: value, }, @moui.Effect::none()))
    // 掩码态下 text_field 的 on_input 送来的是星号串，直接写会毁掉真值：
    // 未展开时忽略编辑，用户点「显示」后再改。
    SetProviderKey(value) =>
      if model.provider_key_revealed {
        Some(({ ..model, provider_key: value, }, @moui.Effect::none()))
      } else {
        Some((model, @moui.Effect::none()))
      }
    ToggleProviderKeyReveal =>
      Some(
        (
          { ..model, provider_key_revealed: !model.provider_key_revealed, },
          @moui.Effect::none(),
        ),
      )
    // 墙钟刷新：纯状态转移（订阅只在 AI 模式活跃，见 run_subscription）
    ClockUpdated(clock) => Some(({ ..model, clock, }, @moui.Effect::none()))
    // 会话存储加载回执（M5）：Success 解码替换（坏文件 with_notice 不静默）；
    // Failure = 文件尚不存在（首跑常态），保持默认会话不声不响。
    AiSessionsStoreLoaded(result) =>
      match result {
        Success(payload) =>
          match @ai.decode_ai_sessions(payload) {
            Ok(container) => {
              let restored : Model = {
                ..model,
                ai_sessions: container,
                transcript_follow: true,
                transcript_scroll: @geometry.Point::new(x=0.0, y=0.0),
              }
              restored.transcript_scroll_seq = restored.transcript_scroll_seq +
                1
              Some((restored, @moui.Effect::none()))
            }
            Err(error) =>
              Some(
                (
                  with_notice(
                    model,
                    store_error_text(translator(model), error),
                    true,
                  ),
                  @moui.Effect::none(),
                ),
              )
          }
        Failure(_) | Cancelled => Some((model, @moui.Effect::none()))
      }
    // 写盘回执：失败才提示（保存是常规动作,成功不刷屏）
    AiSessionsStoreSaved(result) =>
      match result {
        Success(_) | Cancelled => Some((model, @moui.Effect::none()))
        Failure(error) =>
          Some((push_toast(model, error.message, true), @moui.Effect::none()))
      }
    // 时间线消息动作（对白转录）：编辑 = 回填草稿；重发 = 回填 + 立即重跑
    // （ComposerRun 语义，不是第二条执行通道）。
    EditUserPrompt(seq) =>
      Some((restore_prompt_draft(model, seq), @moui.Effect::none()))
    RetryUserPrompt(seq) => {
      let restored = restore_prompt_of_turn(model, seq)
      if restored.ai_sessions.current().prompt_draft == "" {
        Some((restored, @moui.Effect::none()))
      } else {
        Some(composer_run(restored))
      }
    }
    // 时间线受控滚动（终端同款）：上滚 = 关自动跟随（出现「回到底部」），
    // 下滚 = 恢复跟随；新内容追加时只在跟随态强制贴底。
    TranscriptScrolled(offset) => {
      let was = model.transcript_scroll.y
      model.transcript_scroll = offset
      if offset.y < was - 2.0 {
        model.transcript_follow = false
      } else if offset.y > was + 2.0 {
        model.transcript_follow = true
      }
      Some((model, @moui.Effect::none()))
    }
    // === 左栏会话列表（M4）：搜索 / 悬停 / 行内改名 ===
    ToggleAiSessionSearch => {
      let opening = !model.ai_sessions_search_open
      Some(
        (
          {
            ..model,
            ai_sessions_search_open: opening,
            ai_sessions_query: if opening {
              model.ai_sessions_query
            } else {
              ""
            },
          },
          @moui.Effect::none(),
        ),
      )
    }
    SetAiSessionsQuery(value) =>
      Some(({ ..model, ai_sessions_query: value, }, @moui.Effect::none()))
    AiSessionHover(index, entered) =>
      Some(
        (
          { ..model, ai_session_hover: if entered { index } else { -1 }, },
          @moui.Effect::none(),
        ),
      )
    AiSessionRenameStart(index) =>
      match model.ai_sessions.session_at(index) {
        Some(session) =>
          Some(
            (
              { ..model, session_rename: Some((index, session.title)), },
              @moui.Effect::none(),
            ),
          )
        None => Some((model, @moui.Effect::none()))
      }
    AiSessionRenameDraft(value) =>
      match model.session_rename {
        Some((index, _)) =>
          Some(
            (
              { ..model, session_rename: Some((index, value)), },
              @moui.Effect::none(),
            ),
          )
        None => Some((model, @moui.Effect::none()))
      }
    AiSessionRenameCommit =>
      match model.session_rename {
        Some((index, draft)) => {
          let trimmed = draft.trim().to_owned()
          if trimmed != "" {
            let _ = model.ai_sessions.rename(index, trimmed)
            // 改名是结构性事件：盖「最近活动」戳 + 存储脏标
            model.ai_sessions.touch(civil_seconds(model.clock))
            mark_ai_sessions_dirty(model)
          }
          Some(({ ..model, session_rename: None, }, @moui.Effect::none()))
        }
        None => Some((model, @moui.Effect::none()))
      }
    AiSessionRenameDismiss =>
      Some(({ ..model, session_rename: None, }, @moui.Effect::none()))
    TranscriptScrollToBottom => {
      model.transcript_follow = true
      model.transcript_scroll = @geometry.Point::new(x=0.0, y=1000000000.0)
      model.transcript_scroll_seq = model.transcript_scroll_seq + 1
      Some((model, @moui.Effect::none()))
    }
    _ => None
  }
}

///|
/// 自动贴底：跟随态下新内容追加后强制滚到底部（ScrollRequest offset 用
/// 1e9 由容器钳底，终端先例）。非跟随态不动——用户正在上滚看历史。
pub fn follow_transcript(model : Model) -> Model {
  if model.transcript_follow {
    model.transcript_scroll = @geometry.Point::new(x=0.0, y=1000000000.0)
    model.transcript_scroll_seq = model.transcript_scroll_seq + 1
  }
  model
}

///|
/// 按 seq 找时间线里的卡（动作消息只带 seq；找不到返回 None）。
fn card_by_seq(model : Model, seq : Int) -> AiCard? {
  let mut found : AiCard? = None
  for card in model.ai_sessions.current().cards {
    if card.seq == seq {
      found = Some(card)
    }
  }
  found
}

///|
/// 复制用的消息正文（剪贴板写入在服务层执行,这里只取文本）。
pub fn card_text_by_seq(model : Model, seq : Int) -> String? {
  match card_by_seq(model, seq) {
    Some(card) => Some(card.body)
    None => None
  }
}

///|
/// 把一条用户提问的原文回填进 composer 草稿（气泡「编辑」动作）。
/// 只在目标卡是 CardUserPrompt 时生效。
fn restore_prompt_draft(model : Model, seq : Int) -> Model {
  match card_by_seq(model, seq) {
    Some(card) =>
      if card.kind is CardUserPrompt {
        let draft = card.body
        model.ai_sessions.amend({
          ..model.ai_sessions.current(),
          prompt_draft: draft,
        })
        { ..model, prompt_error: "", }
      } else {
        model
      }
    None => model
  }
}

///|
/// 「重发」：找到该条 AI 卡**之前最近的一条用户提问**，回填草稿。
/// 找不到（会话开头就没有提问）时草稿保持原样、重发 no-op。
fn restore_prompt_of_turn(model : Model, seq : Int) -> Model {
  let cards = model.ai_sessions.current().cards
  let mut prompt : String? = None
  let mut index = cards.length() - 1
  while index >= 0 {
    let card = cards[index]
    if card.seq == seq {
      // 从目标卡往前找最近的用户提问
      let mut walk = index
      while walk >= 0 {
        let candidate = cards[walk]
        if candidate.kind is CardUserPrompt {
          prompt = Some(candidate.body)
          break
        }
        walk = walk - 1
      }
      break
    }
    index = index - 1
  }
  match prompt {
    Some(text) => {
      model.ai_sessions.amend({
        ..model.ai_sessions.current(),
        prompt_draft: text,
      })
      { ..model, prompt_error: "", }
    }
    None => model
  }
}

///|
/// 记录提案历史（会话内）：采纳/拒绝各记一条，seq 单调递增。
fn record_history(
  model : Model,
  pending : PendingProposal,
  accepted : Bool,
) -> Model {
  let history : Array[ProposalRecord] = []
  for record in model.ai_sessions.current().proposal_history {
    history.push(record)
  }
  history.push(ProposalRecord::{
    summary: pending.summary,
    diff: pending.diff,
    code_diff: pending.code_diff,
    accepted,
    seq: history.length() + 1,
  })
  // 历史按会话隔离（M3）：amend 当前会话
  model.ai_sessions.amend({
    ..model.ai_sessions.current(),
    proposal_history: history,
  })
  model
}
