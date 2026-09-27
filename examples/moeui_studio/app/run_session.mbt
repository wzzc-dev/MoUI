///|
/// 运行会话：运行模式下的实时状态（控件实时文本 + 信息框横幅）。
/// 不可变值语义：每次事件在值表副本上解释执行，返回新会话，
/// 与 TEA 模型的重渲染约定一致；停止运行即丢弃。

///|
pub(all) struct RunSession {
  values : Map[String, String]
  message : String?
}

///|
fn copy_values(values : Map[String, String]) -> Map[String, String] {
  let next : Map[String, String] = Map([], capacity=values.size() + 8)
  for pair in values.to_array() {
    next[pair.0] = pair.1
  }
  next
}

///|
pub fn RunSession::start(project : FormProject) -> RunSession {
  let values : Map[String, String] = Map([], capacity=16)
  for control in project.controls {
    values[control.name] = control.text
  }
  { values, message: None, }
}

///|
/// 控件当前文本（渲染运行画面用；初始文本兜底）。
pub fn RunSession::text_of(
  self : RunSession,
  name : String,
  fallback : String,
) -> String {
  match self.values.get(name) {
    Some(value) => value
    None => fallback
  }
}

///|
/// 输入框键入（不走 DSL）时的会话更新。
pub fn RunSession::set_text(
  self : RunSession,
  name : String,
  text : String,
) -> RunSession {
  let values = copy_values(self.values)
  values[name] = text
  { values, message: self.message, }
}

///|
pub fn RunSession::show_message(self : RunSession, text : String) -> RunSession {
  { values: self.values, message: Some(text), }
}

///|
pub fn RunSession::clear_message(self : RunSession) -> RunSession {
  { values: self.values, message: None, }
}

///|
/// 运行一段 Mo易 子程序：在值表副本上解释执行（信息框写入横幅、
/// 设置文本写回副本），成功后返回新会话；失败返回 RunError，
/// 原会话不变。
pub fn RunSession::run_source(
  self : RunSession,
  source : String,
  max_steps? : Int = 100_000,
) -> Result[RunSession, RunError] {
  let values = copy_values(self.values)
  let boxes : Array[String] = []
  let host : HostContext = {
    message_box: fn(text) { boxes.push(text) },
    set_text: fn(name, text) { values[name] = text },
    get_text: fn(name) {
      match values.get(name) {
        Some(value) => value
        None => ""
      }
    },
  }
  match run_body(source, host, max_steps~) {
    Ok(_) => {
      let message = if boxes.is_empty() {
        self.message
      } else {
        Some(boxes[boxes.length() - 1])
      }
      Ok({ values, message, })
    }
    Err(error) => Err(error)
  }
}
