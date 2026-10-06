///|
/// AI 提案契约：模型只产出版本化 JSON 提案（IR 的增删改），
/// 永不直接执行、永不生成任意源码。v1 提案是「全量构建」与
/// 「定点修改」的统一形状：add/update/remove 三态 diff。

///|
pub const PROPOSAL_VERSION : Int = 1

///|
/// 提案：对当前程序的一组受约束修改。summary 双语必填（说清做了什么）。
pub(all) struct ProposalV1 {
  version : Int
  summary_zh : String
  summary_en : String
  window : @ir.WindowSpec?
  controls_add : Array[@ir.Control]
  controls_update : Array[@ir.Control]
  controls_remove : Array[String]
  variables_add : Array[@ir.Variable]
  variables_update : Array[@ir.Variable]
  variables_remove : Array[String]
  handlers_add : Array[@ir.Handler]
  handlers_update : Array[@ir.Handler]
  handlers_remove : Array[HandlerRef]
  open_handler : HandlerRef?
}

///|
/// 子程序定位（控件名 + 事件标签）。
pub(all) struct HandlerRef {
  control : String
  event : String
}

///|
/// 提案错误（界面层本地化）。
pub(all) enum ProposalError {
  InvalidJson
  BadVersion(Int)
  MissingField(String)
  BadControlKind(String)
  BadEventKind(String)
  BadStatement(String)
  BadExpr(String)
  Structural(@ir.IrError)
  LanguageIssue(String)
  Readability(String)
  UnknownControl(String)
  UnknownHandler(String)
  DuplicateHandler(String)
}

