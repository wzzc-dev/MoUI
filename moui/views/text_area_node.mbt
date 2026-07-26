///|
priv struct TextAreaViewNode {
  value : @core.Binding[String]
  placeholder : String
  size : @core.Size
  theme : @core.Theme?
  variant : TextFieldVariant
  style : TextFieldStyle?
  lines : Int
  line_height : Double
  theme_revision : String
  variant_label : String
  key : String?
}

///|
impl @core.ViewNode for TextAreaViewNode with fn identity(self) {
  @core.ViewIdentity::new(kind="TextArea", key=self.key)
}

///|
impl @core.ViewNode for TextAreaViewNode with fn revision(self) {
  "textarea:\{self.value.get()}:\{self.placeholder}:\{view_size_revision(self.size)}:\{self.variant_label}:\{self.theme_revision}:\{self.lines}:\{self.line_height}"
}

///|
impl @core.ViewNode for TextAreaViewNode with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(self.size))
}

///|
impl @core.ViewNode for TextAreaViewNode with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => self.variant.style(resolved_theme)
  }
  let normal = resolved_style.normal
  let focused = resolved_style.focused
  let commands : Array[@core.DrawCommand] = []
  let overlay_commands : Array[@core.DrawCommand] = []
  append_text_area_commands(
    commands,
    overlay_commands,
    text=self.value.get(),
    placeholder=self.placeholder,
    font=resolved_style.font,
    foreground=normal.foreground,
    placeholder_color=resolved_style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=resolved_style.cursor_color,
    corner_radius=normal.radius,
    frame=ctx.frame,
    focused=ctx.focused,
    control=ctx.text_control,
    text_system=ctx.text_system,
    theme=resolved_theme,
    visible_lines=self.lines,
    line_height=self.line_height,
  )
  {
    commands,
    child_layers: [],
    post_commands: [],
    overlay_commands,
    platform_views: [],
    repaint_boundary: false,
    animating: false,
  }
}

///|
impl @core.ViewNode for TextAreaViewNode with fn text_input_state(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => self.variant.style(resolved_theme)
  }
  Some(
    text_input_state_for_multi_line(
      text=self.value.get(),
      frame=ctx.frame,
      font=resolved_style.font,
      control=ctx.text_control,
      text_system=ctx.text_system,
      line_height=self.line_height,
      visible_lines=self.lines,
    ),
  )
}

///|
impl @core.ViewNode for TextAreaViewNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::TextField,
    label=self.placeholder,
    value=self.value.get(),
    actions=[@core.SemanticsAction::Focus, @core.SemanticsAction::SetText],
  )
}

///|
impl @core.ViewNode for TextAreaViewNode with fn focusable(_self) {
  true
}
