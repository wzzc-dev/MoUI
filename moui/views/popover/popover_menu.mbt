///|
fn[Msg] dropdown_menu(
  items : Array[@controls.MenuItem[Msg]],
  theme~ : @core.Theme,
  width~ : Double,
  max_height~ : Double,
  selected? : String = "",
  label? : String = "Menu options",
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      @button.button(
        item.label,
        on_click=item.message,
        variant=if item.enabled {
          @style.ButtonVariant::Ghost
        } else {
          @style.ButtonVariant::Outline
        },
        theme~,
        width~,
        height=34.0,
      )
      .disabled(disabled=!item.enabled)
      .semantics_selected(selected=item.id == selected)
      .accessibility_label(item.label),
    )
  }
  scroll_view(
    @layout.column(rows, spacing=theme.spacing_scale.xs),
    width~,
    height=max_height,
  )
  .semantics_role(@core.SemanticsRole::Menu)
  .accessibility_label(label)
}

///|
fn[Msg] dropdown_selected_label(
  items : Array[@controls.MenuItem[Msg]],
  selected : String,
  placeholder : String,
) -> String {
  for item in items {
    if item.id == selected {
      return item.label
    }
  }
  placeholder
}
