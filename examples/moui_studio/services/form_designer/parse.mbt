///|
/// form.mbt 子集解析器(M4):规范文本 → 模型 + span。
///
/// 只接受**规范形态**(render_form 的输出;手改漂出规范 → 结构化报错并
/// 提示重新保存)——解析器的可靠域与渲染器严格同形,这是往返门能成为
/// 硬门的前提。行内格式:
/// `    place(@views.<kind>("<text>"[, on_click=<ident>]), x=N, y=N, width=N, height=N),`
///
/// 标签定位:四个标签在行内**按顺序**查找(从上一命中末尾起),每个标签
/// 的数字字面量 span 记录到行内下标——补丁按 span 替换,文本其余部分
/// (注释/空白/其他标签)零破坏。

///|
/// 解析 form.mbt 文本 → 模型 + span。结构化错误带行号。
pub fn parse_form(source : String) -> Result[ParsedForm, String] {
  let lines = source.split("\n")
  let mut stage_width = 0.0
  let mut stage_height = 0.0
  let mut stage_seen = false
  let controls : Array[FormControl] = []
  let spans : Array[ControlSpans] = []
  let mut line_no = 0
  let mut line_start = 0
  for view in lines {
    line_no = line_no + 1
    let line = view.trim(chars=" \t\r").to_owned()
    // 行内 span 的绝对起点(含前导缩进);推进必须在 continue 之前
    let line_offset = line_start + (view.length() - line.length())
    let next_start = line_start + view.length() + 1
    if line == "" || line.has_prefix("//") {
      line_start = next_start
      continue
    }
    if !stage_seen && line.has_prefix("stage(") {
      match parse_stage_head(line, line_no) {
        Err(msg) => return Err(msg)
        Ok((w, h)) => {
          stage_width = w
          stage_height = h
          stage_seen = true
        }
      }
      line_start = next_start
      continue
    }
    if line.has_prefix("place(@views.") {
      if !stage_seen {
        return Err("form.mbt:\{line_no}:place 出现在 stage 之前")
      }
      match parse_place_line(line, line_no) {
        Err(msg) => return Err(msg)
        Ok((control, control_spans)) => {
          controls.push(control)
          // 行内 span → 源码绝对 span(补丁按整份源码定位)
          spans.push({
            x: control_spans.x + line_offset,
            y: control_spans.y + line_offset,
            width: control_spans.width + line_offset,
            height: control_spans.height + line_offset,
            text: control_spans.text + line_offset,
          })
        }
      }
      continue
    }
    line_start = line_start + view.length() + 1
  }
  if !stage_seen {
    return Err(
      "form.mbt:没有 stage( 布局头——不是设计器子集文件?",
    )
  }
  Ok(ParsedForm::{
    model: FormModel::{ stage_width, stage_height, controls, },
    spans,
  })
}

///|
fn line_to_chars(text : String) -> Array[Char] {
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  chars
}

///|
fn parse_form_number(text : String) -> Double? {
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  if chars.length() == 0 {
    return None
  }
  let mut value = 0.0
  let mut seen_digit = false
  let mut divisor = 1.0
  let mut in_fraction = false
  for c in chars {
    let v = c.to_int()
    if v >= 48 && v <= 57 {
      value = value * 10.0 + (v - 48).to_double()
      seen_digit = true
      if in_fraction {
        divisor = divisor * 10.0
      }
    } else if c == '.' && !in_fraction && seen_digit {
      in_fraction = true
    } else {
      return None
    }
  }
  if !seen_digit {
    return None
  }
  Some(value / divisor)
}

///|
/// stage(W, H, [) 头解析:两个数字字面量。
fn parse_stage_head(
  line : String,
  line_no : Int,
) -> Result[(Double, Double), String] {
  let chars = line_to_chars(line)
  let n = chars.length()
  let numbers : Array[Double] = []
  let mut i = 6 // "stage(" 之后
  while i < n && numbers.length() < 2 {
    let c = chars[i]
    if (c >= '0' && c <= '9') || c == '.' {
      let mut num = ""
      while i < n && ((chars[i] >= '0' && chars[i] <= '9') || chars[i] == '.') {
        num = num + chars[i].to_string()
        i = i + 1
      }
      match parse_form_number(num) {
        Some(value) => numbers.push(value)
        None => return Err("form.mbt:\{line_no}:stage 数字不合法:\{num}")
      }
    } else {
      i = i + 1
    }
  }
  if numbers.length() < 2 {
    return Err("form.mbt:\{line_no}:stage 缺少宽/高")
  }
  Ok((numbers[0], numbers[1]))
}

///|
priv struct PlaceParse {
  control : FormControl
  spans : ControlSpans
}

