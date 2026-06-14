///|
pub fn[Msg] toolbar(
  children : Array[@core.View[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 48.0,
) -> @core.View[Msg] {
  surface(
    row(children, spacing=theme.spacing_scale.sm, align=CrossAlign::Center),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] button_group(
  items : Array[MenuItem[Msg]],
  selected? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  button_width? : Double = 88.0,
  height? : Double = 36.0,
) -> @core.View[Msg] {
  let buttons : Array[@core.View[Msg]] = []
  for item in items {
    let variant = if item.id == selected {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Outline
    }
    buttons.push(
      button(
        item.label,
        on_click=item.message,
        variant~,
        theme~,
        width=button_width,
        height~,
      )
      .disabled(disabled=!item.enabled)
      .semantics_selected(selected=item.id == selected),
    )
  }
  row(buttons, spacing=0.0, align=CrossAlign::Center).semantics_role(
    @core.SemanticsRole::ButtonGroup,
  )
}

///|
pub fn[Msg] command_bar(
  items : Array[MenuItem[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 48.0,
) -> @core.View[Msg] {
  let commands : Array[@core.View[Msg]] = []
  for item in items {
    commands.push(
      button(
        item.label,
        on_click=item.message,
        variant=ButtonVariant::Ghost,
        theme~,
        width=command_item_width(item.label),
        height=36.0,
      ).disabled(disabled=!item.enabled),
    )
  }
  toolbar(commands, theme~, width~, height~)
}

///|
pub fn[Msg] status_bar(
  items : Array[String],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 30.0,
) -> @core.View[Msg] {
  let segments : Array[@core.View[Msg]] = []
  for item in items {
    segments.push(
      text(
        item,
        role=TextRole::Caption,
        theme~,
        width=command_item_width(item),
        height=22.0,
      ),
    )
  }
  surface(
    row(segments, spacing=theme.spacing_scale.sm, align=CrossAlign::Center),
    width~,
    height~,
    background=theme.palette.surface_variant.multiply_alpha(0.52),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.xs,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
fn command_item_width(label : String) -> Double {
  views_max_double(54.0, label.to_array().length().to_double() * 8.0 + 24.0)
}