///|
fn json_string_field(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_int_field(fields : Map[String, Json], key : String) -> Int? {
  match fields.get(key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
fn decode_control_object(
  value : Json,
  errors : Array[ProposalError],
) -> @ir.Control? {
  match value {
    Object(fields) => {
      let name = match json_string_field(fields, "name") {
        Some(text) => text
        None => {
          errors.push(MissingField("controls.name"))
          return None
        }
      }
      let kind = match json_string_field(fields, "kind") {
        Some(text) =>
          match @ir.parse_control_kind(text) {
            Some(kind) => kind
            None => {
              errors.push(BadControlKind(text))
              return None
            }
          }
        None => {
          errors.push(MissingField("controls.kind"))
          return None
        }
      }
      let items : Array[String] = []
      match fields.get("items") {
        Some(Array(values)) =>
          for item in values {
            match item {
              String(text) => items.push(text)
              _ => ()
            }
          }
        _ => ()
      }
      Some(@ir.Control::{
        id: json_int_field(fields, "id").unwrap_or(0),
        kind,
        name,
        text: json_string_field(fields, "text").unwrap_or(""),
        x: json_int_field(fields, "x").unwrap_or(40),
        y: json_int_field(fields, "y").unwrap_or(40),
        width: json_int_field(fields, "width").unwrap_or(120),
        height: json_int_field(fields, "height").unwrap_or(36),
        items,
      })
    }
    _ => {
      errors.push(MissingField("controls[]"))
      None
    }
  }
}

///|
/// 复用 codec 的语句/表达式解码原语走项目同一条严格路径：
/// 提案里的 body 用与 `.studio.json` 完全相同的语句 JSON。
fn decode_handler_object(
  value : Json,
  errors : Array[ProposalError],
) -> @ir.Handler? {
  let body_fields = match value {
    Object(fields) => fields
    _ => {
      errors.push(MissingField("handlers[]"))
      return None
    }
  }
  let control = match json_string_field(body_fields, "control") {
    Some(text) => text
    None => {
      errors.push(MissingField("handlers.control"))
      return None
    }
  }
  let event = match json_string_field(body_fields, "event") {
    Some(text) =>
      match @ir.parse_event_kind(text) {
        Some(event) => event
        None => {
          errors.push(BadEventKind(text))
          return None
        }
      }
    None => {
      errors.push(MissingField("handlers.event"))
      return None
    }
  }
  let (note_zh, note_en) = match body_fields.get("note") {
    Some(Object(note)) =>
      (
        json_string_field(note, "zh").unwrap_or(""),
        json_string_field(note, "en").unwrap_or(""),
      )
    _ => ("", "")
  }
  // body 经项目编解码器解码：与 .studio.json 同一套严格路径
  let stmts : Array[@ir.Stmt] = []
  match body_fields.get("body") {
    Some(Array(values)) =>
      for value in values {
        match @codec.decode_stmt_value(value) {
          Ok(stmt) => stmts.push(stmt)
          Err(error) => {
            errors.push(map_codec_error(error))
            return None
          }
        }
      }
    _ => {
      errors.push(MissingField("handlers.body"))
      return None
    }
  }
  Some(@ir.Handler::{
    control_name: control,
    event,
    note_zh,
    note_en,
    body: stmts,
  })
}

///|
fn map_codec_error(error : @codec.CodecError) -> ProposalError {
  match error {
    @codec.InvalidJson => InvalidJson
    @codec.BadFormat => MissingField("format")
    @codec.UnsupportedVersion(v) => BadVersion(v)
    @codec.MissingField(field) => MissingField(field)
    @codec.BadControlKind(text) => BadControlKind(text)
    @codec.BadEventKind(text) => BadEventKind(text)
    @codec.BadStatement(text) => BadStatement(text)
    @codec.BadExpr(text) => BadExpr(text)
    @codec.LanguageIssue(name, _) => LanguageIssue(name)
    @codec.Structural(issue) => Structural(issue)
  }
}

///|
fn decode_window(
  value : Json,
  errors : Array[ProposalError],
) -> @ir.WindowSpec? {
  match value {
    Object(fields) =>
      Some(@ir.WindowSpec::{
        title: json_string_field(fields, "title").unwrap_or(
          "MoUI Studio 程序",
        ),
        width: json_int_field(fields, "width").unwrap_or(@ir.DESIGN_WIDTH),
        height: json_int_field(fields, "height").unwrap_or(@ir.DESIGN_HEIGHT),
        timer_interval: 0,
      })
    _ => {
      errors.push(MissingField("window"))
      None
    }
  }
}

///|
fn decode_controls_section(
  fields : Map[String, Json],
  errors : Array[ProposalError],
) -> (Array[@ir.Control], Array[@ir.Control], Array[String]) {
  let add : Array[@ir.Control] = []
  let update : Array[@ir.Control] = []
  let remove : Array[String] = []
  match fields.get("controls") {
    Some(Object(sections)) => {
      match sections.get("add") {
        Some(Array(values)) =>
          for value in values {
            match decode_control_object(value, errors) {
              Some(control) => add.push(control)
              None => ()
            }
          }
        _ => ()
      }
      match sections.get("update") {
        Some(Array(values)) =>
          for value in values {
            match decode_control_object(value, errors) {
              Some(control) => update.push(control)
              None => ()
            }
          }
        _ => ()
      }
      match sections.get("remove") {
        Some(Array(values)) =>
          for value in values {
            match value {
              String(text) => remove.push(text)
              _ => ()
            }
          }
        _ => ()
      }
    }
    _ => ()
  }
  (add, update, remove)
}

///|
/// 解码提案文本：容错 ```json 围栏与前后散文（真实模型常见输出）。
pub fn decode_proposal(
  source : String,
) -> Result[ProposalV1, Array[ProposalError]] {
  let payload = match extract_json_object(source) {
    Some(text) => @json.parse(text) catch { _ => return Err([InvalidJson]) }
    None => return Err([InvalidJson])
  }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err([MissingField("root")])
  }
  let version = match json_int_field(fields, "version") {
    Some(value) => value
    None => return Err([MissingField("version")])
  }
  if version != PROPOSAL_VERSION {
    return Err([BadVersion(version)])
  }
  let (summary_zh, summary_en) = match fields.get("summary") {
    Some(Object(summary)) =>
      (
        json_string_field(summary, "zh").unwrap_or(""),
        json_string_field(summary, "en").unwrap_or(""),
      )
    _ => ("", "")
  }
  let window = match fields.get("window") {
    Some(value) => decode_window(value, [])
    None => None
  }
  let errors : Array[ProposalError] = []
  let (controls_add, controls_update, controls_remove) = decode_controls_section(
    fields, errors,
  )
  let variables_add : Array[@ir.Variable] = []
  let variables_update : Array[@ir.Variable] = []
  let variables_remove : Array[String] = []
  match fields.get("variables") {
    Some(Object(sections)) => {
      decode_variables_section(sections, "add", variables_add, errors)
      decode_variables_section(sections, "update", variables_update, errors)
      match sections.get("remove") {
        Some(Array(values)) =>
          for value in values {
            match value {
              String(text) => variables_remove.push(text)
              _ => ()
            }
          }
        _ => ()
      }
    }
    _ => ()
  }
  let handlers_add : Array[@ir.Handler] = []
  let handlers_update : Array[@ir.Handler] = []
  let handlers_remove : Array[HandlerRef] = []
  match fields.get("handlers") {
    Some(Object(sections)) => {
      decode_handlers_section(sections, "add", handlers_add, errors)
      decode_handlers_section(sections, "update", handlers_update, errors)
      match sections.get("remove") {
        Some(Array(values)) =>
          for value in values {
            match value {
              Object(item) =>
                match json_string_field(item, "control") {
                  Some(control) =>
                    match json_string_field(item, "event") {
                      Some(event) =>
                        handlers_remove.push(HandlerRef::{ control, event, })
                      None => errors.push(MissingField("handlers.remove.event"))
                    }
                  None => errors.push(MissingField("handlers.remove.control"))
                }
              _ => errors.push(MissingField("handlers.remove[]"))
            }
          }
        _ => ()
      }
    }
    _ => ()
  }
  let open_handler = match fields.get("open_handler") {
    Some(Object(item)) =>
      match
        (json_string_field(item, "control"), json_string_field(item, "event")) {
        (Some(control), Some(event)) => Some(HandlerRef::{ control, event, })
        _ => None
      }
    _ => None
  }
  if !errors.is_empty() {
    return Err(errors)
  }
  Ok(ProposalV1::{
    version,
    summary_zh,
    summary_en,
    window,
    controls_add,
    controls_update,
    controls_remove,
    variables_add,
    variables_update,
    variables_remove,
    handlers_add,
    handlers_update,
    handlers_remove,
    open_handler,
  })
}

///|
fn decode_variables_section(
  sections : Map[String, Json],
  key : String,
  out : Array[@ir.Variable],
  errors : Array[ProposalError],
) -> Unit {
  match sections.get(key) {
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(item) =>
            match json_string_field(item, "name") {
              Some(name) =>
                out.push(@ir.Variable::{
                  name,
                  init: json_string_field(item, "init").unwrap_or(""),
                })
              None => errors.push(MissingField("variables.name"))
            }
          _ => errors.push(MissingField("variables[]"))
        }
      }
    _ => ()
  }
}

