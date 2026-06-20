///|
pub fn[Msg] form_field_state(
  field~ : FormFieldState,
  child~ : @core.View[Msg],
  helper? : String = "",
  validation_display? : FormValidationDisplay = FormValidationDisplay::OnInvalid,
  required? : Bool = false,
  disabled? : Bool = false,
  read_only? : Bool = false,
  theme? : @core.Theme,
  width? : Double = 320.0,
  label_width? : Double = 120.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let label = if field.label == "" { field.name } else { field.label }
  let error = match field.validate() {
    Some(error) => error.message
    None => ""
  }
  form_field(
    label~,
    child~,
    helper~,
    error~,
    status=if error == "" {
      FormFieldStatus::Normal
    } else {
      FormFieldStatus::Invalid
    },
    validation_display~,
    required~,
    disabled~,
    read_only~,
    theme=resolved_theme,
    width~,
    label_width~,
  )
}
