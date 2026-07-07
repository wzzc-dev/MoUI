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
        height=chat_message_line_height(line, width),
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
  let size = @geometry.Size::new(width~, height~)
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="ChatMessageText"),
    revision=() => {
      "chat-message-text:\{text}:\{size.width}:\{size.height}:\{chat_message_text_role_revision(role)}:\{theme.revision_fingerprint()}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      let font = chat_message_text_role_font(role, theme)
      let base_color = chat_message_text_role_color(role, theme)
      let color = if ctx.environment.enabled {
        ctx.style.foreground.unwrap_or(base_color)
      } else {
        ctx.style.foreground.unwrap_or(base_color).multiply_alpha(0.7)
      }
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text~,
            frame=ctx.frame,
            font~,
            color~,
            align=@core.TextAlign::TextStart,
          ),
        ),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Text,
        label=text,
        value=text,
      )
    },
  )
}

///|
fn chat_message_text_role_font(
  role : @views.TextRole,
  theme : @moui.Theme,
) -> @core.FontSpec {
  match role {
    @views.TextRole::Body => theme.typography.body
    @views.TextRole::Title => theme.typography.title
    @views.TextRole::Caption => theme.typography.caption
    @views.TextRole::Control => theme.typography.control
    @views.TextRole::Mono =>
      { ..theme.typography.body, families: @core.FontFamilyStack::monospace() }
    @views.TextRole::Display => theme.typography.display
    @views.TextRole::Headline => theme.typography.headline
    @views.TextRole::Subtitle => theme.typography.subtitle
    @views.TextRole::Label => theme.typography.label
    @views.TextRole::Overline => theme.typography.overline
  }
}

///|
fn chat_message_text_role_color(
  role : @views.TextRole,
  theme : @moui.Theme,
) -> @graphics.Color {
  match role {
    @views.TextRole::Caption | @views.TextRole::Overline => theme.palette.muted
    @views.TextRole::Body
    | @views.TextRole::Title
    | @views.TextRole::Control
    | @views.TextRole::Mono
    | @views.TextRole::Display
    | @views.TextRole::Headline
    | @views.TextRole::Subtitle
    | @views.TextRole::Label => theme.palette.foreground
  }
}

///|
fn chat_message_text_role_revision(role : @views.TextRole) -> String {
  match role {
    @views.TextRole::Body => "body"
    @views.TextRole::Title => "title"
    @views.TextRole::Caption => "caption"
    @views.TextRole::Control => "control"
    @views.TextRole::Mono => "mono"
    @views.TextRole::Display => "display"
    @views.TextRole::Headline => "headline"
    @views.TextRole::Subtitle => "subtitle"
    @views.TextRole::Label => "label"
    @views.TextRole::Overline => "overline"
  }
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