///|
fn decode_handlers_section(
  sections : Map[String, Json],
  key : String,
  out : Array[@ir.Handler],
  errors : Array[ProposalError],
) -> Unit {
  match sections.get(key) {
    Some(Array(values)) =>
      for value in values {
        match decode_handler_object(value, errors) {
          Some(handler) => out.push(handler)
          None => ()
        }
      }
    _ => ()
  }
}

///|
/// 从模型输出里提取 JSON 对象文本：第一个平衡大括号片段。
/// ```json 围栏与前后散文都会被自然跳过（首个 `{` 之后才开始取）。
pub fn extract_json_object(source : String) -> String? {
  let chars : Array[Char] = []
  for c in source {
    chars.push(c)
  }
  let mut start = -1
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '{' {
      start = i
      break
    }
    i = i + 1
  }
  if start < 0 {
    return None
  }
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  let mut end = -1
  i = start
  while i < chars.length() {
    let c = chars[i]
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
    } else if c == '}' {
      depth = depth - 1
      if depth == 0 {
        end = i + 1
        break
      }
    }
    i = i + 1
  }
  if end < 0 {
    None
  } else {
    let buf = StringBuilder()
    let mut j = start
    while j < end {
      buf.write_char(chars[j])
      j = j + 1
    }
    Some(buf.to_string())
  }
}

