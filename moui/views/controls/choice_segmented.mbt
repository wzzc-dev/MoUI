///|
pub fn[Msg] segmented_control(
  items : Array[ChoiceItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  size? : @style.SegmentedControlSize = @style.SegmentedControlSize::Regular,
  theme? : @core.Theme,
  width? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let height = match size {
    @style.SegmentedControlSize::Compact => 32.0
    @style.SegmentedControlSize::Regular => 40.0
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
      @button.button(
        item.label,
        on_click=on_select(item.id),
        variant=if active {
          @style.ButtonVariant::Primary
        } else {
          @style.ButtonVariant::Ghost
        },
        theme=resolved_theme,
        width=item_width,
        height~,
      )
      .semantics_role(@core.SemanticsRole::Tab)
      .semantics_selected(selected=active),
    )
  }
  @container.container(
    @layout.row(segments, spacing=0.0, align=@style.CrossAlign::Center),
    width~,
    height~,
    background=resolved_theme.palette.surface_variant.multiply_alpha(0.55),
    corner_radius=resolved_theme.radius_scale.md,
    padding=2.0,
  ).semantics_role(@core.SemanticsRole::Group)
}
