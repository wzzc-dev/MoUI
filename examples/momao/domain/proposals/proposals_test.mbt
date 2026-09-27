///|
/// proposals 测试：模板自洽、提案往返、校验链各层、diff、假模型路由。

///|
fn apply_to_empty(proposal : @proposals.ProposalV1) -> @ir.MomaoProgram {
  @proposals.apply_proposal(@ir.empty_program(), proposal)
}

test "all samples are self-valid programs" {
  for sample in @proposals.all_samples() {
    let structural = @ir.validate_program(sample)
    let language = @momao_lang.validate_program_language(sample)
    if !structural.is_empty() || !language.is_empty() {
      fail("样例「\{sample.window.title}」不合法")
    }
  }
}

test "proposal round trip preserves sample signature" {
  for sample in @proposals.all_samples() {
    let proposal = @proposals.proposal_from_program(
      sample,
      "测试摘要",
      "test summary",
    )
    let text = @proposals.encode_proposal(proposal)
    match @proposals.decode_proposal(text) {
      Ok(decoded) => {
        let errors = @proposals.validate_proposal(@ir.empty_program(), decoded)
        if !errors.is_empty() {
          fail("提案校验失败: \{errors.length()} 个问题")
        }
        assert_eq(
          @ir.program_signature(apply_to_empty(decoded)),
          @ir.program_signature(sample),
        )
      }
      Err(errors) => fail("提案解码失败: \{errors.length()} 个问题")
    }
  }
}

test "validation chain rejects junk names and missing notes" {
  let junk : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(@proposals.sample_hello(), "摘要", "summary"),
    controls_add: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "tmp",
        text: "x",
        x: 0,
        y: 0,
        width: 10,
        height: 10,
        items: [],
      },
    ],
    handlers_add: [],
    variables_add: [],
  }
  let errors = @proposals.validate_proposal(@ir.empty_program(), junk)
  assert_true(errors.any(e => e is @proposals.Readability(_)))
  let no_note : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(@proposals.sample_hello(), "", ""),
    handlers_add: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [@ir.Call("message_box", [@ir.StrLit("hi")])],
      },
    ],
    controls_add: [],
    variables_add: [],
    summary_zh: "有中文摘要",
    summary_en: "has english summary",
  }
  let note_errors = @proposals.validate_proposal(@ir.empty_program(), no_note)
  assert_true(note_errors.any(e => e is @proposals.Readability(_)))
}

test "validation chain rejects unknown controls and stray break" {
  let unknown : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(@proposals.sample_hello(), "摘要", "summary"),
    handlers_add: [
      @ir.Handler::{
        control_name: "不存在",
        event: @ir.OnClick,
        note_zh: "n",
        note_en: "n",
        body: [],
      },
    ],
    controls_add: [],
    variables_add: [],
  }
  assert_true(
    @proposals.validate_proposal(
      @ir.empty_program(),
      unknown,
    ).any(e => e is @proposals.Structural(_)),
  )
  let stray : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(@proposals.sample_hello(), "摘要", "summary"),
    handlers_add: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "n",
        note_en: "n",
        body: [@ir.Break],
      },
    ],
    controls_add: [],
    variables_add: [],
  }
  assert_true(
    @proposals.validate_proposal(
      @ir.empty_program(),
      stray,
    ).any(e => e is @proposals.LanguageIssue(_)),
  )
}

test "control update produces field level diff" {
  let program = @proposals.sample_hello()
  let label = match @ir.find_control(program, "显示") {
    Some(control) => control
    None => fail("样例应有「显示」标签")
  }
  let changed = @ir.Control::{ ..label, text: "新的欢迎语" }
  let proposal : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(program, "改文案", "change text"),
    controls_add: [],
    controls_update: [changed],
  }
  let entries = @proposals.proposal_diff(program, proposal)
  assert_true(
    entries.any(e =>
      e.op is @proposals.Changed &&
      e.path == "control.显示.text" &&
      e.old_text == "" &&
      e.new_text == "新的欢迎语"),
  )
  let applied = @proposals.apply_proposal(program, proposal)
  match @ir.find_control(applied, "显示") {
    Some(control) => assert_eq(control.text, "新的欢迎语")
    None => fail("更新后应仍在")
  }
}

test "handler removal cascades from control removal" {
  let program = @proposals.sample_hello()
  let proposal : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(program, "删按钮", "remove button"),
    controls_add: [],
    handlers_add: [],
    variables_add: [],
    controls_remove: ["按钮"],
  }
  let applied = @proposals.apply_proposal(program, proposal)
  assert_true(applied.handlers.is_empty())
  assert_true(@ir.find_control(applied, "按钮") is None)
}

test "fake model routes prompts deterministically" {
  assert_eq(@proposals.route_prompt("帮我做一个随机点名器"), "roll_call")
  assert_eq(@proposals.route_prompt("roll call please"), "roll_call")
  assert_eq(@proposals.route_prompt("口算练习"), "drill")
  assert_eq(@proposals.route_prompt("班级小卖部记账"), "store")
  assert_eq(@proposals.route_prompt("做个小商店"), "store")
  assert_eq(@proposals.route_prompt("随便做点东西"), "generic")
  let first = @proposals.fake_model_completion("随机点名", @ir.empty_program())
  let second = @proposals.fake_model_completion("随机点名", @ir.empty_program())
  assert_eq(first, second)
  match @proposals.decode_proposal(first) {
    Ok(proposal) => {
      let errors = @proposals.validate_proposal(@ir.empty_program(), proposal)
      assert_true(errors.is_empty())
      let applied = apply_to_empty(proposal)
      assert_eq(applied.window.title, "班级点名册")
      assert_eq(applied.handlers.length(), 1)
    }
    Err(errors) => fail("假模型产物应可解码: \{errors.length()} 个问题")
  }
}

test "decode tolerates fences and prose around json" {
  let completion = @proposals.fake_model_completion("random roll call", @ir.empty_program())
  let wrapped = "好的，这是提案：\n```json\n\{completion}\n```\n希望对你有帮助"
  match @proposals.decode_proposal(wrapped) {
    Ok(proposal) => assert_eq(proposal.summary_zh != "" || proposal.summary_en != "", true)
    Err(errors) => fail("围栏+散文应可解码: \{errors.length()} 个问题")
  }
  match @proposals.decode_proposal("完全是散文，没有 JSON") {
    Err(errors) => assert_true(errors.any(e => e is @proposals.InvalidJson))
    Ok(_) => fail("无 JSON 应拒绝")
  }
}

test "system prompt mentions gates and notes" {
  let prompt = @proposals.proposal_system_prompt()
  assert_true(prompt.contains("submit_data"))
  assert_true(prompt.contains("note"))
  assert_true(prompt.contains("Never output source code"))
}
