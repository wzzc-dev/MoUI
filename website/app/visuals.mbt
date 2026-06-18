///|
fn hero_demo_panel(
  theme : @moui.Theme,
  width : Double,
  height : Double,
  compact : Bool,
  count : Int,
) -> @moui.View[Msg] {
  let padding = if compact { 8.0 } else { 10.0 }
  let gap = if compact { 6.0 } else { 12.0 }
  let inner_width = width - padding * 2.0
  let inner_height = height - padding * 2.0
  let source_width = (inner_width - gap) / 2.0
  let counter_width = inner_width - source_width - gap
  surface(
    row(
      [
        hero_source_panel(theme, source_width, inner_height, compact),
        hero_counter_panel(theme, counter_width, inner_height, compact, count),
      ],
      spacing=gap,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height~,
    background=code_panel_background(theme),
    corner_radius=12.0,
    theme~,
    padding~,
  ).border(accent_border(theme, theme.palette.primary))
}

///|
fn hero_source_panel(
  theme : @moui.Theme,
  width : Double,
  height : Double,
  compact : Bool,
) -> @moui.View[Msg] {
  let header_height = if compact { 34.0 } else { 36.0 }
  surface(
    column(
      [
        hero_demo_header(theme, "Source", "View[Msg]", width, header_height),
        hero_source_code(theme, width, height - header_height, compact),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    background=code_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=0.0,
  ).border(website_border(theme))
}

///|
fn hero_counter_panel(
  theme : @moui.Theme,
  width : Double,
  height : Double,
  compact : Bool,
  count : Int,
) -> @moui.View[Msg] {
  let header_height = if compact { 34.0 } else { 36.0 }
  surface(
    column(
      [
        hero_demo_header(theme, "Counter", "TEA", width, header_height),
        hero_counter_demo(theme, width, height - header_height, compact, count),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    background=hero_counter_background(theme),
    corner_radius=8.0,
    theme~,
    padding=0.0,
  ).border(website_border(theme))
}

///|
fn hero_demo_header(
  theme : @moui.Theme,
  label : String,
  trailing : String,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let label_width = max_website_double(44.0, width - 92.0)
  surface(
    row(
      [
        text(label, width=label_width, height=height - 14.0)
        .font(@core.FontSpec::new(size=13.0, weight=800))
        .foreground(theme.palette.foreground),
        spacer(min_length=0.0, weight=1.0),
        text(trailing, width=64.0, height=height - 14.0)
        .font(code_snippet_font(10.8))
        .foreground(theme.palette.muted),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height~,
    background=hero_demo_header_background(theme),
    corner_radius=0.0,
    theme~,
    padding=7.0,
  )
}

///|
fn hero_source_code(
  theme : @moui.Theme,
  width : Double,
  height : Double,
  compact : Bool,
) -> @moui.View[Msg] {
  let narrow = width < 240.0
  let padding = if narrow { 8.0 } else if compact { 10.0 } else { 18.0 }
  let inner_width = width - padding * 2.0
  let row_gap = if compact || narrow { 0.0 } else { 1.0 }
  let line_height = (height - padding * 2.0 - row_gap * 14.0) / 15.0
  let font_size = if narrow { 4.6 } else if compact { 9.4 } else { 12.2 }
  surface(
    column(
      [
        code_snippet_line(
          theme, "01", "using @views {button, column, text}", inner_width, line_height,
          font_size,
        ),
        code_snippet_line(
          theme, "02", "enum Msg { Inc; Reset }", inner_width, line_height, font_size,
        ),
        code_snippet_line(
          theme, "03", "fn update(count : Int, msg : Msg) -> Int {", inner_width,
          line_height, font_size,
        ),
        code_snippet_line(
          theme, "04", "  match msg {", inner_width, line_height, font_size,
        ),
        code_snippet_line(
          theme, "05", "    Inc => count + 1", inner_width, line_height, font_size,
        ),
        code_snippet_line(
          theme, "06", "    Reset => 0", inner_width, line_height, font_size,
        ),
        code_snippet_line(
          theme, "07", "  }", inner_width, line_height, font_size,
        ),
        code_snippet_line(theme, "08", "}", inner_width, line_height, font_size),
        code_snippet_line(
          theme, "09", "fn view(count : Int) -> @moui.View[Msg] {", inner_width,
          line_height, font_size,
        ),
        code_snippet_line(
          theme, "10", "  column([", inner_width, line_height, font_size,
        ),
        code_snippet_line(
          theme, "11", "    text(\"Count: \\{count}\"),", inner_width, line_height,
          font_size,
        ),
        code_snippet_line(
          theme, "12", "    button(\"+\", on_click=Inc),", inner_width, line_height,
          font_size,
        ),
        code_snippet_line(
          theme, "13", "    button(\"Reset\", on_click=Reset),", inner_width, line_height,
          font_size,
        ),
        code_snippet_line(
          theme, "14", "  ])", inner_width, line_height, font_size,
        ),
        code_snippet_line(theme, "15", "}", inner_width, line_height, font_size),
      ],
      spacing=row_gap,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    background=code_panel_background(theme),
    corner_radius=0.0,
    theme~,
    padding~,
  )
}

///|
fn hero_counter_demo(
  theme : @moui.Theme,
  width : Double,
  height : Double,
  compact : Bool,
  count : Int,
) -> @moui.View[Msg] {
  let narrow = width < 220.0
  let padding = if narrow { 10.0 } else if compact { 16.0 } else { 24.0 }
  let inner_width = width - padding * 2.0
  let button_width = if narrow {
    (inner_width - 6.0) / 2.0
  } else if compact {
    (inner_width - 8.0) / 2.0
  } else {
    118.0
  }
  let value_height = if narrow { 52.0 } else if compact { 58.0 } else { 74.0 }
  let value_font_size = if narrow {
    30.0
  } else if compact {
    34.0
  } else {
    42.0
  }
  surface(
    column(
      [
        spacer(min_length=0.0, weight=1.0),
        text("Live Counter", width=inner_width, height=32.0)
        .font(
          @core.FontSpec::new(size=if narrow { 17.0 } else { 22.0 }, weight=820),
        )
        .foreground(theme.palette.foreground),
        text("Model -> update -> view", width=inner_width, height=24.0)
        .font(
          code_snippet_font(
            if narrow {
              8.2
            } else if compact {
              10.8
            } else {
              12.0
            },
          ),
        )
        .foreground(theme.palette.muted),
        surface(
          text("\{count}", width=inner_width - 28.0, height=value_height - 16.0)
          .font(@core.FontSpec::new(size=value_font_size, weight=860))
          .foreground(theme.palette.primary),
          width=inner_width,
          height=value_height,
          background=theme.palette.surface_variant,
          corner_radius=theme.radius_scale.md,
          theme~,
          padding=8.0,
        ),
        row(
          [
            button(
              "+",
              on_click=CounterIncrement,
              variant=@views.ButtonVariant::Primary,
              theme~,
              width=button_width,
              height=if narrow { 30.0 } else if compact { 34.0 } else { 38.0 },
            ),
            button(
              "Reset",
              on_click=CounterReset,
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=button_width,
              height=if narrow { 30.0 } else if compact { 34.0 } else { 38.0 },
            ),
          ],
          spacing=if narrow { 6.0 } else { 8.0 },
          align=@views.CrossAlign::Center,
        ),
        spacer(min_length=0.0, weight=1.0),
      ],
      spacing=if narrow { 6.0 } else if compact { 8.0 } else { 10.0 },
      align=@views.CrossAlign::Center,
    ),
    width~,
    height~,
    background=hero_counter_background(theme),
    corner_radius=0.0,
    theme~,
    padding~,
  )
}

///|
fn code_snippet_line(
  theme : @moui.Theme,
  line_no : String,
  value : String,
  width : Double,
  height : Double,
  font_size : Double,
) -> @moui.View[Msg] {
  let gutter_width = if font_size < 12.0 { 22.0 } else { 30.0 }
  let font = code_snippet_font(font_size)
  custom_layout(
    measure=constraints => {
      constraints.constrain(@moui.Size::new(width~, height~))
    },
    paint=frame => {
      let commands : Array[@core.DrawCommand] = [
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=line_no,
            frame=@core.Rect::new(
              x=frame.origin.x,
              y=frame.origin.y,
              width=gutter_width,
              height~,
            ),
            font~,
            color=code_snippet_gutter(theme),
            align=@core.TextAlign::TextStart,
          ),
        ),
      ]
      commands.append(
        syntax_highlight_draw_commands(
          theme,
          value,
          @core.Rect::new(
            x=frame.origin.x + gutter_width + 8.0,
            y=frame.origin.y,
            width=width - gutter_width - 8.0,
            height~,
          ),
          font,
          font_size,
        ),
      )
      commands
    },
    semantics_label=value,
  )
}

///|
priv enum SyntaxTone {
  SyntaxPlain
  SyntaxKeyword
  SyntaxType
  SyntaxFunction
  SyntaxString
  SyntaxNumber
  SyntaxOperator
  SyntaxModule
}

///|
priv struct SyntaxSegment {
  value : String
  tone : SyntaxTone
}

///|
fn syntax_highlight_draw_commands(
  theme : @moui.Theme,
  value : String,
  frame : @core.Rect,
  font : @core.FontSpec,
  font_size : Double,
) -> Array[@core.DrawCommand] {
  let segments = moonbit_syntax_segments(value)
  let commands : Array[@core.DrawCommand] = []
  let char_width = font_size * 0.61
  let mut column = 0
  for segment in segments {
    let length = segment.value.to_array().length()
    if length > 0 {
      let x = frame.origin.x + column.to_double() * char_width
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=segment.value,
            frame=@core.Rect::new(
              x~,
              y=frame.origin.y,
              width=max_website_double(
                0.0,
                frame.size.width - (x - frame.origin.x),
              ),
              height=frame.size.height,
            ),
            font~,
            color=syntax_tone_color(theme, segment.tone),
            align=@core.TextAlign::TextStart,
          ),
        ),
      )
      column = column + length
    }
  }
  commands
}

///|
fn moonbit_syntax_segments(value : String) -> Array[SyntaxSegment] {
  let chars = value.to_array()
  let segments : Array[SyntaxSegment] = []
  let mut index = 0
  while index < chars.length() {
    let start = index
    let ch = chars[index]
    if ch.is_ascii_whitespace() {
      while index < chars.length() && chars[index].is_ascii_whitespace() {
        index = index + 1
      }
      syntax_push_segment(segments, chars, start, index, SyntaxPlain)
    } else if ch == '"' {
      index = index + 1
      let mut escaped = false
      while index < chars.length() {
        let current = chars[index]
        index = index + 1
        if current == '"' && !escaped {
          break
        }
        escaped = current == '\\' && !escaped
      }
      syntax_push_segment(segments, chars, start, index, SyntaxString)
    } else if ch == '@' {
      index = index + 1
      while index < chars.length() && syntax_identifier_part(chars[index]) {
        index = index + 1
      }
      syntax_push_segment(segments, chars, start, index, SyntaxModule)
    } else if ch.is_ascii_digit() {
      while index < chars.length() && chars[index].is_ascii_digit() {
        index = index + 1
      }
      syntax_push_segment(segments, chars, start, index, SyntaxNumber)
    } else if syntax_identifier_start(ch) {
      while index < chars.length() && syntax_identifier_part(chars[index]) {
        index = index + 1
      }
      let token = String::from_array(chars[start:index])
      syntax_push_segment(
        segments,
        chars,
        start,
        index,
        moonbit_identifier_tone(token),
      )
    } else {
      index = index + 1
      syntax_push_segment(segments, chars, start, index, SyntaxOperator)
    }
  }
  segments
}

///|
fn syntax_push_segment(
  segments : Array[SyntaxSegment],
  chars : Array[Char],
  start : Int,
  end : Int,
  tone : SyntaxTone,
) -> Unit {
  if end > start {
    segments.push({ value: String::from_array(chars[start:end]), tone })
  }
}

///|
fn syntax_identifier_start(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

///|
fn syntax_identifier_part(ch : Char) -> Bool {
  syntax_identifier_start(ch) || ch.is_ascii_digit()
}

///|
fn moonbit_identifier_tone(token : String) -> SyntaxTone {
  if moonbit_keyword(token) {
    SyntaxKeyword
  } else if moonbit_component(token) {
    SyntaxFunction
  } else if moonbit_type_like(token) {
    SyntaxType
  } else {
    SyntaxPlain
  }
}

///|
fn moonbit_keyword(token : String) -> Bool {
  token == "using" ||
  token == "enum" ||
  token == "fn" ||
  token == "match" ||
  token == "let" ||
  token == "pub" ||
  token == "priv"
}

///|
fn moonbit_component(token : String) -> Bool {
  token == "button" ||
  token == "column" ||
  token == "text" ||
  token == "update" ||
  token == "view"
}

///|
fn moonbit_type_like(token : String) -> Bool {
  let chars = token.to_array()
  token == "Int" ||
  token == "Msg" ||
  token == "View" ||
  token == "Model" ||
  token == "Inc" ||
  token == "Reset" ||
  (chars.length() > 0 && chars[0] >= 'A' && chars[0] <= 'Z')
}

///|
fn code_snippet_font(size : Double) -> @core.FontSpec {
  @core.FontSpec::new(
    size~,
    weight=520,
    families=@core.FontFamilyStack::monospace(),
  )
}

///|
fn code_snippet_foreground(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.86, g=0.93, b=0.90)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.08, g=0.10, b=0.13)
  }
}

///|
fn code_snippet_gutter(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.46, g=0.58, b=0.57)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.42, g=0.48, b=0.52)
  }
}

