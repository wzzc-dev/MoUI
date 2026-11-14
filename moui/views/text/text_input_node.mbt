///|
priv struct SingleLineTextInput {
  value : String
  placeholder : String
  size : @core.Size
  theme : @core.Theme?
  variant : @style.TextFieldVariant
  style : @style.TextFieldStyle?
  search_bar : Bool
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
impl @core.ViewNode for SingleLineTextInput with fn layout(self, ctx) {
  // A zero height means "use the theme's control height", so presets move
  // every input together. An explicit height still wins for dense rows.
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let height = if self.size.height > 0.0 {
    self.size.height
  } else {
    resolved_theme.layout_scale.control_height
  }
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.size.width, height~),
    ),
  )
}

///|
impl @core.ViewNode for SingleLineTextInput with fn paint(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => self.variant.style(resolved_theme)
  }
  let disabled_mode = ctx.state.disabled || !ctx.environment.enabled
  let normal = if disabled_mode {
    resolved_style.disabled
  } else {
    resolved_style.normal
  }
  let focused = resolved_style.focused
  let focused_state = ctx.focused && !disabled_mode
  let mut animating = false
  // Hover lifts the outline to full strength instead of adding a fill: an
  // input's surface should stay stable while the pointer crosses it.
  let input_border = if focused_state {
    focused.border
  } else {
    match normal.border {
      Some(value) => {
        let (border_color, border_animating) = if disabled_mode {
          (@common.pressable_state_color(value.brush), false)
        } else {
          @common.pressable_transition_color(
            ctx,
            control="text_field",
            normal=@common.pressable_state_color(value.brush),
            hovered=resolved_theme.palette.outline,
            pressed=resolved_theme.palette.outline,
          )
        }
        animating = border_animating
        Some(
          @core.BorderStyle::new(
            brush=@core.Brush::solid(border_color),
            width=value.width,
          ),
        )
      }
      None => None
    }
  }
  let commands : Array[@core.DrawCommand] = []
  let overlay_commands : Array[@core.DrawCommand] = []
  if self.search_bar {
    append_searchbar_commands(
      commands,
      overlay_commands,
      text=self.value,
      placeholder=self.placeholder,
      font=resolved_style.font,
      foreground=normal.foreground,
      placeholder_color=resolved_style.placeholder_color,
      background=normal.background,
      border=input_border,
      focused_border=focused.border,
      cursor_color=resolved_style.cursor_color,
      corner_radius=normal.radius,
      frame=ctx.frame,
      focused=focused_state,
      control=ctx.text_control,
      text_system=ctx.text_system,
      theme=resolved_theme,
      direction=ctx.environment.layout_direction,
    )
  } else {
    append_text_field_commands(
      commands,
      overlay_commands,
      text=self.value,
      placeholder=self.placeholder,
      size=self.size,
      font=resolved_style.font,
      foreground=normal.foreground,
      placeholder_color=resolved_style.placeholder_color,
      background=normal.background,
      border=input_border,
      focused_border=focused.border,
      cursor_color=resolved_style.cursor_color,
      corner_radius=normal.radius,
      frame=ctx.frame,
      focused=focused_state,
      control=ctx.text_control,
      text_system=ctx.text_system,
      theme=resolved_theme,
      bottom_border_only=normal.bottom_border_only,
      direction=ctx.environment.layout_direction,
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
    repaint_boundary: false,
    animating,
  }
}

///|
impl @core.ViewNode for SingleLineTextInput with fn text_input_state(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => self.variant.style(resolved_theme)
  }
  Some(
    text_input_state_for_single_line(
      text=self.value,
      frame=ctx.frame,
      font=resolved_style.font,
      control=ctx.text_control,
      text_system=ctx.text_system,
      search_bar=self.search_bar,
      direction=ctx.environment.layout_direction,
    ),
  )
}

///|
impl @core.ViewNode for SingleLineTextInput with fn semantics(self) {
  // Only `multiline` is a structural fact here; whether the field is locked or
  // masked belongs to the wrapper that builds it.
  @core.ViewSemanticsInfo::text_field(label=self.placeholder, value=self.value)
}

///|
impl @core.ViewNode for SingleLineTextInput with fn focusable(_self) {
  true
}
