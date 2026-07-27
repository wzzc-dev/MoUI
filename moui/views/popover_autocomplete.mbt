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