///|
fn syntax_tone_color(theme : @moui.Theme, tone : SyntaxTone) -> @core.Color {
  match tone {
    SyntaxPlain => code_snippet_foreground(theme)
    SyntaxKeyword => code_syntax_keyword(theme)
    SyntaxType => code_syntax_type(theme)
    SyntaxFunction => code_syntax_function(theme)
    SyntaxString => code_syntax_string(theme)
    SyntaxNumber => code_syntax_number(theme)
    SyntaxOperator => code_syntax_operator(theme)
    SyntaxModule => code_syntax_module(theme)
  }
}

///|
fn code_syntax_keyword(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.56, g=0.75, b=1.0)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.07, g=0.29, b=0.84)
  }
}

///|
fn code_syntax_type(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.90, g=0.66, b=1.0)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.56, g=0.20, b=0.76)
  }
}

///|
fn code_syntax_function(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.36, g=0.87, b=0.68)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.03, g=0.45, b=0.28)
  }
}

///|
fn code_syntax_string(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=1.0, g=0.70, b=0.44)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.72, g=0.30, b=0.02)
  }
}

///|
fn code_syntax_number(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.73, g=0.83, b=1.0)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.18, g=0.39, b=0.78)
  }
}

///|
fn code_syntax_operator(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.70, g=0.76, b=0.78)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.38, g=0.44, b=0.48)
  }
}

///|
fn code_syntax_module(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.53, g=0.87, b=0.92)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.00, g=0.45, b=0.56)
  }
}

///|
fn hero_demo_header_background(theme : @moui.Theme) -> @core.Color {
  code_panel_background(theme)
}

///|
fn hero_counter_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Dark => @core.Color::rgba(r=0.10, g=0.11, b=0.13)
    @moui.ColorScheme::Light => @core.Color::rgba(r=0.98, g=0.99, b=0.98)
  }
}
