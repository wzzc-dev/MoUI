///|
fn quick_start_header(
  theme : @moui.Theme,
  width : Double,
  locale : String,
) -> @moui.View[Msg] {
  let message = key => website_message(locale, key)
  column(
    [
      text(message("quick.title"), width~, height=44.0)
      .font(@text.FontSpec::new(size=34.0, weight=820))
      .foreground(theme.palette.foreground),
      text(message("quick.summary"), width~, height=28.0)
      .font(@text.FontSpec::new(size=15.0, weight=480))
      .foreground(theme.palette.muted),
    ],
    spacing=10.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn Model::quick_start_steps(
  self : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let steps = [
    (
      "1",
      website_message(self.locale, "quick.install"),
      ["moon install wzzc-dev/moui_cli/cmd/moui"],
    ),
    (
      "2",
      website_message(self.locale, "quick.create"),
      ["moui new my_app", "cd my_app", "moon update", "moon check"],
    ),
    (
      "3",
      website_message(self.locale, "quick.run"),
      ["moon run macos_skia --target native"],
    ),
  ]
  let rows : Array[@moui.View[Msg]] = []
  let last = steps.length() - 1
  for index = 0; index < steps.length(); index = index + 1 {
    let (number, title, lines) = steps[index]
    rows.push(
      self.quick_start_step(
        theme,
        width,
        number,
        title,
        lines,
        show_connector=index < last,
      ),
    )
  }
  column(rows, spacing=18.0, align=@views.CrossAlign::Start)
}

///|
fn Model::quick_start_step(
  self : Model,
  theme : @moui.Theme,
  width : Double,
  number : String,
  title : String,
  lines : Array[String],
  show_connector~ : Bool,
) -> @moui.View[Msg] {
  let badge_size = 30.0
  let rail_width = 36.0
  let content_width = max_website_double(180.0, width - rail_width - 12.0)
  let rail_children : Array[@moui.View[Msg]] = [
    quick_start_step_badge(
      theme,
      number,
      badge_size,
      website_message_with(self.locale, "step.label", [("number", number)]),
    ),
  ]
  if show_connector {
    rail_children.push(
      container(
        spacer(min_length=0.0, weight=1.0),
        width=2.0,
        height=if lines.length() > 1 { 118.0 } else { 54.0 },
        background=theme.palette.outline.multiply_alpha(0.35),
        corner_radius=1.0,
        theme~,
        padding=0.0,
      ),
    )
  }
  row(
    [
      column(rail_children, spacing=8.0, align=@views.CrossAlign::Center).frame(
        width=rail_width,
      ),
      column(
        [
          text(
            title,
            width=content_width,
            height=28.0,
            align=@text.TextAlign::TextStart,
          )
          .font(@text.FontSpec::new(size=17.0, weight=700))
          .foreground(theme.palette.foreground),
          self.quick_start_code_block(theme, content_width, lines),
        ],
        spacing=10.0,
        align=@views.CrossAlign::Start,
      ),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn quick_start_step_badge(
  theme : @moui.Theme,
  number : String,
  size : Double,
  semantics_label : String,
) -> @moui.View[Msg] {
  let fill = website_green(theme)
  let font = @text.FontSpec::new(size=13.0, weight=780)
  custom_layout(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width=size, height=size))
    },
    paint=(ctx, frame) => {
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=frame, radius=size / 2.0),
        @graphics.Brush::solid(fill),
      )
      draw_text(
        ctx,
        @text.TextRun::new(
          text=number,
          frame~,
          font~,
          color=@graphics.Color::white(),
          align=@text.TextAlign::TextCenter,
        ),
      )
    },
    semantics_label~,
  )
}

