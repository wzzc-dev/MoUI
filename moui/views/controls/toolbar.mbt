///|
pub fn[Msg] toolbar(
  children : Array[@core.View[Msg]],
  theme? : @core.Theme,
  width? : Double = 520.0,
  height? : Double = 48.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  @container.container(
    @layout.row(
      children,
      spacing=resolved_theme.spacing_scale.sm,
      align=@style.CrossAlign::Center,
    ),
    width~,
    height~,
    variant=@style.ContainerVariant::Base,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.xs,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] button_group(
  items : Array[ActionItem[Msg]],
  selected? : String = "",
  theme? : @core.Theme,
  button_width? : Double = 88.0,
  height? : Double = 36.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let buttons : Array[@core.View[Msg]] = []
  for item in items {
    let variant = if item.id == selected {
      @style.ButtonVariant::Primary
    } else {
      @style.ButtonVariant::Outline
    }
    buttons.push(
      @button.button(
        item.label,
        on_click=item.message,
        variant~,
        theme=resolved_theme,
        width=button_width,
        height~,
      )
      .disabled(disabled=!item.enabled)
      .semantics_selected(selected=item.id == selected),
    )
  }
  @layout.row(buttons, spacing=0.0, align=@style.CrossAlign::Center).semantics_role(
    @core.SemanticsRole::ButtonGroup,
  )
}

///|
pub fn[Msg] command_bar(
  items : Array[ActionItem[Msg]],
  theme? : @core.Theme,
  width? : Double = 520.0,
  height? : Double = 48.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let commands : Array[@core.View[Msg]] = []
  for item in items {
    commands.push(
      @button.button(
        item.label,
        on_click=item.message,
        variant=@style.ButtonVariant::Ghost,
        theme=resolved_theme,
        width=command_item_width(item.label),
        height=36.0,
      ).disabled(disabled=!item.enabled),
    )
  }
  toolbar(commands, theme=resolved_theme, width~, height~)
}

///|
pub fn[Msg] status_bar(
  items : Array[String],
  theme? : @core.Theme,
  width? : Double = 520.0,
  height? : Double = 30.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let segments : Array[@core.View[Msg]] = []
  for item in items {
    segments.push(
      @text.text(
        item,
        role=@style.TextRole::Caption,
        theme=resolved_theme,
        width=command_item_width(item),
        height=22.0,
      ),
    )
  }
  @container.container(
    @layout.row(
      segments,
      spacing=resolved_theme.spacing_scale.sm,
      align=@style.CrossAlign::Center,
    ),
    width~,
    height~,
    background=resolved_theme.palette.surface_variant.multiply_alpha(0.52),
    corner_radius=resolved_theme.radius_scale.sm,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.xs,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
fn command_item_width(label : String) -> Double {
  @common.view_max_double(
    54.0,
    label.to_array().length().to_double() * 8.0 + 24.0,
  )
}
