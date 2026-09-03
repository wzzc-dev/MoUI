///|
pub fn[Msg] dropdown(
  label : String,
  items : Array[@controls.MenuItem[Msg]],
  state~ : DropdownState,
  on_toggle~ : Msg,
  placeholder? : String = "Select",
  theme? : @core.Theme,
  width? : Double = 240.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let selected_label = dropdown_selected_label(
    items,
    state.selected,
    placeholder,
  )
  let anchor_view = @button.button(
      label + ": " + selected_label,
      on_click=on_toggle,
      variant=@style.ButtonVariant::Tonal,
      theme=resolved_theme,
      width~,
    )
    .semantics_role(@core.SemanticsRole::Menu)
    .semantics_expanded(expanded=state.expanded)
    .accessibility_label(label + ": " + selected_label)
  let anchor = @controls.semantic_toggle_action_control(
    anchor_view,
    state.expanded,
    on_toggle,
  )
  let popups : Array[@presentation.PresentationSpec[Msg]] = if state.expanded {
    [
      popup_spec(
        id="dropdown:\{label}",
        content=dropdown_menu(
          items,
          theme=resolved_theme,
          width=width - resolved_theme.spacing_scale.sm * 2.0,
          max_height~,
          selected=state.selected,
          label=label + " options",
        ),
        theme=resolved_theme,
        width~,
        height=max_height,
      ),
    ]
  } else {
    []
  }
  @presentation.popup_host(anchor, popups)
}

///|
pub fn[Msg] combobox(
  value : String,
  on_input~ : (String) -> Msg,
  items : Array[@controls.MenuItem[Msg]],
  expanded~ : Bool,
  on_toggle~ : Msg,
  placeholder? : String = "Search",
  theme? : @core.Theme,
  width? : Double = 280.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let anchor_view = @layout.row(
    [
      @text.text_field(
        value,
        on_input~,
        placeholder~,
        variant=@style.TextFieldVariant::Outline,
        theme=resolved_theme,
        width=@common.max_view_double(80.0, width - 70.0),
      ),
      @button.button(
        "Open",
        on_click=on_toggle,
        variant=@style.ButtonVariant::Ghost,
        theme=resolved_theme,
        width=62.0,
      )
      .semantics_expanded(expanded~)
      .accessibility_label(
        if expanded {
          "Close options"
        } else {
          "Open options"
        },
      ),
    ],
    spacing=resolved_theme.spacing_scale.xs,
    align=@style.CrossAlign::Center,
  ).frame(width~)
  let anchor = @controls.semantic_toggle_action_control(
    anchor_view, expanded, on_toggle,
  )
  let popups : Array[@presentation.PresentationSpec[Msg]] = if expanded {
    [
      popup_spec(
        id="combobox:\{placeholder}",
        content=dropdown_menu(
          items,
          theme=resolved_theme,
          width=width - resolved_theme.spacing_scale.sm * 2.0,
          max_height~,
        ),
        theme=resolved_theme,
        width~,
        height=max_height,
      ),
    ]
  } else {
    []
  }
  @presentation.popup_host(anchor, popups)
}
