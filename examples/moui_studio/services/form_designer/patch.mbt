///|
/// span 补丁回写(M4):拖拽改坐标 = 按 parse 记录的 span 替换数字字面量;
/// 文本编辑 = 替换字符串字面量 span(含引号,转义由调用方传入转义文本)。
/// 其余源码零破坏(注释/空白/其他控件)。

///|
/// 数字字面量补丁:把 source 中 [start, end) 替换为 formatted。
pub fn apply_number_patch(
  source : String,
  start : Int,
  end : Int,
  formatted : String,
) -> String {
  if start < 0 || end > source.length() || start > end {
    return source
  }
  source[:start].to_owned() + formatted + source[end:].to_owned()
}

///|
/// 组装设计器拖拽后的补丁链:先改 model,再按 spans 逐字段补丁源码。
/// 字段格式:`88.0`(Double::to_string 口径,与解析器互认)。
pub fn apply_control_patch(
  source : String,
  spans : ControlSpans,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> String {
  // 从后往前替换:前面的 span 不因前面补丁而漂移
  let patched = apply_number_patch(
    source,
    spans.height,
    spans.height + number_len(source, spans.height),
    double_literal(height),
  )
  let patched = apply_number_patch(
    patched,
    spans.width,
    spans.width + number_len(patched, spans.width),
    double_literal(width),
  )
  let patched = apply_number_patch(
    patched,
    spans.y,
    spans.y + number_len(patched, spans.y),
    double_literal(y),
  )
  apply_number_patch(
    patched,
    spans.x,
    spans.x + number_len(patched, spans.x),
    double_literal(x),
  )
}

///|
/// 文本字面量补丁:span 含引号,替换为 `"escaped"`。
pub fn apply_text_patch(
  source : String,
  text_span : Int,
  text_len : Int,
  new_text : String,
) -> String {
  if text_span < 0 || text_len <= 0 {
    return source
  }
  // span 含引号:替换文本 = 转义后的新文本 + 成对引号
  apply_number_patch(
    source,
    text_span,
    text_span + text_len,
    "\"" + escape_form_string(new_text) + "\"",
  )
}

///|
/// span 起点处数字字面量的长度(到非数字字符止)。
pub fn number_len(source : String, start : Int) -> Int {
  let chars : Array[Char] = []
  for c in source {
    chars.push(c)
  }
  let mut len = 0
  let mut i = start
  let n = chars.length()
  while i < n && ((chars[i] >= '0' && chars[i] <= '9') || chars[i] == '.') {
    len = len + 1
    i = i + 1
  }
  len
}

///|
/// Double → 字面量文本(解析器可读;不丢小数部分)。
pub fn double_literal(value : Double) -> String {
  let text = value.to_string()
  if text.contains(".") {
    text
  } else {
    text + ".0"
  }
}