///|
fn Model::quick_start_code_block(
  self : Model,
  theme : @moui.Theme,
  width : Double,
  lines : Array[String],
) -> @moui.View[Msg] {
  let pad = 14.0
  let gap = 12.0
  let copy_height = 30.0
  let line_height = 22.0
  let line_gap = 4.0
  let font_size = if width < 360.0 { 12.0 } else { 13.5 }
  let mono_font = @text.FontSpec::new(
    size=font_size,
    weight=560,
    families=@text.FontFamilyStack::monospace(),
  )
  let copy_text = quick_start_join_lines(lines)
  let copied = match self.copied_text {
    Some(value) => value == copy_text
    None => false
  }
  let copy_width = if copied { 70.0 } else { 58.0 }
  let code_width = max_website_double(
    96.0,
    width - pad * 2.0 - copy_width - gap,
  )
  let line_views : Array[@moui.View[Msg]] = []
  for line in lines {
    line_views.push(
      text(
        line,
        width=code_width,
        height=line_height,
        align=@text.TextAlign::TextStart,
      )
      .font(mono_font)
      .foreground(quick_start_code_foreground(theme)),
    )
  }
  let code_height = if lines.length() <= 0 {
    line_height
  } else {
    lines.length().to_double() * line_height +
    (lines.length() - 1).to_double() * line_gap
  }
  let content_height = max_website_double(code_height, copy_height)
  container(
    row(
      [
        column(line_views, spacing=line_gap, align=@views.CrossAlign::Start).frame(
          width=code_width,
          height=code_height,
        ),
        button(
          if copied {
            website_message(self.locale, "action.copied")
          } else {
            website_message(self.locale, "action.copy")
          },
          on_click=CopyText(copy_text),
          style=quick_start_copy_button_style(theme, copied),
          theme~,
          width=if copied { 70.0 } else { copy_width },
          height=copy_height,
        ),
      ],
      spacing=gap,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=content_height + pad * 2.0,
    background=quick_start_code_background(theme),
    corner_radius=12.0,
    theme~,
    padding=pad,
  )
}

///|
fn quick_start_copy_button_style(
  theme : @moui.Theme,
  copied : Bool,
) -> @views.ButtonStyle {
  ignore(theme)
  let label = if copied {
    @graphics.Color::rgba(r=0.05, g=0.12, b=0.11)
  } else {
    @graphics.Color::rgba(r=0.78, g=0.98, b=0.92)
  }
  let fill = if copied {
    @graphics.Color::rgba(r=0.45, g=0.92, b=0.82)
  } else {
    @graphics.Color::rgba(r=0.12, g=0.20, b=0.19)
  }
  let hover_fill = if copied {
    @graphics.Color::rgba(r=0.55, g=0.95, b=0.86)
  } else {
    @graphics.Color::rgba(r=0.16, g=0.26, b=0.24)
  }
  let press_fill = if copied {
    @graphics.Color::rgba(r=0.38, g=0.84, b=0.74)
  } else {
    @graphics.Color::rgba(r=0.10, g=0.17, b=0.16)
  }
  let border = @graphics.Color::rgba(r=0.45, g=0.92, b=0.82)
  let radius = 8.0
  let normal = @views.new_control_state_style(
    foreground=label,
    background=@graphics.Brush::solid(fill),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border),
      width=1.0,
    ),
    radius~,
  )
  let hovered = @views.new_control_state_style(
    foreground=label,
    background=@graphics.Brush::solid(hover_fill),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border),
      width=1.0,
    ),
    radius~,
  )
  let pressed = @views.new_control_state_style(
    foreground=label,
    background=@graphics.Brush::solid(press_fill),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border),
      width=1.0,
    ),
    radius~,
  )
  let disabled = @views.new_control_state_style(
    foreground=@graphics.Color::rgba(r=0.55, g=0.62, b=0.60),
    background=@graphics.Brush::solid(
      @graphics.Color::rgba(r=0.10, g=0.14, b=0.13),
    ),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(
        @graphics.Color::rgba(r=0.30, g=0.38, b=0.36),
      ),
      width=1.0,
    ),
    radius~,
  )
  @views.ButtonStyle::new(normal~, hovered~, pressed~, disabled~)
}

///|
fn quick_start_actions(theme : @moui.Theme, locale : String) -> @moui.View[Msg] {
  row(
    [
      button(
        website_message(locale, "action.read_docs"),
        on_click=OpenDocs,
        variant=@views.ButtonVariant::Primary,
        theme~,
        width=148.0,
        height=42.0,
      ),
      button(
        website_message(locale, "action.open_playground"),
        on_click=OpenPlayground,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=156.0,
        height=42.0,
      ).foreground(theme.palette.foreground),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn quick_start_join_lines(lines : Array[String]) -> String {
  let mut joined = ""
  for index = 0; index < lines.length(); index = index + 1 {
    if index > 0 {
      joined = "\{joined}\n"
    }
    joined = "\{joined}\{lines[index]}"
  }
  joined
}

///|
fn quick_start_code_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.05, g=0.09, b=0.09)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.07, g=0.12, b=0.11)
  }
}

///|
fn quick_start_code_foreground(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    @state.ColorScheme::Dark => @graphics.Color::rgba(r=0.55, g=0.95, b=0.86)
    @state.ColorScheme::Light => @graphics.Color::rgba(r=0.45, g=0.92, b=0.82)
  }
}
