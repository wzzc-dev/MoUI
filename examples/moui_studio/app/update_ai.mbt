///|
/// 「发送」按当前模式分流到既有通道——模式只改**入口路由**，不新增
/// 执行路径（提案仍走 proposals 校验链，讲解仍是确定性函数）。
fn composer_run(model : Model) -> (Model, @moui.Effect[Msg]) {
  match model.composer_mode {
    // 解释需要「当前子程序」才有话说：没选中就先选第一个子程序
    // （与左栏点选同一语义），否则讲解恒为空——点了没反应。
    ComposeExplain => {
      let targeted = if current_handler(model) is None &&
        model.program.handlers.length() > 0 {
        let first = model.program.handlers[0]
        update_pure(
          model,
          SelectHandler(handler_key(first.control_name, first.event.tag())),
        )
      } else {
        (model, @moui.Effect::none())
      }
      update_pure(targeted.0, ExplainHandler)
    }
    ComposeRepair => update_pure(model, RestoreCodeDraft)
    // 生成 = 以空程序为基底的修改：清空控件与子程序让提案从零重建，
    // 走的还是同一个 proposals 校验链（不是「另一条生成通道」）。
    ComposeGenerate => {
      let cleared = {
        ..model,
        program: @ir.StudioProgram::{
          ..model.program,
          controls: [],
          handlers: [],
          functions: [],
        },
      }
      update_pure(cleared, GenerateProposal)
    }
    ComposeEdit => update_pure(model, GenerateProposal)
  }
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
          prompt_draft: "",
          selected_control: first_control_name(next.controls),
          run: None,
          runtime_values: @studio_lang.initial_values(next),
          runtime_texts: @studio_lang.initial_texts(next),
          runtime_rows: @studio_lang.initial_rows(next),
          runtime_selections: Map([], capacity=4),
        }
        let accepted = settle_newest_thread_card(
          record_history(cleared, pending, true),
          text(translator(model), "app.ai.card.applied"),
        )
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
        // 不再 push_toast 与 notice 各写一份）。
        with_notice(tracked, text(t, "app.toast.proposal_accepted"), false)
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
  let cards = model.ai_cards
  let mut index = cards.length() - 1
  while index >= 0 {
    let card = cards[index]
    if !card.settled && (card.kind is CardDiff || card.kind is CardSideEffect) {
      cards[index] = AiCard::{ ..card, settled: true, settled_note: note, }
      break
    }
    index = index - 1
  }
  { ..model, ai_cards: cards, }
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
  push_ai_card(model, AiCard::{
    kind: CardDiff,
    title: pending.summary,
    body: text_with(t, "app.ai.card.diff", [
      ("count", pending.diff.length().to_string()),
    ]),
    steps: [],
    steps_done: 0,
    progress: 100,
    diff_lines: lines,
    settled: false,
    settled_note: "",
    seq: 0,
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
    SetPrompt(value) =>
      Some(
        (
          { ..model, prompt_draft: value, prompt_error: "", },
          @moui.Effect::none(),
        ),
      )
    ExplainHandler =>
      Some(
        (
          { ..model, explanation: local_explanation(model), },
          @moui.Effect::none(),
        ),
      )
    SetComposerMode(mode) =>
      Some(({ ..model, composer_mode: mode, }, @moui.Effect::none()))
    // 「发送」按当前模式分流到既有通道——模式只改**入口路由**，
    // 不新增执行路径（提案仍走校验链，讲解仍是确定性函数）。
    ComposerRun => Some(composer_run(model))
    GenerateProposal => {
      let completion = @proposals.fake_model_completion(
        model.prompt_draft,
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
              { ..toasted, pending: None, }
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
              { ..model, prompt_error: message, ai_busy: false, },
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
    _ => None
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
  for record in model.proposal_history {
    history.push(record)
  }
  history.push(ProposalRecord::{
    summary: pending.summary,
    diff: pending.diff,
    accepted,
    seq: history.length() + 1,
  })
  { ..model, proposal_history: history, }
}
