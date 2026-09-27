///|
/// AI 生成契约：模型只产出版本化 MoeuiProposal（JSON 文本），
/// 不产出任意可执行代码；子程序必须是合法的 Mo易 DSL 源码。
/// 未知 kind / 非法语法 / 重复名称一律拒绝。
/// 假模型按关键词路由内置模板，确定性离线可演示；真实 provider 走
/// proposal_system_prompt 描述的同一 schema。

///|
let proposal_version : Double = 1.0

///|
/// 内置模板：加法计算器。
fn template_calculator() -> FormProject {
  {
    name: "加法计算器",
    window_title: "加法计算器",
    controls: [
      {
        id: 1,
        name: "标题",
        kind: Label,
        x: 40.0,
        y: 32.0,
        width: 280.0,
        height: 36.0,
        text: "加法计算器",
      },
      {
        id: 2,
        name: "数1",
        kind: TextField,
        x: 40.0,
        y: 96.0,
        width: 120.0,
        height: 36.0,
        text: "0",
      },
      {
        id: 3,
        name: "数2",
        kind: TextField,
        x: 200.0,
        y: 96.0,
        width: 120.0,
        height: 36.0,
        text: "0",
      },
      {
        id: 4,
        name: "计算按钮",
        kind: Button,
        x: 40.0,
        y: 160.0,
        width: 120.0,
        height: 40.0,
        text: "计算",
      },
      {
        id: 5,
        name: "结果",
        kind: Label,
        x: 40.0,
        y: 224.0,
        width: 280.0,
        height: 36.0,
        text: "结果将显示在这里",
      },
    ],
    handlers: [
      {
        control: "计算按钮",
        event: "被单击",
        source: "变量 和 = 取数值(\"数1\") + 取数值(\"数2\")\n设置文本(\"结果\", \"和是\" + 转文本(和))",
      },
    ],
    next_id: 6,
  }
}

///|
/// 内置模板：问候应用（与 sample_project 同构，作为兜底）。
fn template_greeting() -> FormProject {
  {
    name: "问候应用",
    window_title: "问候应用",
    controls: [
      {
        id: 1,
        name: "标题",
        kind: Label,
        x: 40.0,
        y: 32.0,
        width: 280.0,
        height: 36.0,
        text: "问候应用",
      },
      {
        id: 2,
        name: "姓名框",
        kind: TextField,
        x: 40.0,
        y: 96.0,
        width: 280.0,
        height: 36.0,
        text: "",
      },
      {
        id: 3,
        name: "问候按钮",
        kind: Button,
        x: 40.0,
        y: 160.0,
        width: 120.0,
        height: 40.0,
        text: "打个招呼",
      },
    ],
    handlers: [
      {
        control: "问候按钮",
        event: "被单击",
        source: "变量 名字 = 取文本(\"姓名框\")\n如果 名字 = \"\" 则\n信息框(\"你好，陌生人！\")\n否则\n信息框(\"你好，\" + 名字 + \"！\")\n结束",
      },
    ],
    next_id: 4,
  }
}

///|
/// 假模型的自然语言路由：纯关键词，不做任何网络请求。
/// 命中模板后仍走完整校验，保证离线演示与真实模式同一质量闸门。
pub fn fake_generate_from_prompt(
  prompt : String,
) -> Result[FormProject, Array[FormError]] {
  let project = if prompt.contains("计算") ||
    prompt.contains("加法") ||
    prompt.contains("求和") ||
    prompt.contains("加") {
    template_calculator()
  } else {
    template_greeting()
  }
  let errors = validate_project(project)
  if errors.is_empty() {
    Ok(project)
  } else {
    Err(errors)
  }
}

///|
/// 解码版本化提案 JSON 文本：严格字段检查，未知 kind / 非法语法拒绝；
/// 解码成功后跑完整项目校验。
pub fn decode_proposal(
  source : String,
) -> Result[FormProject, Array[FormError]] {
  let payload = @json.parse(source) catch { _ => return Err([InvalidJson]) }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err([InvalidProject("提案必须是 JSON 对象")])
  }
  match json_number_field(fields, "version") {
    Some(n) => if n != proposal_version { return Err([UnsupportedVersion]) }
    None => return Err([UnsupportedVersion])
  }
  let window_title = match fields.get("window") {
    Some(Object(window)) => json_string_field(window, "title")
    _ => None
  }
  let window_title = window_title.unwrap_or("窗口")
  let errors : Array[FormError] = []
  let (controls, handlers, next_id) = decode_controls_and_handlers(
    fields, errors,
  )
  let project : FormProject = {
    name: "AI 提案",
    window_title,
    controls,
    handlers,
    next_id,
  }
  for error in validate_project(project) {
    errors.push(error)
  }
  if errors.is_empty() {
    Ok(project)
  } else {
    Err(errors)
  }
}

///|
/// 真实 provider 的系统提示：把提案 schema 与 Mo易 DSL 语法讲清楚，
/// 约束模型只产出 JSON。
pub fn proposal_system_prompt() -> String {
  "你是 Mo易 Studio 的应用生成器。只输出一个 JSON 对象，不要输出任何多余文字。格式：{\"version\":1,\"window\":{\"title\":\"窗口标题\"},\"controls\":[{\"id\":1,\"name\":\"按钮1\",\"kind\":\"Button\",\"x\":40,\"y\":40,\"width\":120,\"height\":40,\"text\":\"按钮文字\"}],\"handlers\":[{\"control\":\"按钮1\",\"event\":\"被单击\",\"source\":\"信息框(\\\"你好\\\")\"}]}。控件 kind 只有 Button(按钮)、Label(标签)、TextField(输入框)；事件只有 Button 的 被单击 和 TextField 的 内容改变。id 从 1 连续编号，name 唯一且不含空格。source 是 Mo易 中文程序，可用：变量 x = 表达式；赋值 x = 表达式；如果 条件 则 … 否则 … 结束；计次循环 n 次 为 i … 结束；当 条件 循环 … 结束；比较 = <> < > <= >=；逻辑 且 或 非；字符串用双引号；内置：信息框(文本)、设置文本(控件名, 文本)、取文本(控件名)、取数值(控件名)、转文本(值)、取长度(文本)、文本包含(文本, 子串)。数字与文本用 + 可拼接。"
}

///|
/// 真实生成回路的纯函数收尾：provider 文本 → 提案解码 → 校验。
/// 容忍 ```json 围栏与前后缀散文：取首个 `{` 到配对 `}` 之间的内容。
pub fn finish_real_generation(
  text : String,
) -> Result[FormProject, Array[FormError]] {
  let start = match text.find("{") {
    Some(index) => index
    None => return Err([InvalidJson])
  }
  let tail = text.exact_view(start~).to_owned()
  let end = match json_object_end(tail) {
    Some(index) => index
    None => tail.length()
  }
  decode_proposal(tail.exact_view(end~).to_owned())
}

///|
/// 从首个 `{` 开始的字符串中，扫描到与之配对的 `}` 之后的偏移（含）。
/// 感知字符串字面量与转义；没有配对时返回 None。
fn json_object_end(text : String) -> Int? {
  let mut i = 0
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  let mut started = false
  for c in text {
    if in_string {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        in_string = false
      }
    } else if c == '"' {
      in_string = true
    } else if c == '{' {
      depth = depth + 1
      started = true
    } else if c == '}' {
      depth = depth - 1
      if started && depth == 0 {
        return Some(i + 1)
      }
    }
    i = i + 1
  }
  None
}
