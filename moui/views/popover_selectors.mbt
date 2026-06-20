///|
pub fn[Msg] dropdown(
  label : String,
  items : Array[MenuItem[Msg]],
  state~ : DropdownState,
  on_toggle~ : Msg,
  placeholder? : String = "Select",
  theme? : @core.Theme,
  width? : Double = 240.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let selected_label = dropdown_selected_label(
    items,
    state.selected,
    placeholder,
  )
  let anchor = button(
      label + ": " + selected_label,
      on_click=on_toggle,
      variant=ButtonVariant::Tonal,
      theme=resolved_theme,
      width~,
    )
    .semantics_role(@core.SemanticsRole::Menu)
    .semantics_expanded(expanded=state.expanded)
    .semantics_action(popover_toggle_action(state.expanded))
    .accessibility_label(label + ": " + selected_label)
  popover(
    anchor~,
    content=dropdown_menu(
      items,
      theme=resolved_theme,
      width=width - resolved_theme.spacing_scale.sm * 2.0,
      max_height~,
      selected=state.selected,
      label=label + " options",
    ),
    expanded=state.expanded,
    theme=resolved_theme,
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
  theme? : @core.Theme,
  width? : Double = 280.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let anchor = row(
    [
      text_field(
        value,
        on_input~,
        placeholder~,
        variant=TextFieldVariant::Outline,
        theme=resolved_theme,
        width=views_max_double(80.0, width - 70.0),
      ),
      button(
        "Open",
        on_click=on_toggle,
        variant=ButtonVariant::Ghost,
        theme=resolved_theme,
        width=62.0,
      )
      .semantics_expanded(expanded~)
      .semantics_action(popover_toggle_action(expanded))
      .accessibility_label(
        if expanded {
          "Close options"
        } else {
          "Open options"
        },
      ),
    ],
    spacing=resolved_theme.spacing_scale.xs,
    align=CrossAlign::Center,
  ).frame(width~)
  popover(
    anchor~,
    content=dropdown_menu(
      items,
      theme=resolved_theme,
      width=width - resolved_theme.spacing_scale.sm * 2.0,
      max_height~,
    ),
    expanded~,
    theme=resolved_theme,
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
  theme? : @core.Theme,
  width? : Double = 280.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  popover(
    anchor=text_field(
      query,
      on_input~,
      placeholder~,
      variant=TextFieldVariant::Outline,
      theme=resolved_theme,
      width~,
    ),
    content=dropdown_menu(
      suggestions,
      theme=resolved_theme,
      width=width - resolved_theme.spacing_scale.sm * 2.0,
      max_height~,
      label="Autocomplete suggestions",
    ),
    expanded~,
    theme=resolved_theme,
    width~,
    height=max_height,
  )
}
