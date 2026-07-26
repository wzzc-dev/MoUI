///|
priv struct SingleLineTextInput {
  value : @core.Binding[String]
  placeholder : String
  size : @core.Size
  theme : @core.Theme?
  variant : TextFieldVariant
  style : TextFieldStyle?
  search_bar : Bool
  theme_revision : String
  variant_label : String
  has_on_submit : Bool
  has_on_clear : Bool
  kind : String
  key : String?
}

///|
impl @core.ViewNode for SingleLineTextInput with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for SingleLineTextInput with fn revision(self) {
  if self.search_bar {
    "searchbar:\{self.value.get()}:\{self.placeholder}:\{self.variant_label}:\{self.theme_revision}:\{self.has_on_submit}:\{self.has_on_clear}"
  } else {
    "textfield:\{self.value.get()}:\{self.placeholder}:\{view_size_revision(self.size)}:\{self.variant_label}:\{self.theme_revision}:\{self.has_on_submit}"
  }
}

///|
impl @core.ViewNode for SingleLineTextInput with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(self.size))
}

///|
impl @core.ViewNode for SingleLineTextInput with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => self.variant.style(resolved_theme)
  }
  let normal = resolved_style.normal
  let focused = resolved_style.focused
  let commands : Array[@core.DrawCommand] = []
  let overlay_commands : Array[@core.DrawCommand] = []
  if self.search_bar {
    append_searchbar_commands(
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
    )
  } else {
    append_text_field_commands(
      commands,
      overlay_commands,
      text=self.value.get(),
      placeholder=self.placeholder,
      size=self.size,
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
      bottom_border_only=normal.bottom_border_only,
      inner_focus_border=if ctx.focused {
        focused.inner_focus_border
      } else {
        None
      },
    )
  }
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
impl @core.ViewNode for SingleLineTextInput with fn text_input_state(
  self,
  ctx,
) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => self.variant.style(resolved_theme)
  }
  Some(
    text_input_state_for_single_line(
      text=self.value.get(),
      frame=ctx.frame,
      font=resolved_style.font,
      control=ctx.text_control,
      text_system=ctx.text_system,
      search_bar=self.search_bar,
    ),
  )
}

///|
impl @core.ViewNode for SingleLineTextInput with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::TextField,
    label=self.placeholder,
    value=self.value.get(),
    actions=[
      @core.SemanticsAction::Focus,
      @core.SemanticsAction::SetText,
      @core.SemanticsAction::Submit,
    ],
  )
}

///|
impl @core.ViewNode for SingleLineTextInput with fn focusable(_self) {
  true
}
