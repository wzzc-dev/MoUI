///|
priv struct TextArea {
  value : String
  placeholder : String
  size : @core.Size
  theme : @core.Theme?
  variant : @style.TextFieldVariant
  style : @style.TextFieldStyle?
  lines : Int32
  line_height : Double
  has_on_submit : Bool
  key : String?
}

///|
impl @core.ViewNode for TextArea with fn identity(self) {
  @core.ViewIdentity::new(kind="TextArea", key=self.key)
}

///|
impl @core.ViewNode for TextArea with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(self.size))
}

///|
impl @core.ViewNode for TextArea with fn paint(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
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
    text=self.value,
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
    scroll_offset=text_area_scroll_offset(ctx.state),
    line_height=self.line_height,
  )
  {
    commands,
    child_layers: [],
    post_commands: [],
    overlay_commands,
    repaint_boundary: false,
    animating: false,
  }
}

///|
impl @core.ViewNode for TextArea with fn text_input_state(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => self.variant.style(resolved_theme)
  }
  Some(
    text_input_state_for_multi_line(
      text=self.value,
      frame=ctx.frame,
      font=resolved_style.font,
      control=ctx.text_control,
      text_system=ctx.text_system,
      line_height=self.line_height,
      scroll_offset=text_area_scroll_offset(ctx.state),
    ),
  )
}

///|
impl @core.ViewNode for TextArea with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=Boundary,
    role=TextField,
    label=self.placeholder,
    value=self.value,
    multiline=true,
    text=@core.SemanticsTextValue::new(editable=true),
  )
}

///|
impl @core.ViewNode for TextArea with fn focusable(_self) {
  true
}
