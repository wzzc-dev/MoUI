///|
/// proposals 测试：模板自洽、提案往返、校验链各层、diff、假模型路由。

///|
fn apply_to_empty(proposal : @proposals.ProposalV1) -> @ir.MomaoProgram {
  @proposals.apply_proposal(@ir.empty_program(), proposal)
}

///|
test "all samples are self-valid programs" {
  for sample in @proposals.all_samples() {
    let structural = @ir.validate_program(sample)
    let language = @momao_lang.validate_program_language(sample)
    if !structural.is_empty() || !language.is_empty() {
      fail("样例「\{sample.window.title}」不合法")
    }
  }
}

///|
test "proposal round trip preserves sample signature" {
  for sample in @proposals.all_samples() {
    let proposal = @proposals.proposal_from_program(
      sample, "测试摘要", "test summary",
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

///|
test "validation chain rejects junk names and missing notes" {
  let junk : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(
      @proposals.sample_hello(),
      "摘要",
      "summary",
    ),
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

///|
test "validation chain rejects unsupported proposal versions" {
  let proposal : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(
      @proposals.sample_hello(),
      "摘要",
      "summary",
    ),
    version: 2,
  }
  let errors = @proposals.validate_proposal(@proposals.sample_hello(), proposal)
  assert_true(errors.any(e => e is @proposals.BadVersion(2)))
}

///|
test "readability checks only AI-touched objects" {
  let program = @proposals.sample_hello()
  let existing = program.handlers[0]
  program.handlers[0] = { ..existing, note_zh: "", note_en: "", }
  let control = program.controls[0]
  let proposal : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(program, "改按钮", "change button"),
    controls_add: [],
    controls_update: [{ ..control, text: "新文本", }],
    variables_add: [],
    handlers_add: [],
  }
  let errors = @proposals.validate_proposal(program, proposal)
  assert_true(!errors.any(e => e is @proposals.Readability(_)))
}

///|
test "validation chain rejects unknown controls and stray break" {
  let unknown : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(
      @proposals.sample_hello(),
      "摘要",
      "summary",
    ),
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
    @proposals.validate_proposal(@ir.empty_program(), unknown).any(e => {
      e is @proposals.Structural(_)
    }),
  )
  let stray : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(
      @proposals.sample_hello(),
      "摘要",
      "summary",
    ),
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
    @proposals.validate_proposal(@ir.empty_program(), stray).any(e => {
      e is @proposals.LanguageIssue(_)
    }),
  )
}

///|
test "control update produces field level diff" {
  let program = @proposals.sample_hello()
  let label = match @ir.find_control(program, "显示") {
    Some(control) => control
    None => fail("样例应有「显示」标签")
  }
  let changed = @ir.Control::{ ..label, text: "新的欢迎语", }
  let proposal : @proposals.ProposalV1 = {
    ..@proposals.proposal_from_program(program, "改文案", "change text"),
    controls_add: [],
    controls_update: [changed],
  }
  let entries = @proposals.proposal_diff(program, proposal)
  assert_true(
    entries.any(e => {
      e.op is @proposals.Changed &&
      e.path == "control.显示.text" &&
      e.old_text == "" &&
      e.new_text == "新的欢迎语"
    }),
  )
  let applied = @proposals.apply_proposal(program, proposal)
  match @ir.find_control(applied, "显示") {
    Some(control) => assert_eq(control.text, "新的欢迎语")
    None => fail("更新后应仍在")
  }
}

///|
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

///|
test "fake model routes prompts deterministically" {
  assert_eq(
    @proposals.route_prompt("帮我做一个随机点名器"),
    "roll_call",
  )
  assert_eq(@proposals.route_prompt("roll call please"), "roll_call")
  assert_eq(@proposals.route_prompt("口算练习"), "drill")
  assert_eq(@proposals.route_prompt("班级小卖部记账"), "store")
  assert_eq(@proposals.route_prompt("做个小商店"), "store")
  assert_eq(@proposals.route_prompt("随便做点东西"), "generic")
  let first = @proposals.fake_model_completion(
    "随机点名",
    @ir.empty_program(),
  )
  let second = @proposals.fake_model_completion(
    "随机点名",
    @ir.empty_program(),
  )
  assert_eq(first, second)
  match @proposals.decode_proposal(first) {
    Ok(proposal) => {
      let errors = @proposals.validate_proposal(@ir.empty_program(), proposal)
      assert_true(errors.is_empty())
      let applied = apply_to_empty(proposal)
      assert_eq(applied.window.title, "班级点名册")
      assert_eq(applied.handlers.length(), 1)
    }
    Err(errors) =>
      fail("假模型产物应可解码: \{errors.length()} 个问题")
  }
}

