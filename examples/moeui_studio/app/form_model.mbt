///|
/// 窗体模型：控件、事件子程序与项目级校验。
/// 设计期唯一事实来源；`.moeui.json` 编解码与 AI 提案都落在这一层。

///|
pub(all) enum ControlKind {
  Button // 按钮
  Label // 标签
  TextField // 输入框
}

///|
pub fn ControlKind::label(self : ControlKind) -> String {
  match self {
    Button => "按钮"
    Label => "标签"
    TextField => "输入框"
  }
}

///|
pub fn parse_control_kind(text : String) -> ControlKind? {
  match text {
    "Button" | "按钮" => Some(Button)
    "Label" | "标签" => Some(Label)
    "TextField" | "输入框" => Some(TextField)
    _ => None
  }
}

///|
/// 控件可绑定的事件（易语言式命名）。
pub fn ControlKind::events(self : ControlKind) -> Array[String] {
  match self {
    Button => ["被单击"]
    Label => []
    TextField => ["内容改变"]
  }
}

///|
pub fn kind_supports_event(kind : ControlKind, event : String) -> Bool {
  kind.events().contains(event)
}

///|
pub(all) struct FormControl {
  id : Int
  name : String
  kind : ControlKind
  x : Double
  y : Double
  width : Double
  height : Double
  text : String
}

///|
pub(all) struct EventHandler {
  control : String
  event : String
  source : String
}

///|
pub(all) struct FormProject {
  name : String
  window_title : String
  controls : Array[FormControl]
  handlers : Array[EventHandler]
  mut next_id : Int
}

///|
pub fn FormProject::empty(name? : String = "未命名项目") -> FormProject {
  { name, window_title: "窗口", controls: [], handlers: [], next_id: 1, }
}

///|
pub fn FormProject::find_control(self : FormProject, id : Int) -> FormControl? {
  for control in self.controls {
    if control.id == id {
      return Some(control)
    }
  }
  None
}

///|
pub fn FormProject::find_control_by_name(
  self : FormProject,
  name : String,
) -> FormControl? {
  for control in self.controls {
    if control.name == name {
      return Some(control)
    }
  }
  None
}

///|
pub fn FormProject::handler_of(
  self : FormProject,
  control : String,
  event : String,
) -> String? {
  for handler in self.handlers {
    if handler.control == control && handler.event == event {
      return Some(handler.source)
    }
  }
  None
}

///|
/// 名称合法性：非空、无空白（名称会出现在中文代码与画布上）。
pub fn control_name_valid(name : String) -> Bool {
  if name.is_empty() {
    return false
  }
  for c in name {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      return false
    }
  }
  true
}

///|
pub(all) enum FormError {
  InvalidJson
  BadFormat
  UnsupportedVersion
  InvalidProject(String) // 字段类型/缺失的通用描述
  UnknownKind(String)
  BadName(String) // 名称非法
  DuplicateName(String)
  BadSize(String) // 宽高必须为正
  UnknownHandlerControl(String)
  UnknownHandlerEvent(String, String) // 控件, 事件
  DuplicateHandler(String, String)
  BadSyntax(String, String, String) // 控件, 事件, 语法错误信息
}

///|
pub fn FormError::label(self : FormError) -> String {
  match self {
    InvalidJson => "不是合法的 JSON"
    BadFormat => "format 不是 moeui.project"
    UnsupportedVersion => "不支持的版本号"
    InvalidProject(detail) => "项目字段错误：\{detail}"
    UnknownKind(kind) => "未知控件类型：\{kind}"
    BadName(name) => "控件名称非法：\{name}（非空且不含空白）"
    DuplicateName(name) => "控件重名：\{name}"
    BadSize(name) => "控件宽高必须为正：\{name}"
    UnknownHandlerControl(name) =>
      "事件子程序指向不存在的控件：\{name}"
    UnknownHandlerEvent(name, event) =>
      "控件 \{name} 不支持事件 \{event}"
    DuplicateHandler(name, event) =>
      "重复的事件子程序：\{name}.\{event}"
    BadSyntax(name, event, message) =>
      "代码语法错误（\{name}.\{event}）：\{message}"
  }
}

///|
fn error_labels(errors : Array[FormError]) -> String {
  let mut text = ""
  let mut first = true
  for error in errors {
    if !first {
      text = text + "；"
    }
    first = false
    text = text + error.label()
  }
  text
}

///|
pub fn validation_summary(errors : Array[FormError]) -> String {
  error_labels(errors)
}

///|
/// 项目级完整校验：结构 + 名称 + 事件归属 + 子程序语法。
pub fn validate_project(project : FormProject) -> Array[FormError] {
  let errors : Array[FormError] = []
  let names : Array[String] = []
  for control in project.controls {
    if !control_name_valid(control.name) {
      errors.push(BadName(control.name))
    } else if names.contains(control.name) {
      errors.push(DuplicateName(control.name))
    } else {
      names.push(control.name)
    }
    if control.width <= 0.0 || control.height <= 0.0 {
      errors.push(BadSize(control.name))
    }
  }
  let seen : Array[(String, String)] = []
  for handler in project.handlers {
    match project.find_control_by_name(handler.control) {
      None => errors.push(UnknownHandlerControl(handler.control))
      Some(control) => {
        if !kind_supports_event(control.kind, handler.event) {
          errors.push(UnknownHandlerEvent(handler.control, handler.event))
        }
        let key = (handler.control, handler.event)
        if seen.contains(key) {
          errors.push(DuplicateHandler(handler.control, handler.event))
        } else {
          seen.push(key)
        }
        match check_source(handler.source) {
          Some(error) =>
            errors.push(
              BadSyntax(handler.control, handler.event, error.message()),
            )
          None => ()
        }
      }
    }
  }
  errors
}

///|
/// 首次打开的示例项目：问候应用（输入姓名 → 按钮弹问候）。
pub fn sample_project() -> FormProject {
  {
    name: "问候示例",
    window_title: "我的第一个 Mo易 应用",
    controls: [
      {
        id: 1,
        name: "标题",
        kind: Label,
        x: 40.0,
        y: 32.0,
        width: 280.0,
        height: 36.0,
        text: "欢迎使用 Mo易",
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
