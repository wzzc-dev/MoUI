///|
pub fn[Msg] text(
  text : String,
  role? : TextRole = TextRole::Body,
  theme? : @core.Theme = default_theme(),
  width? : Double = 160.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let size = @core.Size::new(width~, height~)
  let font = role.font(theme)
  let color = role.color(theme)
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Text"),
    revision=() => {
      "text:\{text}:\{size.width}:\{size.height}:\{font.size}:\{font.weight}:\{color.r}:\{color.g}:\{color.b}:\{color.a}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
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