///|
test "decode tolerates fences and prose around json" {
  let completion = @proposals.fake_model_completion(
    "random roll call",
    @ir.empty_program(),
  )
  let wrapped = "好的，这是提案：\n```json\n\{completion}\n```\n希望对你有帮助"
  match @proposals.decode_proposal(wrapped) {
    Ok(proposal) =>
      assert_eq(proposal.summary_zh != "" || proposal.summary_en != "", true)
    Err(errors) =>
      fail("围栏+散文应可解码: \{errors.length()} 个问题")
  }
  match @proposals.decode_proposal("完全是散文，没有 JSON") {
    Err(errors) => assert_true(errors.any(e => e is @proposals.InvalidJson))
    Ok(_) => fail("无 JSON 应拒绝")
  }
}

///|
test "system prompt mentions gates and notes" {
  let prompt = @proposals.proposal_system_prompt()
  assert_true(prompt.contains("submit_data"))
  assert_true(prompt.contains("note"))
  assert_true(prompt.contains("Never output source code"))
}

///|
/// 拒绝矩阵：13 类 ProposalError 全覆盖（可直达的逐一触发；
/// UnknownControl/UnknownHandler/DuplicateHandler 三个保留变体经
/// Structural(IrError) 语义等价触发——校验链在合并程序上跑 @ir.validate_program）。

///|
fn encoded_hello() -> String {
  @proposals.encode_proposal(
    @proposals.proposal_from_program(
      @proposals.sample_hello(),
      "测试",
      "test",
    ),
  )
}

///|
fn decode_errors(text : String) -> Array[@proposals.ProposalError] {
  match @proposals.decode_proposal(text) {
    Err(errors) => errors
    Ok(_) => []
  }
}

///|
test "reject: invalid json, missing version, bad version" {
  assert_true(decode_errors("{ nope") is [InvalidJson, ..])
  assert_true(decode_errors("{}") is [MissingField("version")])
  assert_true(decode_errors("{\"version\": 2}") is [BadVersion(2)])
}

///|
test "reject: bad control kind via tampered encode" {
  let tampered = encoded_hello().replace(
    old="\"kind\":\"button\"",
    new="\"kind\":\"slider\"",
  )
  let errors = decode_errors(tampered)
  assert_true(errors.any(e => e is BadControlKind("slider")))
}

///|
test "reject: bad event kind via tampered encode" {
  let tampered = encoded_hello().replace(
    old="\"event\":\"on_click\"",
    new="\"event\":\"on_hover\"",
  )
  let errors = decode_errors(tampered)
  assert_true(errors.any(e => e is BadEventKind("on_hover")))
}

///|
test "reject: bad statement kind via tampered encode" {
  let tampered = encoded_hello().replace(
    old="\"op\":\"call\"",
    new="\"op\":\"summon\"",
  )
  let errors = decode_errors(tampered)
  assert_true(errors.any(e => e is BadStatement("summon")))
}

///|
test "reject: bad expr kind via tampered encode" {
  let tampered = encoded_hello().replace(
    old="\"t\":\"str\"",
    new="\"t\":\"num\"",
  )
  let errors = decode_errors(tampered)
  assert_true(errors.any(e => e is BadExpr("num")))
}

///|
/// 校验链层：结构 / 语言 / 可读性（struct 变异 + validate_proposal）。

///|
fn handler_ref_proposal(
  control : String,
  event : @ir.EventKind,
) -> @proposals.ProposalV1 {
  let base = @proposals.proposal_from_program(
    @ir.empty_program(),
    "加子程序",
    "add handler",
  )
  {
    ..base,
    handlers_add: [
      @ir.Handler::{
        control_name: control,
        event,
        note_zh: "点击后打招呼",
        note_en: "say hi on click",
        body: [
          @ir.Call("set_text", [@ir.StrLit("显示"), @ir.StrLit("你好")]),
        ],
      },
    ],
  }
}

///|
test "reject: empty summary is a readability failure" {
  let base = @proposals.proposal_from_program(@proposals.sample_hello(), "", "")
  let errors = @proposals.validate_proposal(@proposals.sample_hello(), base)
  assert_true(errors.any(e => e is Readability("summary")))
}

