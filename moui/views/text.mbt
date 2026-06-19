///|
pub fn[Msg] text(
  text : String,
  role? : TextRole = TextRole::Body,
  theme? : @core.Theme,
  width? : Double = 160.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let size = @core.Size::new(width~, height~)
  let theme_revision = match theme {
    Some(value) => text_theme_revision(value)
    None => "context"
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Text"),
    revision=() => {
      "text:\{text}:\{size.width}:\{size.height}:\{text_role_revision(role)}:\{theme_revision}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let font = ctx.style.font.unwrap_or(role.font(resolved_theme))
      let color = if ctx.environment.enabled {
        ctx.style.foreground.unwrap_or(role.color(resolved_theme))
      } else {
        ctx.style.foreground
        .unwrap_or(role.color(resolved_theme))
        .multiply_alpha(0.7)
      }
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::DrawText(
          @core.TextRun::new(text~, frame=ctx.frame, font~, color~),
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
fn text_role_revision(role : TextRole) -> String {
  match role {
    Body => "body"
    Title => "title"
    Caption => "caption"
    Control => "control"
    Mono => "mono"
    Display => "display"
    Headline => "headline"
    Subtitle => "subtitle"
    Label => "label"
    Overline => "overline"
  }
}

///|
fn text_theme_revision(theme : @core.Theme) -> String {
  let foreground = theme.palette.foreground
  let muted = theme.palette.muted
  "theme:\{text_scheme_revision(theme.scheme)}:\{foreground.r}:\{foreground.g}:\{foreground.b}:\{foreground.a}:\{muted.r}:\{muted.g}:\{muted.b}:\{muted.a}"
}

///|
fn text_scheme_revision(scheme : @core.ColorScheme) -> String {
  match scheme {
    Light => "light"
    Dark => "dark"
  }
}

///|
pub fn[Msg] text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_submit? : Msg? = None,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  style? : TextFieldStyle,
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => variant.style(theme)
  }
  let normal = resolved_style.normal
  let focused = resolved_style.focused
  controlled_text_field_control(
    value~,
    on_input~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    font=resolved_style.font,
    foreground=normal.foreground,
    placeholder_color=resolved_style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=resolved_style.cursor_color,
    corner_radius=normal.radius,
    on_submit~,
  )
}

///|
pub fn[Msg] text_field_binding(
  value : @core.Binding[String],
  on_submit? : Msg? = None,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  style? : TextFieldStyle,
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => variant.style(theme)
  }
  let normal = resolved_style.normal
  let focused = resolved_style.focused
  text_field_control(
    value~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    font=resolved_style.font,
    foreground=normal.foreground,
    placeholder_color=resolved_style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=resolved_style.cursor_color,
    corner_radius=normal.radius,
    on_submit~,
  )
}

///|
pub fn[Msg] text_area(
  value : String,
  on_input~ : (String) -> Msg,
  placeholder? : String = "",
  lines? : Int = 4,
  variant? : TextFieldVariant = TextFieldVariant::Outline,
  theme? : @core.Theme = default_theme(),
  width? : Double = 320.0,
  line_height? : Double = 28.0,
) -> @core.View[Msg] {
  text_field(
    value,
    on_input~,
    placeholder~,
    variant~,
    theme~,
    width~,
    height=views_max_double(line_height, lines.to_double() * line_height),
  ).accessibility_label("Multiline text area")
}
