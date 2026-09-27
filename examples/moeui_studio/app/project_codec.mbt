///|
/// `.moeui.json` 项目编解码：format 门卫 + 严格字段检查 + 完整校验。
/// 与 AI 提案（decode_proposal）共用控件/子程序解码逻辑。

///|
let format_id : String = "moeui.project"

///|
let format_version : Double = 1.0

///|
fn json_string_field(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_number_field(fields : Map[String, Json], key : String) -> Double? {
  match fields.get(key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
fn kind_json(kind : ControlKind) -> String {
  match kind {
    Button => "Button"
    Label => "Label"
    TextField => "TextField"
  }
}

///|
fn encode_control(control : FormControl) -> Json {
  let fields : Map[String, Json] = Map([], capacity=8)
  fields["id"] = Json::number(control.id.to_double())
  fields["name"] = Json::string(control.name)
  fields["kind"] = Json::string(kind_json(control.kind))
  fields["x"] = Json::number(control.x)
  fields["y"] = Json::number(control.y)
  fields["width"] = Json::number(control.width)
  fields["height"] = Json::number(control.height)
  fields["text"] = Json::string(control.text)
  Json::object(fields)
}

///|
fn encode_handler(handler : EventHandler) -> Json {
  let fields : Map[String, Json] = Map([], capacity=4)
  fields["control"] = Json::string(handler.control)
  fields["event"] = Json::string(handler.event)
  fields["source"] = Json::string(handler.source)
  Json::object(fields)
}

///|
/// 项目 → JSON 文本（保存到磁盘的格式）。
pub fn encode_project(project : FormProject) -> String {
  let root : Map[String, Json] = Map([], capacity=8)
  root["format"] = Json::string(format_id)
  root["version"] = Json::number(format_version)
  let metadata : Map[String, Json] = Map([], capacity=2)
  metadata["name"] = Json::string(project.name)
  root["metadata"] = Json::object(metadata)
  let window : Map[String, Json] = Map([], capacity=2)
  window["title"] = Json::string(project.window_title)
  root["window"] = Json::object(window)
  root["controls"] = Json::array(project.controls.map(encode_control))
  root["handlers"] = Json::array(project.handlers.map(encode_handler))
  root["next_id"] = Json::number(project.next_id.to_double())
  Json::object(root).stringify()
}

///|
/// 控件数组与子程序数组的公共解码（项目文件与 AI 提案共用）。
/// 返回 errors 非空即失败；controls/handlers 在失败时也是部分可用，
/// 调用方必须以 errors 为准。
fn decode_controls_and_handlers(
  fields : Map[String, Json],
  errors : Array[FormError],
) -> (Array[FormControl], Array[EventHandler], Int) {
  let controls : Array[FormControl] = []
  match fields.get("controls") {
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(item) => {
            let id = match json_number_field(item, "id") {
              Some(n) => n.to_int()
              None => {
                errors.push(InvalidProject("控件缺少数字 id"))
                continue
              }
            }
            let name = match json_string_field(item, "name") {
              Some(text) => text
              None => {
                errors.push(InvalidProject("控件缺少 name"))
                continue
              }
            }
            let kind = match json_string_field(item, "kind") {
              Some(text) =>
                match parse_control_kind(text) {
                  Some(kind) => kind
                  None => {
                    errors.push(UnknownKind(text))
                    continue
                  }
                }
              None => {
                errors.push(InvalidProject("控件缺少 kind"))
                continue
              }
            }
            let x = json_number_field(item, "x").unwrap_or(40.0)
            let y = json_number_field(item, "y").unwrap_or(40.0)
            let width = json_number_field(item, "width").unwrap_or(120.0)
            let height = json_number_field(item, "height").unwrap_or(36.0)
            let text = json_string_field(item, "text").unwrap_or("")
            controls.push({ id, name, kind, x, y, width, height, text, })
          }
          _ => errors.push(InvalidProject("controls 项必须是对象"))
        }
      }
    _ => errors.push(InvalidProject("缺少 controls 数组"))
  }
  let handlers : Array[EventHandler] = []
  match fields.get("handlers") {
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(item) => {
            let control = match json_string_field(item, "control") {
              Some(text) => text
              None => {
                errors.push(InvalidProject("子程序缺少 control"))
                continue
              }
            }
            let event = match json_string_field(item, "event") {
              Some(text) => text
              None => {
                errors.push(InvalidProject("子程序缺少 event"))
                continue
              }
            }
            let source = match json_string_field(item, "source") {
              Some(text) => text
              None => {
                errors.push(InvalidProject("子程序缺少 source"))
                continue
              }
            }
            handlers.push({ control, event, source, })
          }
          _ => errors.push(InvalidProject("handlers 项必须是对象"))
        }
      }
    _ => errors.push(InvalidProject("缺少 handlers 数组"))
  }
  let next_id = match json_number_field(fields, "next_id") {
    Some(n) if n.to_int() > 0 => n.to_int()
    _ => {
      let mut max_id = 0
      for control in controls {
        if control.id > max_id {
          max_id = control.id
        }
      }
      max_id + 1
    }
  }
  (controls, handlers, next_id)
}

///|
/// 解码 `.moeui.json` 项目文本：结构检查 + 完整项目校验。
pub fn decode_project(source : String) -> Result[FormProject, Array[FormError]] {
  let payload = @json.parse(source) catch { _ => return Err([InvalidJson]) }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err([BadFormat])
  }
  match json_string_field(fields, "format") {
    Some(text) => if text != format_id { return Err([BadFormat]) }
    None => return Err([BadFormat])
  }
  match json_number_field(fields, "version") {
    Some(n) => if n != format_version { return Err([UnsupportedVersion]) }
    None => return Err([UnsupportedVersion])
  }
  let name = match fields.get("metadata") {
    Some(Object(metadata)) => json_string_field(metadata, "name")
    _ => None
  }
  let name = name.unwrap_or("未命名项目")
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
    name,
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