///|
/// place 行解析:`place(@views.<kind>("text"[, on_click=id]), x=N, y=N, width=N, height=N),`
fn parse_place_line(
  line : String,
  line_no : Int,
) -> Result[(FormControl, ControlSpans), String] {
  let chars = line_to_chars(line)
  let n = chars.length()
  let ctor = "place(@views."
  let ctor_len = ctor.length()
  if line.length() < ctor_len || line[:ctor_len].to_owned() != ctor {
    return Err("form.mbt:\{line_no}:place 行应以 place(@views. 开头")
  }
  // kind
  let mut i = ctor_len
  let mut kind_tag = ""
  while i < n && chars[i] != '(' {
    kind_tag = kind_tag + chars[i].to_string()
    i = i + 1
  }
  let kind = match form_kind_from_tag(kind_tag) {
    Some(kind) => kind
    None => return Err("form.mbt:\{line_no}:未知控件种类:\{kind_tag}")
  }
  i = i + 1 // 过构造器 '('
  // 字符串字面量(text)
  while i < n && chars[i] == ' ' {
    i = i + 1
  }
  if i >= n || chars[i] != '"' {
    return Err("form.mbt:\{line_no}:控件构造器缺少文本字面量")
  }
  let text_open = i
  let mut text = ""
  i = i + 1
  let mut escaped = false
  let mut text_closed = false
  while i < n {
    let c = chars[i]
    if escaped {
      match c {
        'n' => text = text + "\n"
        't' => text = text + "\t"
        other => text = text + other.to_string()
      }
      escaped = false
    } else if c == '\\' {
      escaped = true
    } else if c == '"' {
      text_closed = true
      break
    } else {
      text = text + c.to_string()
    }
    i = i + 1
  }
  if !text_closed {
    return Err("form.mbt:\{line_no}:文本字面量未闭合")
  }
  let text_span = text_open
  i = i + 1
  // 可选 , on_click=<ident>(到 place 的配平右括号为止)
  let mut handler : String? = None
  let mut depth = 1
  let mut scan = i
  while scan < n && depth > 0 {
    let c = chars[scan]
    if c == '(' {
      depth = depth + 1
    } else if c == ')' {
      depth = depth - 1
    }
    scan = scan + 1
  }
  // 构造器右括号之后、place 右括号之前找 on_click=
  let inner_end = scan - 1
  let mut j = i
  while j < inner_end - 9 {
    if chars[j] == 'o' &&
      chars[j + 1] == 'n' &&
      chars[j + 2] == '_' &&
      chars[j + 3] == 'c' &&
      chars[j + 4] == 'l' &&
      chars[j + 5] == 'i' &&
      chars[j + 6] == 'c' &&
      chars[j + 7] == 'k' &&
      chars[j + 8] == '=' {
      j = j + 9
      let mut ident = ""
      while j < inner_end &&
            chars[j] != ',' &&
            chars[j] != ' ' &&
            chars[j] != ')' {
        ident = ident + chars[j].to_string()
        j = j + 1
      }
      handler = Some(ident)
      break
    }
    j = j + 1
  }
  let _ = text_span
  // 四个标签:x= y= width= height=(顺序查找,从构造器右括号之后)
  let labels : Array[String] = ["x=", "y=", "width=", "height="]
  let values : Array[Double?] = [None, None, None, None]
  let spans : Array[Int] = [-1, -1, -1, -1]
  let mut search_from = inner_end
  let mut li = 0
  for label in labels {
    let lchars = line_to_chars(label)
    let llen = lchars.length()
    let mut j = search_from
    while j <= n - llen {
      let mut matched = true
      for k in 0..<llen {
        if chars[j + k] != lchars[k] {
          matched = false
        }
      }
      if matched {
        let mut k = j + llen
        let mut num = ""
        while k < n && ((chars[k] >= '0' && chars[k] <= '9') || chars[k] == '.') {
          num = num + chars[k].to_string()
          k = k + 1
        }
        match parse_form_number(num) {
          Some(value) => {
            values[li] = Some(value)
            spans[li] = j + llen
          }
          None =>
            return Err("form.mbt:\{line_no}:\{label} 数字不合法:\{num}")
        }
        search_from = k
        break
      }
      j = j + 1
    }
    li = li + 1
  }
  match (values[0], values[1], values[2], values[3]) {
    (Some(x), Some(y), Some(width), Some(height)) =>
      Ok(
        (
          FormControl::{ kind, text, handler, x, y, width, height, },
          ControlSpans::{
            x: spans[0],
            y: spans[1],
            width: spans[2],
            height: spans[3],
            text: text_span,
          },
        ),
      )
    _ => Err("form.mbt:\{line_no}:place 缺少 x/y/width/height 字面量")
  }
}
