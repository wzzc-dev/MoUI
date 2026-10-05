///|
/// 预览帧解析(M1-2):harness stdout → 结构化帧。
///
/// 协议:moon run 输出里找哨兵行 `__STUDIO_PREVIEW_V1__`,其后首个
/// 非空行是 JSON 信封(version/width/height/commands/semantics)。
/// commands 逐条重建为 `@core.DrawCommand`(枚举的 ToJson 是**数组
/// 编码** `["Tag", field...]`,此处为其手写逆),语义树保持 JSON 原文
/// (M1-3 的点选层再投影成 typed 节点)。
///
/// 纪律:**未知 op 不静默丢**——记入 `unknown_ops` 由 UI 显式展示,
/// 其余命令照常重放(部分未知不影响已知部分出帧)。
///
/// 解析器风格注记:MoonBit 的 match 臂体是**块或单表达式**——嵌套
/// match 作臂体必须加大括号,否则内层 `{` 会被当作语句块解析
/// (实测:不加括号时内层臂被当成被忽略的表达式语句)。

///|
/// 解析后的预览帧:重放画布按序 push commands;语义树供点选层消费。
pub(all) struct PreviewFrame {
  version : Int
  width : Double
  height : Double
  commands : Array[@core.DrawCommand]
  semantics : Array[Json]
  /// 无法重建的命令 tag(诚实报告)
  unknown_ops : Array[String]
}

///|
/// 数组安全索引(本版本 Array::get 直接返回元素,无 Option)。
fn json_at(items : Array[Json], index : Int) -> Json? {
  if index >= 0 && index < items.length() {
    Some(items[index])
  } else {
    None
  }
}

///|
fn text_to_chars(text : String) -> Array[Char] {
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  chars
}

///|
fn parse_int_text(text : String) -> Int? {
  let chars = text_to_chars(text)
  if chars.length() == 0 {
    return None
  }
  let mut value = 0
  for c in chars {
    let v = c.to_int()
    if v < 48 || v > 57 {
      return None
    }
    value = value * 10 + (v - 48)
  }
  Some(value)
}

///|
/// 从构建输出解析预览帧。无哨兵 / JSON 损坏 → 结构化 Err。
pub fn parse_preview_frame(output : String) -> Result[PreviewFrame, String] {
  // 单遍扫描:哨兵之后的首个非空行 = JSON 信封(split 的视图不可再 drop)
  let mut seen_sentinel = false
  let mut payload_text = ""
  for view in output.split("\n") {
    let line = view.trim(chars=" \t\r")
    if !seen_sentinel {
      if line == @project.PREVIEW_SENTINEL {
        seen_sentinel = true
      }
    } else if line != "" {
      payload_text = view.to_owned()
      break
    }
  }
  if !seen_sentinel {
    return Err(
      "构建输出里没有预览哨兵行(\{@project.PREVIEW_SENTINEL})——预览 harness 可能没有跑起来",
    )
  }
  if payload_text == "" {
    return Err("哨兵行之后没有 JSON 有效载荷")
  }
  let payload = @json.parse(payload_text) catch {
    _ =>
      return Err("预览 JSON 无法解析(版本不匹配或输出被截断)")
  }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err("预览载荷不是 JSON 对象")
  }
  let version = match fields.get("version") {
    Some(String(text)) =>
      match parse_int_text(text) {
        Some(value) => value
        None => return Err("预览版本号不合法:\{text}")
      }
    _ => return Err("预览载荷缺 version 字段")
  }
  if version != @project.PREVIEW_HARNESS_VERSION {
    return Err(
      "预览 harness 版本不匹配:载荷 v\{version},Studio 期望 v\{@project.PREVIEW_HARNESS_VERSION}(重新导入工程即可再生成)",
    )
  }
  let width = match json_number_field(fields, "width") {
    Some(value) => value
    None => return Err("预览载荷缺 width 字段")
  }
  let height = match json_number_field(fields, "height") {
    Some(value) => value
    None => return Err("预览载荷缺 height 字段")
  }
  let command_jsons = match json_array_field(fields, "commands") {
    Some(items) => items
    None => return Err("预览载荷缺 commands 数组")
  }
  let commands : Array[@core.DrawCommand] = []
  let unknown_ops : Array[String] = []
  for item in command_jsons {
    match draw_command_from_json(item) {
      Ok(command) => commands.push(command)
      Err(message) => unknown_ops.push(message)
    }
  }
  let semantics : Array[Json] = match json_array_field(fields, "semantics") {
    Some(items) => items
    None => []
  }
  Ok(PreviewFrame::{ version, width, height, commands, semantics, unknown_ops, })
}