///|
test "reject: handler without bilingual note" {
  let base = @proposals.proposal_from_program(
    @ir.empty_program(),
    "无说明",
    "no note",
  )
  let proposal = {
    ..handler_ref_proposal("按钮", @ir.OnClick),
    handlers_add: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [],
      },
    ],
    controls_add: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "按钮",
        text: "",
        x: 10,
        y: 10,
        width: 80,
        height: 28,
        items: [],
      },
    ],
  }
  let errors = @proposals.validate_proposal(@ir.empty_program(), proposal)
  assert_true(errors.any(e => e is Readability("handler.按钮.on_click.note")))
}

///|
test "reject: junk names a1/tmp" {
  let base = @proposals.proposal_from_program(
    @ir.empty_program(),
    "命名",
    "naming",
  )
  let with_junk_control = {
    ..base,
    controls_add: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "a1",
        text: "",
        x: 0,
        y: 0,
        width: 80,
        height: 28,
        items: [],
      },
    ],
  }
  let errors = @proposals.validate_proposal(
    @ir.empty_program(),
    with_junk_control,
  )
  assert_true(errors.any(e => e is Readability("control.a1")))
  let with_junk_var = {
    ..base,
    variables_add: [@ir.Variable::{ name: "tmp", init: "0", }],
  }
  let errors2 = @proposals.validate_proposal(@ir.empty_program(), with_junk_var)
  assert_true(errors2.any(e => e is Readability("variable.tmp")))
}

///|
test "reject: structural issues surface as Structural(IrError)" {
  let base = @proposals.proposal_from_program(
    @proposals.sample_hello(),
    "重复控件",
    "dup control",
  )
  let hello = @proposals.sample_hello()
  let existing = hello.controls[0]
  // 同名控件 → DuplicateControlName
  let dup = { ..base, controls_add: [{ ..existing, id: 999, }], }
  let errors = @proposals.validate_proposal(hello, dup)
  assert_true(errors.any(e => e is Structural(@ir.DuplicateControlName(_))))
  // 子程序引用不存在的控件 → UnknownControlInHandler
  let orphan = {
    ..handler_ref_proposal("不存在", @ir.OnClick),
    controls_add: [],
  }
  let errors2 = @proposals.validate_proposal(@ir.empty_program(), orphan)
  assert_true(errors2.any(e => e is Structural(@ir.UnknownControlInHandler(_))))
  // 按钮不支持 on_change → UnsupportedEvent（控件须真实存在才会查事件支持）
  let wrong_event = {
    ..handler_ref_proposal("按钮", @ir.OnChange),
    controls_add: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "按钮",
        text: "",
        x: 0,
        y: 0,
        width: 80,
        height: 28,
        items: [],
      },
    ],
  }
  let errors3 = @proposals.validate_proposal(@ir.empty_program(), wrong_event)
  assert_true(errors3.any(e => e is Structural(@ir.UnsupportedEvent(_, _))))
  // 重复 (控件, 事件) 子程序 → DuplicateHandler（提案的 add 是替换语义
  // 造不出重复对；重复只能来自损坏的基底程序，校验链照样拦截）
  let corrupt_base : @ir.MomaoProgram = {
    ..@ir.empty_program(),
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "按钮",
        text: "",
        x: 0,
        y: 0,
        width: 80,
        height: 28,
        items: [],
      },
    ],
    handlers: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "一",
        note_en: "one",
        body: [],
      },
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "二",
        note_en: "two",
        body: [],
      },
    ],
  }
  let benign = @proposals.proposal_from_program(
    corrupt_base, "什么也不改", "change nothing",
  )
  let errors4 = @proposals.validate_proposal(corrupt_base, benign)
  assert_true(errors4.any(e => e is Structural(@ir.DuplicateHandler(_))))
}

///|
test "reject: unknown builtin in body is a language issue" {
  let proposal = {
    ..handler_ref_proposal("按钮", @ir.OnClick),
    handlers_add: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "点",
        note_en: "click",
        body: [@ir.Call("魔法命令", [@ir.NumLit(1.0)])],
      },
    ],
    controls_add: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "按钮",
        text: "",
        x: 0,
        y: 0,
        width: 80,
        height: 28,
        items: [],
      },
    ],
  }
  let errors = @proposals.validate_proposal(@ir.empty_program(), proposal)
  assert_true(errors.any(e => e is LanguageIssue(_)))
}
