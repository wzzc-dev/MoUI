// Multiline chat body rendering (plain text; preserves newlines and long lines).

///|
fn chat_message_body(
  text_ : String,
  role : @views.TextRole,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let display = if text_.trim().is_empty() { "(empty)" } else { text_ }
  let lines = chat_message_display_lines(display, width)
  if lines.is_empty() {
    return @views.text("(empty)", role=@views.TextRole::Caption, theme~, width~).foreground(
      theme.palette.muted,
    )
  }
  let rows : Array[@moui.View[CodeMsg]] = []
  for line in lines {
    rows.push(
      @views.text(
        line,
        role~,
        theme~,
        width~,
        height=chat_message_line_height(line, width),
      ),
    )
  }
  @views.column(rows, spacing=4.0, align=@views.CrossAlign::Start)
}

///|
fn chat_message_display_lines(text_ : String, width : Double) -> Array[String] {
  let max_chars = chat_message_chars_per_line(width)
  let out : Array[String] = []
  for raw in text_.split("\n") {
    let line = raw.to_owned()
    if line.is_empty() {
      out.push("")
    } else if line.length() <= max_chars {
      out.push(line)
    } else {
      let chars = line.to_array()
      let mut i = 0
      while i < chars.length() {
        let end = (i + max_chars).min(chars.length())
        let chunk = StringBuilder::new()
        for c in chars[i:end] {
          chunk.write_char(c)
        }
        out.push(chunk.to_string())
        i = end
      }
    }
  }
  out
}

///|
fn chat_message_chars_per_line(width : Double) -> Int {
  let chars = (width / 8.0).to_int()
  if chars < 24 {
    24
  } else if chars > 120 {
    120
  } else {
    chars
  }
}

///|
fn chat_message_line_height(line : String, width : Double) -> Double {
  let max_chars = chat_message_chars_per_line(width)
  let chars = line.length()
  if chars == 0 {
    22.0
  } else {
    let lines = (chars + max_chars - 1) / max_chars
    (lines.to_double() * 22.0).max(22.0)
  }
}
