///|
/// 拖拽布局设计器的数据面(M4):form.mbt 子集的模型、渲染与解析。
///
/// form.mbt 是**坐标布局子集**的真 MoonBit 源码(代码即真源):
/// ```moonbit
/// pub fn layout() -> @moui.View[Msg] {
///   stage(640.0, 480.0, [
///     place(@views.button("确定", on_click=do_submit), x=280.0, y=180.0, width=80.0, height=36.0),
///   ])
/// }
/// ```
/// 设计器 = 该子集上的结构化编辑器:渲染确定文本 + 每个数字/字符串字面量
/// 的 **span**,拖拽改坐标 = 按 span 补丁源码。往返门(硬):`parse(render(m)) == m`。
///
/// v1 子集边界(诚实):单 stage、place 的字面量参数、控件构造器的首个
/// 字符串字面量(text)与 on_click 标识符;超出子集的构造 → 结构化报错。

///|
/// 控件种类(form.mbt 子集支持的 @views 构造器)。
pub(all) enum FormKind {
  FkText
  FkButton
  FkTextField
  FkCheckBox
  FkImage
}

///|
fn FormKind::tag(self : FormKind) -> String {
  match self {
    FkText => "text"
    FkButton => "button"
    FkTextField => "text_field"
    FkCheckBox => "checkbox"
    FkImage => "image"
  }
}

///|
fn form_kind_from_tag(tag : String) -> FormKind? {
  match tag {
    "text" => Some(FkText)
    "button" => Some(FkButton)
    "text_field" => Some(FkTextField)
    "checkbox" => Some(FkCheckBox)
    "image" => Some(FkImage)
    _ => None
  }
}

///|
/// 一个被放置的控件(选择身份 = 模型数组下标)。
pub(all) struct FormControl {
  kind : FormKind
  /// 控件文本(字符串字面量;image 时为资源路径)
  text : String
  /// 事件处理器名(on_click=<ident>;None = 未绑定)
  handler : String?
  x : Double
  y : Double
  width : Double
  height : Double
  /// 属性 v2(G7.2):默认属性在渲染时整体省略,解析缺省 = 默认
  props : @ir.ControlProps
}

///|
/// 舞台规格 + 控件数组。
pub(all) struct FormModel {
  stage_width : Double
  stage_height : Double
  controls : Array[FormControl]
}

///|
/// 解析产物:模型 + 每个 control 的 **span 组**(源码里数字/字符串字面量
/// 的下标范围,供拖拽补丁精确回写;数组与 model.controls 一一对应)。
pub(all) struct ParsedForm {
  model : FormModel
  spans : Array[ControlSpans]
}

///|
pub(all) struct ControlSpans {
  x : Int
  y : Int
  width : Int
  height : Int
  /// 字符串字面量的 span(**含引号**;无文本控件为 -1)
  text : Int
}

///|
const FORM_HEADER : String = "/// 由 MoUI Studio 设计器维护的布局文件(form.mbt)——重新保存会覆盖手改。\n"

///|
/// 渲染:模型 → form.mbt 规范文本(确定性;同一模型逐字节一致)。
pub fn render_form(model : FormModel) -> String {
  let builder = StringBuilder()
  builder.write_string(FORM_HEADER)
  builder.write_string("pub fn layout() -> @moui.View[Msg] {\n")
  builder.write_string(
    "  stage(\{model.stage_width}, \{model.stage_height}, [\n",
  )
  for control in model.controls {
    builder.write_string("    place(@views.\{control.kind.tag()}(")
    builder.write_string("\"\{escape_form_string(control.text)}\"")
    match control.handler {
      Some(handler) => builder.write_string(", on_click=\{handler}")
      None => ()
    }
    builder.write_string("), ")
    builder.write_string(
      "x=\{control.x}, y=\{control.y}, width=\{control.width}, height=\{control.height}\{render_props(control.props)}),\n",
    )
  }
  builder.write_string("  ])\n}\n")
  builder.to_string()
}

///|
/// 属性 v2(G7.2):非默认属性 → 规范命名参数(默认整体省略,旧文件零变化)。
fn render_props(props : @ir.ControlProps) -> String {
  let out = StringBuilder()
  if props.font_size > 0 {
    out.write_string(", font_size=\{props.font_size}")
  }
  if props.bold {
    out.write_string(", bold=true")
  }
  if props.text_color != "" {
    out.write_string(", text_color=\"\{props.text_color}\"")
  }
  if props.back_color != "" {
    out.write_string(", back_color=\"\{props.back_color}\"")
  }
  if props.align != "" {
    out.write_string(", align=\"\{props.align}\"")
  }
  if !props.visible {
    out.write_string(", visible=false")
  }
  if props.disabled {
    out.write_string(", disabled=true")
  }
  if props.multiline {
    out.write_string(", multiline=true")
  }
  if props.placeholder != "" {
    out.write_string(", placeholder=\"\{escape_form_string(props.placeholder)}\"")
  }
  if props.password {
    out.write_string(", password=true")
  }
  out.to_string()
}

///|
fn escape_form_string(text : String) -> String {
  let mut out = ""
  for c in text {
    if c == '\\' {
      out = out + "\\\\"
    } else if c == '"' {
      out = out + "\\\""
    } else if c == '\n' {
      out = out + "\\n"
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
/// 往返门(硬):parse(render(m)) == m。字段级相等(kind/text/handler/坐标)。
pub fn form_model_eq(a : FormModel, b : FormModel) -> Bool {
  if a.stage_width != b.stage_width || a.stage_height != b.stage_height {
    return false
  }
  if a.controls.length() != b.controls.length() {
    return false
  }
  let mut i = 0
  for control in a.controls {
    let other = b.controls[i]
    if control.kind.tag() != other.kind.tag() ||
      control.text != other.text ||
      control.handler != other.handler ||
      control.x != other.x ||
      control.y != other.y ||
      control.width != other.width ||
      control.height != other.height ||
      control.props != other.props {
      return false
    }
    i = i + 1
  }
  true
}
