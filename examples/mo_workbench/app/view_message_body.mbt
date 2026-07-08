// Multiline chat body rendering (plain text; preserves newlines and long lines).

///|
fn chat_message_body(
  text_ : String,
  role : @views.TextRole,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let display = if text_.trim().is_empty() { "(empty)" } else { text_ }
  let font_size = chat_message_text_role_font(role, theme).size
  let lines = chat_message_display_lines(display, width, font_size)
  if lines.is_empty() {
    return chat_message_text(
      "(empty)",
      role=@views.TextRole::Caption,
      theme~,
      width~,
    ).foreground(theme.palette.muted)
  }
  let rows : Array[@moui.View[CodeMsg]] = []
  for line in lines {
    rows.push(
      chat_message_text(
        line,
        role~,
        theme~,
        width~,
        height=chat_message_line_height(font_size),
      ),
    )
  }
  @views.column(rows, spacing=4.0, align=@views.CrossAlign::Start)
}

///|
fn chat_message_text(
  text : String,
  role? : @views.TextRole = @views.TextRole::Body,
  theme~ : @moui.Theme,
  width? : Double = 160.0,
  height? : Double = 32.0,
) -> @moui.View[CodeMsg] {
  @views.text(
    text,
    role~,
    theme~,
    width~,
    height~,
    align=@text.TextAlign::TextStart,
  )
}

///|
fn chat_message_text_role_font(
  role : @views.TextRole,
  theme : @moui.Theme,
) -> @text.FontSpec {
  match role {
    @views.TextRole::Body => theme.typography.body
    @views.TextRole::Title => theme.typography.title
    @views.TextRole::Caption => theme.typography.caption
    @views.TextRole::Control => theme.typography.control
    @views.TextRole::Mono =>
      { ..theme.typography.body, families: @text.FontFamilyStack::monospace() }
    @views.TextRole::Display => theme.typography.display
    @views.TextRole::Headline => theme.typography.headline
    @views.TextRole::Subtitle => theme.typography.subtitle
    @views.TextRole::Label => theme.typography.label
    @views.TextRole::Overline => theme.typography.overline
  }
}

///|
fn chat_message_display_lines(
  text_ : String,
  width : Double,
  font_size : Double,
) -> Array[String] {
  let max_width = width.max(chat_message_min_line_width(font_size))
  let out : Array[String] = []
  for raw in text_.split("\n") {
    let line = raw.to_owned()
    if line.is_empty() {
      out.push("")
    } else {
      let chars = line.to_array()
      let chunk = StringBuilder::new()
      let mut used_width = 0.0
      for c in chars {
        let advance = chat_message_char_advance(c, font_size)
        if !chunk.is_empty() && used_width + advance > max_width {
          out.push(chunk.to_string())
          chunk.reset()
          used_width = 0.0
        }
        chunk.write_char(c)
        used_width = used_width + advance
      }
      if !chunk.is_empty() {
        out.push(chunk.to_string())
      }
    }
  }
  out
}

///|
fn chat_message_min_line_width(font_size : Double) -> Double {
  (font_size * 4.0).max(48.0)
}

///|
fn chat_message_char_advance(ch : Char, font_size : Double) -> Double {
  let scale = (font_size / 14.0).max(0.75)
  if ch == '\t' {
    16.0 * scale
  } else if ch.is_ascii_whitespace() {
    4.0 * scale
  } else if ch.is_ascii() {
    7.4 * scale
  } else {
    font_size
  }
}

///|
fn chat_message_line_height(font_size : Double) -> Double {
  (font_size + 7.0).max(20.0)
}