///|
/// 提案编码（假模型与测试走同一条路：产出严格 schema JSON）。
pub fn encode_proposal(proposal : ProposalV1) -> String {
  let root : Map[String, Json] = Map([], capacity=6)
  root["version"] = Json::number(proposal.version.to_double())
  let summary : Map[String, Json] = Map([], capacity=2)
  summary["zh"] = Json::string(proposal.summary_zh)
  summary["en"] = Json::string(proposal.summary_en)
  root["summary"] = Json::object(summary)
  match proposal.window {
    Some(window) => {
      let fields : Map[String, Json] = Map([], capacity=3)
      fields["title"] = Json::string(window.title)
      fields["width"] = Json::number(window.width.to_double())
      fields["height"] = Json::number(window.height.to_double())
      root["window"] = Json::object(fields)
    }
    None => ()
  }
  root["controls"] = encode_controls_sections(proposal)
  root["variables"] = encode_variables_sections(proposal)
  root["handlers"] = encode_handlers_sections(proposal)
  match proposal.open_handler {
    Some(reference) => {
      let fields : Map[String, Json] = Map([], capacity=2)
      fields["control"] = Json::string(reference.control)
      fields["event"] = Json::string(reference.event)
      root["open_handler"] = Json::object(fields)
    }
    None => ()
  }
  Json::object(root).stringify()
}

///|
fn encode_controls_sections(proposal : ProposalV1) -> Json {
  let add : Map[String, Json] = Map([], capacity=3)
  add["add"] = Json::array(proposal.controls_add.map(encode_control_json))
  add["update"] = Json::array(proposal.controls_update.map(encode_control_json))
  add["remove"] = Json::array(proposal.controls_remove.map(Json::string))
  Json::object(add)
}

///|
fn encode_variables_sections(proposal : ProposalV1) -> Json {
  let add : Map[String, Json] = Map([], capacity=3)
  add["add"] = Json::array(proposal.variables_add.map(encode_variable_json))
  add["update"] = Json::array(
    proposal.variables_update.map(encode_variable_json),
  )
  add["remove"] = Json::array(proposal.variables_remove.map(Json::string))
  Json::object(add)
}

///|
fn encode_handlers_sections(proposal : ProposalV1) -> Json {
  let add : Map[String, Json] = Map([], capacity=3)
  add["add"] = Json::array(proposal.handlers_add.map(encode_handler_json))
  add["update"] = Json::array(proposal.handlers_update.map(encode_handler_json))
  add["remove"] = Json::array(
    proposal.handlers_remove.map(reference => {
      let fields : Map[String, Json] = Map([], capacity=2)
      fields["control"] = Json::string(reference.control)
      fields["event"] = Json::string(reference.event)
      Json::object(fields)
    }),
  )
  Json::object(add)
}

///|
fn encode_control_json(control : @ir.Control) -> Json {
  let fields : Map[String, Json] = Map([], capacity=9)
  fields["id"] = Json::number(control.id.to_double())
  fields["kind"] = Json::string(control.kind.tag())
  fields["name"] = Json::string(control.name)
  fields["text"] = Json::string(control.text)
  fields["x"] = Json::number(control.x.to_double())
  fields["y"] = Json::number(control.y.to_double())
  fields["width"] = Json::number(control.width.to_double())
  fields["height"] = Json::number(control.height.to_double())
  fields["items"] = Json::array(control.items.map(Json::string))
  Json::object(fields)
}

///|
fn encode_variable_json(variable : @ir.Variable) -> Json {
  let fields : Map[String, Json] = Map([], capacity=2)
  fields["name"] = Json::string(variable.name)
  fields["init"] = Json::string(variable.init)
  Json::object(fields)
}

///|
fn encode_handler_json(handler : @ir.Handler) -> Json {
  let fields : Map[String, Json] = Map([], capacity=4)
  fields["control"] = Json::string(handler.control_name)
  fields["event"] = Json::string(handler.event.tag())
  let note : Map[String, Json] = Map([], capacity=2)
  note["zh"] = Json::string(handler.note_zh)
  note["en"] = Json::string(handler.note_en)
  fields["note"] = Json::object(note)
  fields["body"] = Json::array(handler.body.map(encode_stmt_json))
  Json::object(fields)
}

