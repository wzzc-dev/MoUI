///|
pub fn[Msg] segmented_control(
  items : Array[ChoiceItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  size? : SegmentedControlSize = SegmentedControlSize::Regular,
  theme? : @core.Theme = default_theme(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let height = match size {
    Compact => 32.0
    Regular => 40.0
  }
  let item_width = if items.length() == 0 {
    width
  } else {
    width / items.length().to_double()
  }
  let segments : Array[@core.View[Msg]] = []
  for item in items {
    let active = item.id == selected
    segments.push(
      button(
        item.label,
        on_click=on_select(item.id),
        variant=if active {
          ButtonVariant::Primary
        } else {
          ButtonVariant::Ghost
        },
        theme~,
        width=item_width,
        height~,
      )
      .semantics_role(@core.SemanticsRole::Tab)
      .semantics_selected(selected=active),
    )
  }
  container(
    row(segments, spacing=0.0, align=CrossAlign::Center),
    width~,
    height~,
    background=theme.palette.surface_variant.multiply_alpha(0.55),
    corner_radius=theme.radius_scale.md,
    padding=2.0,
  ).semantics_role(@core.SemanticsRole::Group)
}
