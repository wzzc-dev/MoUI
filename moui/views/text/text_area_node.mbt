///|
priv struct TextArea {
  value : String
  placeholder : String
  size : @core.Size
  theme : @core.Theme?
  variant : @style.TextFieldVariant
  style : @style.TextFieldStyle?
  lines : Int
  line_height : Double
  has_on_submit : Bool
  key : String?
}

///|
impl @core.ViewNode for TextArea with fn identity(self) {
  @core.ViewIdentity::new(kind="TextArea", key=self.key)
}

///|
impl @core.ViewNode for TextArea with fn declaration(self) {
  let paint_key = @common.view_record_key("TextArea.paint", [
    ("value", @core.DeclarationKey::string(self.value)),
    ("placeholder", @core.DeclarationKey::string(self.placeholder)),
    (
      "variant",
      @core.DeclarationKey::int(
        match self.variant {
          @style.TextFieldVariant::Filled => 0
          @style.TextFieldVariant::Outline => 1
          @style.TextFieldVariant::Plain => 2
        },
      ),
    ),
    ("lines", @core.DeclarationKey::int(self.lines)),
    ("line_height", @core.DeclarationKey::double(self.line_height)),
  ])
  @common.view_declaration(
    layout=@common.view_exact_channel(@common.view_size_key(self.size)),
    paint=if self.theme is Some(_) || self.style is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      @common.view_exact_channel(paint_key)
    },
    semantics=@common.view_exact_channel(
      @common.view_record_key("TextArea.semantics", [
        ("value", @core.DeclarationKey::string(self.value)),
        ("placeholder", @core.DeclarationKey::string(self.placeholder)),
        ("submit", @core.DeclarationKey::bool(self.has_on_submit)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for TextArea with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(self.size))
}

///|
impl @core.ViewNode for TextArea with fn paint(self, ctx) {
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
    visible_lines=self.lines,
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
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
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
      visible_lines=self.lines,
    ),
  )
}

///|
impl @core.ViewNode for TextArea with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::TextField,
    label=self.placeholder,
    value=self.value,
    read_only=false,
    multiline=true,
    password=false,
    text=@core.SemanticsTextValue::new(editable=true),
  )
}

///|
impl @core.ViewNode for TextArea with fn focusable(_self) {
  true
}