///|
fn json_number_field(fields : Map[String, Json], key : String) -> Double? {
  match fields.get(key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
fn json_string_field(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_array_field(fields : Map[String, Json], key : String) -> Array[Json]? {
  match fields.get(key) {
    Some(Array(items)) => Some(items)
    _ => None
  }
}

///|
/// 枚举标签提取:数组编码 `["Tag", ...]` → (tag, 其余字段);
/// 字符串(无字段变体)→ (tag, [])。
fn json_tag_parts(value : Json) -> (String, Array[Json])? {
  match value {
    Array(items) => {
      let tag = match json_at(items, 0) {
        Some(String(tag)) => tag
        _ => return None
      }
      let rest : Array[Json] = []
      let mut i = 1
      while i < items.length() {
        match json_at(items, i) {
          Some(item) => rest.push(item)
          None => ()
        }
        i = i + 1
      }
      Some((tag, rest))
    }
    String(tag) => Some((tag, []))
    _ => None
  }
}

///|
fn json_as_point(value : Json) -> @geometry.Point? {
  match value {
    Object(fields) => {
      let x = json_number_field(fields, "x")
      let y = json_number_field(fields, "y")
      match (x, y) {
        (Some(x), Some(y)) => Some(@geometry.Point::new(x~, y~))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn json_as_size(value : Json) -> @geometry.Size? {
  match value {
    Object(fields) => {
      let width = json_number_field(fields, "width")
      let height = json_number_field(fields, "height")
      match (width, height) {
        (Some(width), Some(height)) =>
          Some(@geometry.Size::new(width~, height~))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn json_as_rect(value : Json) -> @geometry.Rect? {
  match value {
    Object(fields) => {
      let origin = match fields.get("origin") {
        Some(v) => json_as_point(v)
        None => None
      }
      let size = match fields.get("size") {
        Some(v) => json_as_size(v)
        None => None
      }
      match (origin, size) {
        (Some(origin), Some(size)) =>
          Some(
            @geometry.Rect::new(
              x=origin.x,
              y=origin.y,
              width=size.width,
              height=size.height,
            ),
          )
        _ => None
      }
    }
    _ => None
  }
}

///|
fn json_as_color(value : Json) -> @core.Color? {
  match value {
    Object(fields) => {
      let r = json_number_field(fields, "r")
      let g = json_number_field(fields, "g")
      let b = json_number_field(fields, "b")
      let a = json_number_field(fields, "a")
      match (r, g, b, a) {
        (Some(r), Some(g), Some(b), Some(a)) =>
          Some(@core.Color::{ r, g, b, a, })
        _ => None
      }
    }
    _ => None
  }
}

///|
fn json_as_rounded_rect(value : Json) -> @core.RoundedRect? {
  match value {
    Object(fields) => {
      let rect = match fields.get("rect") {
        Some(v) => json_as_rect(v)
        None => None
      }
      let radius = json_number_field(fields, "radius")
      match (rect, radius) {
        (Some(rect), Some(radius)) =>
          Some(@core.RoundedRect::new(rect~, radius~))
        _ => None
      }
    }
    _ => None
  }
}

///|
/// Brush:数组编码 ["Solid", color] / ["LinearGradient", spec] /
/// ["RadialGradient", spec](spec 形态未实证 → 暂不支持,进 unknown_ops)。
fn json_as_brush(value : Json) -> Result[@core.Brush, String] {
  match value {
    Array(items) => {
      let tag = match json_at(items, 0) {
        Some(String(tag)) => tag
        _ => return Err("brush 不是数组编码")
      }
      match tag {
        "Solid" => {
          let color = match json_at(items, 1) {
            Some(v) => json_as_color(v)
            None => None
          }
          match color {
            Some(color) => Ok(@core.Solid(color))
            None => Err("Solid 颜色不合法")
          }
        }
        "LinearGradient" => {
          let spec = match json_at(items, 1) {
            Some(v) => v
            None => return Err("LinearGradient 缺 spec")
          }
          match spec {
            Object(spec_fields) => {
              let start = match spec_fields.get("start") {
                Some(v) => json_as_point(v)
                None => None
              }
              let end = match spec_fields.get("end") {
                Some(v) => json_as_point(v)
                None => None
              }
              let start_color = match spec_fields.get("start_color") {
                Some(v) => json_as_color(v)
                None => None
              }
              let end_color = match spec_fields.get("end_color") {
                Some(v) => json_as_color(v)
                None => None
              }
              match (start, end, start_color, end_color) {
                (Some(start), Some(end), Some(sc), Some(ec)) =>
                  Ok(
                    @core.LinearGradient(@core.LinearGradientSpec::{
                      start,
                      end,
                      start_color: sc,
                      end_color: ec,
                    }),
                  )
                _ => Err("LinearGradient 字段不完整")
              }
            }
            _ => Err("LinearGradient spec 不是对象")
          }
        }
        other => Err("brush 变体 \{other} 暂不支持")
      }
    }
    _ => Err("brush 不是数组编码")
  }
}

///|
fn font_family_from_tag(tag : String) -> @core.FontFamily {
  match tag {
    "SystemUi" => @core.SystemUi
    "UiSansSerif" => @core.UiSansSerif
    "UiSerif" => @core.UiSerif
    "UiMonospace" => @core.UiMonospace
    "SansSerif" => @core.SansSerif
    "Serif" => @core.Serif
    "Monospace" => @core.Monospace
    other => @core.Name(other)
  }
}

///|
fn json_as_font(value : Json) -> @core.FontSpec? {
  match value {
    Object(fields) => {
      // families: {families: [标签…]} → FontFamily 栈。FontVariation 为
      // 非 pub(all) 类型,重放按空数组(带 variation 的字体渲染可能略异)。
      let families : Array[@core.FontFamily] = match fields.get("families") {
        Some(stack) =>
          match stack {
            Object(stack_fields) => {
              let parsed : Array[@core.FontFamily] = []
              let names = match stack_fields.get("families") {
                Some(Array(names)) => names
                _ => []
              }
              for name in names {
                match name {
                  String(tag) => parsed.push(font_family_from_tag(tag))
                  _ => ()
                }
              }
              parsed
            }
            _ => []
          }
        None => []
      }
      let size = json_number_field(fields, "size").unwrap_or(13.0)
      let weight = match fields.get("weight") {
        Some(Number(n, ..)) => n.to_int()
        _ => 400
      }
      let style = match fields.get("style") {
        Some(String(text)) =>
          if text == "Italic" {
            @core.Italic
          } else {
            @core.Normal
          }
        _ => @core.Normal
      }
      Some(@core.FontSpec::{
        families: { families, },
        size,
        weight,
        style,
        variations: [],
      })
    }
    _ => None
  }
}

///|
fn json_as_text_run(value : Json) -> @core.TextRun? {
  match value {
    Object(fields) => {
      let text = json_string_field(fields, "text")
      let frame = match fields.get("frame") {
        Some(v) => json_as_rect(v)
        None => None
      }
      let font = match fields.get("font") {
        Some(v) => json_as_font(v)
        None => None
      }
      let color = match fields.get("color") {
        Some(v) => json_as_color(v)
        None => None
      }
      let align = match fields.get("align") {
        Some(String(tag)) =>
          match tag {
            "TextStart" => Some(@core.TextStart)
            "TextCenter" => Some(@core.TextCenter)
            "TextEnd" => Some(@core.TextEnd)
            _ => None
          }
        _ => None
      }
      match (text, frame, font, color, align) {
        (Some(text), Some(frame), Some(font), Some(color), Some(align)) =>
          Some(@core.TextRun::new(text~, frame~, font~, color~, align~))
        _ => None
      }
    }
    _ => None
  }
}

///|
/// PathVerb:数组编码 ["MoveTo", point] 等;Close 为裸字符串。
fn json_as_path_verb(value : Json) -> @core.PathVerb? {
  match value {
    Array(items) => {
      let tag = match json_at(items, 0) {
        Some(String(tag)) => tag
        _ => return None
      }
      match tag {
        "MoveTo" => {
          let point = match json_at(items, 1) {
            Some(v) => json_as_point(v)
            None => None
          }
          match point {
            Some(point) => Some(@core.MoveTo(point))
            None => None
          }
        }
        "LineTo" => {
          let point = match json_at(items, 1) {
            Some(v) => json_as_point(v)
            None => None
          }
          match point {
            Some(point) => Some(@core.LineTo(point))
            None => None
          }
        }
        "QuadTo" => {
          let a = match json_at(items, 1) {
            Some(v) => json_as_point(v)
            None => None
          }
          let b = match json_at(items, 2) {
            Some(v) => json_as_point(v)
            None => None
          }
          match (a, b) {
            (Some(a), Some(b)) => Some(@core.QuadTo(a, b))
            _ => None
          }
        }
        "CubicTo" => {
          let a = match json_at(items, 1) {
            Some(v) => json_as_point(v)
            None => None
          }
          let b = match json_at(items, 2) {
            Some(v) => json_as_point(v)
            None => None
          }
          let c = match json_at(items, 3) {
            Some(v) => json_as_point(v)
            None => None
          }
          match (a, b, c) {
            (Some(a), Some(b), Some(c)) => Some(@core.CubicTo(a, b, c))
            _ => None
          }
        }
        "Close" => Some(@core.Close)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn json_as_path_spec(value : Json) -> @core.PathSpec? {
  match value {
    Object(fields) => {
      let verbs : Array[@core.PathVerb] = match fields.get("verbs") {
        Some(Array(items)) => {
          let parsed : Array[@core.PathVerb] = []
          for item in items {
            match json_as_path_verb(item) {
              Some(verb) => parsed.push(verb)
              None => return None
            }
          }
          parsed
        }
        _ => return None
      }
      let fill : @core.Brush? = match fields.get("fill") {
        Some(brush_json) =>
          match json_as_brush(brush_json) {
            Ok(brush) => Some(brush)
            Err(_) => return None
          }
        None => None
      }
      let stroke : @core.Brush? = match fields.get("stroke") {
        Some(brush_json) =>
          match json_as_brush(brush_json) {
            Ok(brush) => Some(brush)
            Err(_) => return None
          }
        None => None
      }
      let stroke_width = json_number_field(fields, "stroke_width")
      Some(
        @core.PathSpec::new(
          verbs~,
          fill~,
          stroke~,
          stroke_width=stroke_width.unwrap_or(1.0),
        ),
      )
    }
    _ => None
  }
}

///|
fn json_as_transform(value : Json) -> @core.Transform2D? {
  match value {
    Object(fields) => {
      let a = json_number_field(fields, "a")
      let b = json_number_field(fields, "b")
      let c = json_number_field(fields, "c")
      let d = json_number_field(fields, "d")
      let tx = json_number_field(fields, "tx")
      let ty = json_number_field(fields, "ty")
      match (a, b, c, d, tx, ty) {
        (Some(a), Some(b), Some(c), Some(d), Some(tx), Some(ty)) =>
          Some(@core.Transform2D::{ a, b, c, d, tx, ty, })
        _ => None
      }
    }
    _ => None
  }
}

///|
fn json_as_shadow(value : Json) -> @core.ShadowSpec? {
  match value {
    Object(fields) => {
      let rect = match fields.get("rect") {
        Some(v) => json_as_rounded_rect(v)
        None => None
      }
      let color = match fields.get("color") {
        Some(v) => json_as_color(v)
        None => None
      }
      let offset = match fields.get("offset") {
        Some(v) => json_as_point(v)
        None => None
      }
      let blur = json_number_field(fields, "blur_radius")
      let spread = json_number_field(fields, "spread")
      match (rect, color, offset, blur, spread) {
        (Some(rect), Some(color), Some(offset), Some(blur), Some(spread)) =>
          Some(@core.ShadowSpec::{
            rect,
            color,
            offset,
            blur_radius: blur,
            spread,
          })
        _ => None
      }
    }
    _ => None
  }
}

///|
fn json_as_image_run(value : Json) -> @core.ImageRun? {
  match value {
    Object(fields) => {
      let source = json_string_field(fields, "source")
      let frame = match fields.get("frame") {
        Some(v) => json_as_rect(v)
        None => None
      }
      let opacity = json_number_field(fields, "opacity")
      let fit : @core.ImageFit? = match fields.get("fit") {
        Some(String(tag)) =>
          match tag {
            "Contain" => Some(@core.Contain)
            "Cover" => Some(@core.Cover)
            "Stretch" => Some(@core.Stretch)
            "ScaleDown" => Some(@core.ScaleDown)
            "FitWidth" => Some(@core.FitWidth)
            "FitHeight" => Some(@core.FitHeight)
            _ => None
          }
        _ => None
      }
      match (source, frame, opacity, fit) {
        (Some(source), Some(frame), Some(opacity), Some(fit)) =>
          Some(@core.ImageRun::{ source, frame, opacity, fit, })
        _ => None
      }
    }
    _ => None
  }
}

///|
/// 单条命令重建:数组编码分派。返回 Err = 该变体暂不支持(进 unknown_ops)。
pub fn draw_command_from_json(
  value : Json,
) -> Result[@core.DrawCommand, String] {
  let (tag, fields) = match json_tag_parts(value) {
    Some(parts) => parts
    None => return Err("命令不是数组编码")
  }
  match tag {
    "Clear" => {
      let color = match json_at(fields, 0) {
        Some(v) => json_as_color(v)
        None => None
      }
      match color {
        Some(color) => Ok(@core.Clear(color))
        None => Err("Clear 缺颜色")
      }
    }
    "FillRect" => {
      let rect = match json_at(fields, 0) {
        Some(v) => json_as_rect(v)
        None => None
      }
      let color = match json_at(fields, 1) {
        Some(v) => json_as_color(v)
        None => None
      }
      match (rect, color) {
        (Some(rect), Some(color)) => Ok(@core.FillRect(rect, color))
        _ => Err("FillRect 字段不合法")
      }
    }
    "StrokeRect" => {
      let rect = match json_at(fields, 0) {
        Some(v) => json_as_rect(v)
        None => None
      }
      let color = match json_at(fields, 1) {
        Some(v) => json_as_color(v)
        None => None
      }
      let width = match json_at(fields, 2) {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      match (rect, color, width) {
        (Some(rect), Some(color), Some(width)) =>
          Ok(@core.StrokeRect(rect, color, width))
        _ => Err("StrokeRect 字段不合法")
      }
    }
    "FillRoundedRect" => {
      let rect = match json_at(fields, 0) {
        Some(v) => json_as_rounded_rect(v)
        None => None
      }
      let color = match json_at(fields, 1) {
        Some(v) => json_as_color(v)
        None => None
      }
      match (rect, color) {
        (Some(rect), Some(color)) => Ok(@core.FillRoundedRect(rect, color))
        _ => Err("FillRoundedRect 字段不合法")
      }
    }
    "StrokeRoundedRect" => {
      let rect = match json_at(fields, 0) {
        Some(v) => json_as_rounded_rect(v)
        None => None
      }
      let color = match json_at(fields, 1) {
        Some(v) => json_as_color(v)
        None => None
      }
      let width = match json_at(fields, 2) {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      match (rect, color, width) {
        (Some(rect), Some(color), Some(width)) =>
          Ok(@core.StrokeRoundedRect(rect, color, width))
        _ => Err("StrokeRoundedRect 字段不合法")
      }
    }
    "FillRoundedRectBrush" => {
      let rect = match json_at(fields, 0) {
        Some(v) => json_as_rounded_rect(v)
        None => None
      }
      let brush = match json_at(fields, 1) {
        Some(v) =>
          match json_as_brush(v) {
            Ok(brush) => Some(brush)
            Err(_) => None
          }
        None => None
      }
      match (rect, brush) {
        (Some(rect), Some(brush)) => Ok(@core.FillRoundedRectBrush(rect, brush))
        _ => Err("FillRoundedRectBrush 字段不合法")
      }
    }
    "StrokeRoundedRectBrush" => {
      let rect = match json_at(fields, 0) {
        Some(v) => json_as_rounded_rect(v)
        None => None
      }
      let brush = match json_at(fields, 1) {
        Some(v) =>
          match json_as_brush(v) {
            Ok(brush) => Some(brush)
            Err(_) => None
          }
        None => None
      }
      let width = match json_at(fields, 2) {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      match (rect, brush, width) {
        (Some(rect), Some(brush), Some(width)) =>
          Ok(@core.StrokeRoundedRectBrush(rect, brush, width))
        _ => Err("StrokeRoundedRectBrush 字段不合法")
      }
    }
    "DrawShadow" => {
      let spec = match json_at(fields, 0) {
        Some(v) => json_as_shadow(v)
        None => None
      }
      match spec {
        Some(spec) => Ok(@core.DrawShadow(spec))
        None => Err("DrawShadow 字段不合法")
      }
    }
    "DrawText" => {
      let run = match json_at(fields, 0) {
        Some(v) => json_as_text_run(v)
        None => None
      }
      match run {
        Some(run) => Ok(@core.DrawText(run))
        None => Err("DrawText 字段不合法")
      }
    }
    "DrawImage" => {
      let image = match json_at(fields, 0) {
        Some(v) => json_as_image_run(v)
        None => None
      }
      match image {
        Some(image) => Ok(@core.DrawImage(image))
        None => Err("DrawImage 字段不合法")
      }
    }
    "PushClip" => {
      let rect = match json_at(fields, 0) {
        Some(v) => json_as_rect(v)
        None => None
      }
      match rect {
        Some(rect) => Ok(@core.PushClip(rect))
        None => Err("PushClip 缺 rect")
      }
    }
    "PopClip" => Ok(@core.PopClip)
    "PushRoundedClip" => {
      let rect = match json_at(fields, 0) {
        Some(v) => json_as_rounded_rect(v)
        None => None
      }
      match rect {
        Some(rect) => Ok(@core.PushRoundedClip(rect))
        None => Err("PushRoundedClip 缺 rect")
      }
    }
    "PopRoundedClip" => Ok(@core.PopRoundedClip)
    "PushTransform" => {
      let transform = match json_at(fields, 0) {
        Some(v) => json_as_transform(v)
        None => None
      }
      match transform {
        Some(transform) => Ok(@core.PushTransform(transform))
        None => Err("PushTransform 字段不合法")
      }
    }
    "PopTransform" => Ok(@core.PopTransform)
    "PushOpacity" => {
      let opacity = match json_at(fields, 0) {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      match opacity {
        Some(opacity) => Ok(@core.PushOpacity(opacity))
        None => Err("PushOpacity 缺值")
      }
    }
    "PopOpacity" => Ok(@core.PopOpacity)
    "PopLayer" => Ok(@core.PopLayer)
    "PopFilter" => Ok(@core.PopFilter)
    "DrawPath" => {
      let spec = match json_at(fields, 0) {
        Some(v) => json_as_path_spec(v)
        None => None
      }
      match spec {
        Some(spec) => Ok(@core.DrawPath(spec))
        None => Err("DrawPath 字段不合法")
      }
    }
    other => Err("\{other}")
  }
}
