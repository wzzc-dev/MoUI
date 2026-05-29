///|
pub fn[Msg] popover(
  anchor~ : @core.View[Msg],
  content~ : @core.View[Msg],
  expanded~ : Bool,
  placement? : PopoverPlacement = PopoverPlacement::BottomStart,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 240.0,
  height? : Double = 160.0,
) -> @core.View[Msg] {
  if expanded {
    stack([
      anchor,
      surface(
        content,
        width~,
        height~,
        variant=SurfaceVariant::Overlay,
        theme~,
        padding=theme.spacing_scale.sm,
      )
      .shadow(theme.shadow_scale.md)
      .align(alignment=popover_alignment(placement)),
    ])
  } else {
    anchor
  }
}

///|
pub fn[Msg] dropdown(
  label : String,
  items : Array[MenuItem[Msg]],
  state~ : DropdownState,
  on_toggle~ : Msg,
  placeholder? : String = "Select",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 240.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  let selected_label = dropdown_selected_label(items, state.selected, placeholder)
  let anchor = button(
    label + ": " + selected_label,
    on_click=on_toggle,
    variant=ButtonVariant::Tonal,
    theme~,
    width~,
  )
  popover(
    anchor~,
    content=dropdown_menu(items, theme~, width=width - theme.spacing_scale.sm * 2.0, max_height~),
    expanded=state.expanded,
    theme~,
    width~,
    height=max_height,
  )
}

///|
pub fn[Msg] combobox(
  value : String,
  on_input~ : (String) -> Msg,
  items : Array[MenuItem[Msg]],
  expanded~ : Bool,
  on_toggle~ : Msg,
  placeholder? : String = "Search",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 280.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  let anchor = row(
    [
      text_field(
        value,
        on_input~,
        placeholder~,
        variant=TextFieldVariant::Outline,
        theme~,
        width=views_max_double(80.0, width - 70.0),
      ),
      button("Open", on_click=on_toggle, variant=ButtonVariant::Ghost, theme~, width=62.0),
    ],
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Center,
  ).frame(width~)
  popover(
    anchor~,
    content=dropdown_menu(items, theme~, width=width - theme.spacing_scale.sm * 2.0, max_height~),
    expanded~,
    theme~,
    width~,
    height=max_height,
  )
}

///|
pub fn[Msg] autocomplete(
  query : String,
  on_input~ : (String) -> Msg,
  suggestions : Array[MenuItem[Msg]],
  expanded~ : Bool,
  placeholder? : String = "Search",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 280.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  popover(
    anchor=text_field(
      query,
      on_input~,
      placeholder~,
      variant=TextFieldVariant::Outline,
      theme~,
      width~,
    ),
    content=dropdown_menu(
      suggestions,
      theme~,
      width=width - theme.spacing_scale.sm * 2.0,
      max_height~,
    ),
    expanded~,
    theme~,
    width~,
    height=max_height,
  )
}

///|
fn[Msg] dropdown_menu(
  items : Array[MenuItem[Msg]],
  theme~ : @core.Theme,
  width~ : Double,
  max_height~ : Double,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      button(
        item.label,
        on_click=item.message,
        variant=if item.enabled { ButtonVariant::Ghost } else { ButtonVariant::Outline },
        theme~,
        width~,
        height=34.0,
      ).disabled(disabled=!item.enabled),
    )
  }
  scroll_view(column(rows, spacing=theme.spacing_scale.xs), width~, height=max_height)
}

///|
fn[Msg] dropdown_selected_label(
  items : Array[MenuItem[Msg]],
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

///|
fn popover_alignment(placement : PopoverPlacement) -> @core.Alignment {
  match placement {
    BottomStart => @core.Alignment::new(x=0.0, y=1.0)
    BottomEnd => @core.Alignment::new(x=1.0, y=1.0)
    TopStart => @core.Alignment::new(x=0.0, y=0.0)
    TopEnd => @core.Alignment::new(x=1.0, y=0.0)
  }
}
