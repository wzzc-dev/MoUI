///|
/// 确定性假模型：关键词路由到内置模板，产出与真实模型完全同构的
/// 提案 JSON 文本。浏览器离线全功能可演示；现场路演不依赖网络与凭据。
/// 真实模型走同一路径：provider 返回文本 → extract_json_object →
/// decode_proposal → 同一套校验链。

///|
fn contains_any(text : String, keywords : Array[String]) -> Bool {
  for keyword in keywords {
    if text.contains(keyword) {
      return true
    }
  }
  false
}

///|
/// 关键词 → 样例。中英文关键词都认；都不中走通用表单兜底。
pub fn route_prompt(prompt : String) -> String {
  let text = prompt.to_lower()
  if contains_any(text, [
      "点名", "随机抽", "抽签", "roll call", "attendance", "random student",
    ]) {
    "roll_call"
  } else if contains_any(text, [
      "口算", "算术", "练习", "quiz", "arithmetic", "math drill",
    ]) {
    "drill"
  } else if contains_any(text, [
      "小卖部", "商店", "小卖", "库存", "store", "shop", "inventory",
    ]) {
    "store"
  } else if contains_any(text, ["问候", "hello", "hi", "打招呼"]) {
    "hello"
  } else {
    "generic"
  }
}

///|
/// 通用兜底模板：一个输入框 + 一个按钮 + 一句问候（表单应用最小形态）。
fn generic_sample() -> @ir.StudioProgram {
  {
    version: 1,
    window: @ir.WindowSpec::{
      title: "我的小程序",
      width: 640,
      height: 480, timer_interval: 0 },
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Label,
        name: "提示",
        text: "输入名字，点击确定",
        x: 20,
        y: 20,
        width: 260,
        height: 32,
        items: [],
      },
      @ir.Control::{
        id: 2,
        kind: @ir.TextField,
        name: "输入框",
        text: "",
        x: 20,
        y: 60,
        width: 200,
        height: 32,
        items: [],
      },
      @ir.Control::{
        id: 3,
        kind: @ir.Button,
        name: "确定",
        text: "确定",
        x: 20,
        y: 110,
        width: 90,
        height: 32,
        items: [],
      },
    ],
    variables: [],
    handlers: [
      @ir.Handler::{
        control_name: "确定",
        event: @ir.OnClick,
        note_zh: "读取输入框的名字，弹出问候信息框",
        note_en: "read the name from the input box and greet the user",
        body: [
          @ir.Declare("姓名", @ir.Call("get_text", [@ir.Var("输入框")])),
          @ir.Call("message_box", [
            @ir.Binary(@ir.Add, @ir.StrLit("你好，"), @ir.Var("姓名")),
          ]),
        ],
      },
    ],
    functions: [],
  }
}

///|
fn sample_for_route(route : String) -> @ir.StudioProgram {
  match route {
    "roll_call" => sample_roll_call()
    "drill" => sample_drill()
    "store" => sample_store()
    "hello" => sample_hello()
    _ => generic_sample()
  }
}

///|
fn summary_for_route(route : String) -> (String, String) {
  match route {
    "roll_call" =>
      (
        "随机点名：按名单行数抽一位同学", "random roll call over the name list",
      )
    "drill" =>
      (
        "口算训练营：随机出题并批改", "arithmetic drill with random problems",
      )
    "store" =>
      (
        "班级小卖部：记账并在提交前停下确认", "class store with confirmed submission",
      )
    "hello" =>
      (
        "问候小程序：点击按钮显示问候语", "hello app greeting on button click",
      )
    _ =>
      (
        "通用表单：输入名字并问候", "generic form greeting the input name",
      )
  }
}

///|
/// 假模型补全：prompt → 提案 JSON 文本（确定性，可离线演示）。
/// 全量构建语义：先把当前程序的控件/变量/子程序全部移除，再整份新建，
/// 避免在旧程序上叠加出四不像。
pub fn fake_model_completion(
  prompt : String,
  current : @ir.StudioProgram,
) -> String {
  let route = route_prompt(prompt)
  let sample = sample_for_route(route)
  let (summary_zh, summary_en) = summary_for_route(route)
  let proposal = proposal_from_program(sample, summary_zh, summary_en)
  let removes = ProposalV1::{
    ..proposal,
    controls_remove: current.controls.map(control => control.name),
    variables_remove: current.variables.map(variable => variable.name),
    handlers_remove: current.handlers.map(handler => HandlerRef::{
      control: handler.control_name,
      event: handler.event.tag(),
    }),
  }
  encode_proposal(removes)
}

///|
/// 真实模型 system prompt：讲清 schema 与纪律（只产提案，不产源码）。
pub fn proposal_system_prompt() -> String {
  "You generate MoUI Studio program proposals as JSON only. A proposal patches a program: {version:1, summary:{zh,en}, window?, controls:{add,update,remove}, variables:{add,update,remove}, handlers:{add,update,remove}, open_handler?}. Controls: kind in button|label|text_field|check_box|list_box|table, with name/text/x/y/width/height/items. Events: on_click, on_change. Statements use ops declare/assign/if/count_loop/while/break/call with expression trees {t:num|str|bool|var|not|neg|bin|call}. Builtins: message_box, set_text, append_row, get_text, get_number, to_text, text_length, contains, random, row_count, row_at, selected_row (functions/commands) and ask, submit_data (gates). Every added or updated handler MUST include note {zh,en} explaining intent. Names must be self-explanatory. Never output source code; only the proposal JSON."
}
