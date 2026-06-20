///|
pub fn[Msg] clearable_text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_clear~ : Msg,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme,
  width? : Double = 280.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  row(
    [
      text_field(
        value,
        on_input~,
        placeholder~,
        variant~,
        theme=resolved_theme,
        width=views_max_double(80.0, width - 72.0),
        height~,
      ),
      button(
        "Clear",
        on_click=on_clear,
        variant=ButtonVariant::Ghost,
        theme=resolved_theme,
        width=64.0,
        height~,
      ),
    ],
    spacing=resolved_theme.spacing_scale.xs,
    align=CrossAlign::Center,
  ).frame(width~)
}

///|
pub fn[Msg] password_field(
  value : String,
  on_input~ : (String) -> Msg,
  revealed~ : Bool,
  on_toggle_reveal~ : Msg,
  placeholder? : String = "Password",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme,
  width? : Double = 280.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let display_value = if revealed { value } else { mask_text(value) }
  row(
    [
      text_field(
        display_value,
        on_input~,
        placeholder~,
        variant~,
        theme=resolved_theme,
        width=views_max_double(80.0, width - 72.0),
        height~,
      ),
      button(
        if revealed {
          "Hide"
        } else {
          "Show"
        },
        on_click=on_toggle_reveal,
        variant=ButtonVariant::Ghost,
        theme=resolved_theme,
        width=64.0,
        height~,
      ),
    ],
    spacing=resolved_theme.spacing_scale.xs,
    align=CrossAlign::Center,
  ).frame(width~)
}

///|
fn mask_text(value : String) -> String {
  let mut masked = ""
  for _ in value {
    masked = masked + "*"
  }
  masked
}
