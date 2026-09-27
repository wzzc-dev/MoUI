///|
/// AI 提案域状态转移：生成/采纳/拒绝、provider 设置、本地讲解。

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
          {
            ..model,
            pending: None,
            notice: text(translator(model), "app.status.proposal_rejected"),
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
    SetProviderKey(value) =>
      Some(({ ..model, provider_key: value, }, @moui.Effect::none()))
    _ => None
  }
}
