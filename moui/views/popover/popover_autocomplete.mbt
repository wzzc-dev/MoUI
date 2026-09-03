///|
pub fn[Msg] autocomplete(
  query : String,
  on_input~ : (String) -> Msg,
  suggestions : Array[@controls.MenuItem[Msg]],
  expanded~ : Bool,
  placeholder? : String = "Search",
  theme? : @core.Theme,
  width? : Double = 280.0,
  max_height? : Double = 180.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let anchor : @core.View[Msg] = @text.text_field(
    query,
    on_input~,
    placeholder~,
    variant=@style.TextFieldVariant::Outline,
    theme=resolved_theme,
    width~,
  )
  let popups : Array[@presentation.PresentationSpec[Msg]] = if expanded {
    [
      popup_spec(
        id="autocomplete:\{placeholder}",
        content=dropdown_menu(
          suggestions,
          theme=resolved_theme,
          width=width - resolved_theme.spacing_scale.sm * 2.0,
          max_height~,
          label="Autocomplete suggestions",
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