///|
fn encode_stmt_json(stmt : @ir.Stmt) -> Json {
  match stmt {
    @ir.Declare(name, expr) =>
      stmt_node("declare", [
        ("name", Json::string(name)),
        ("expr", encode_expr_json(expr)),
      ])
    @ir.Assign(name, expr) =>
      stmt_node("assign", [
        ("name", Json::string(name)),
        ("expr", encode_expr_json(expr)),
      ])
    @ir.SetIndex(name, index, value) =>
      stmt_node("set_index", [
        ("name", Json::string(name)),
        ("index", encode_expr_json(index)),
        ("value", encode_expr_json(value)),
      ])
    @ir.Return(expr) =>
      stmt_node(
        "return",
        match expr {
          Some(value) => [("expr", encode_expr_json(value))]
          None => []
        },
      )
    @ir.Break => stmt_node("break", [])
    @ir.Call(name, args) =>
      stmt_node("call", [
        ("name", Json::string(name)),
        ("args", Json::array(args.map(encode_expr_json))),
      ])
    @ir.If(cond, then_body, else_ifs, else_body) =>
      stmt_node("if", [
        ("cond", encode_expr_json(cond)),
        ("then", Json::array(then_body.map(encode_stmt_json))),
        (
          "else_ifs",
          Json::array(
            else_ifs.map(arm => {
              let arm_fields : Map[String, Json] = Map([], capacity=2)
              arm_fields["cond"] = encode_expr_json(arm.0)
              arm_fields["body"] = Json::array(arm.1.map(encode_stmt_json))
              Json::object(arm_fields)
            }),
          ),
        ),
        ("else", Json::array(else_body.map(encode_stmt_json))),
      ])
    @ir.CountLoop(times, loop_var, body) =>
      stmt_node("count_loop", [
        ("times", encode_expr_json(times)),
        (
          "as",
          match loop_var {
            Some(name) => Json::string(name)
            None => Json::null()
          },
        ),
        ("body", Json::array(body.map(encode_stmt_json))),
      ])
    @ir.WhileLoop(cond, body) =>
      stmt_node("while", [
        ("cond", encode_expr_json(cond)),
        ("body", Json::array(body.map(encode_stmt_json))),
      ])
    @ir.Match(subject, arms, else_body) =>
      stmt_node("match", [
        ("subject", encode_expr_json(subject)),
        (
          "arms",
          Json::array(
            arms.map(arm => {
              let arm_fields : Map[String, Json] = Map([], capacity=2)
              arm_fields["case"] = Json::string(arm.case_name)
              arm_fields["body"] = Json::array(arm.body.map(encode_stmt_json))
              Json::object(arm_fields)
            }),
          ),
        ),
        ("else", Json::array(else_body.map(encode_stmt_json))),
      ])
  }
}

///|
fn stmt_node(op : String, extras : Array[(String, Json)]) -> Json {
  let fields : Map[String, Json] = Map([], capacity=6)
  fields["op"] = Json::string(op)
  for pair in extras {
    fields[pair.0] = pair.1
  }
  Json::object(fields)
}

///|
fn encode_expr_json(expr : @ir.Expr) -> Json {
  match expr {
    @ir.NumLit(n) => expr_node("num", [("v", Json::number(n))])
    @ir.IntLit(n) => expr_node("int", [("v", Json::number(n.to_double()))])
    @ir.StrLit(text) => expr_node("str", [("v", Json::string(text))])
    @ir.BoolLit(flag) => expr_node("bool", [("v", Json::boolean(flag))])
    @ir.Var(name) => expr_node("var", [("v", Json::string(name))])
    @ir.ListLit(items) =>
      expr_node("list", [("items", Json::array(items.map(encode_expr_json)))])
    @ir.Index(base, index) =>
      expr_node("index", [
        ("base", encode_expr_json(base)),
        ("at", encode_expr_json(index)),
      ])
    @ir.FieldAccess(base, field) =>
      expr_node("field_access", [
        ("base", encode_expr_json(base)),
        ("field", Json::string(field)),
      ])
    @ir.Not(inner) => expr_node("not", [("e", encode_expr_json(inner))])
    @ir.Neg(inner) => expr_node("neg", [("e", encode_expr_json(inner))])
    @ir.Binary(op, left, right) =>
      expr_node("bin", [
        ("op", Json::string(op.canonical())),
        ("l", encode_expr_json(left)),
        ("r", encode_expr_json(right)),
      ])
    @ir.Call(name, args) =>
      expr_node("call", [
        ("name", Json::string(name)),
        ("args", Json::array(args.map(encode_expr_json))),
      ])
    @ir.EnumTag(enum_name, case_name) =>
      expr_node("enum_tag", [
        ("enum", Json::string(enum_name)),
        ("case", Json::string(case_name)),
      ])
  }
}

///|
fn expr_node(kind : String, extras : Array[(String, Json)]) -> Json {
  let fields : Map[String, Json] = Map([], capacity=5)
  fields["t"] = Json::string(kind)
  for pair in extras {
    fields[pair.0] = pair.1
  }
  Json::object(fields)
}
