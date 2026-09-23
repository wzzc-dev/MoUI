///|
pub fn[Msg] clearable_text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_clear~ : Msg,
  placeholder? : String = "",
  variant? : @style.TextFieldVariant = Filled,
  theme? : @core.Theme,
  width? : Double = 280.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  @layout.row(
    [
      @text.text_field(
        value,
        on_input~,
        placeholder~,
        variant~,
        theme=resolved_theme,
        width=@common.view_max_double(80.0, width - 72.0),
        height~,
      ),
      @button.button(
        "Clear",
        on_click=on_clear,
        variant=Ghost,
        theme=resolved_theme,
        width=64.0,
        height~,
      ),
    ],
    spacing=resolved_theme.spacing_scale.xs,
    align=Center,
  ).frame(width~)
}

///|
pub fn[Msg] password_field(
  value : String,
  on_input~ : (String) -> Msg,
  revealed~ : Bool,
  on_toggle_reveal~ : Msg,
  placeholder? : String = "Password",
  variant? : @style.TextFieldVariant = Filled,
  theme? : @core.Theme,
  width? : Double = 280.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let display_value = if revealed { value } else { mask_text(value) }
  @layout.row(
    [
      @text.text_field(
        display_value,
        on_input~,
        placeholder~,
        variant~,
        theme=resolved_theme,
        width=@common.view_max_double(80.0, width - 72.0),
        height~,
      ),
      @button.button(
        if revealed {
          "Hide"
        } else {
          "Show"
        },
        on_click=on_toggle_reveal,
        variant=Ghost,
        theme=resolved_theme,
        width=64.0,
        height~,
      ),
    ],
    spacing=resolved_theme.spacing_scale.xs,
    align=Center,
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
