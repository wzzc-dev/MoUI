///|
fn form_field_resolved_status(
  status : FormFieldStatus,
  required : Bool,
  disabled : Bool,
  read_only : Bool,
  error : String,
) -> FormFieldStatus {
  if disabled {
    FormFieldStatus::Disabled
  } else if error != "" {
    FormFieldStatus::Invalid
  } else if read_only {
    FormFieldStatus::ReadOnly
  } else if status != FormFieldStatus::Normal {
    status
  } else if required {
    FormFieldStatus::Required
  } else {
    FormFieldStatus::Normal
  }
}

///|
fn[Msg] form_field_label(
  label : String,
  status~ : FormFieldStatus,
  required~ : Bool,
  width~ : Double,
  theme~ : @core.Theme,
) -> @core.View[Msg] {
  let label_text = if required { label + " *" } else { label }
  text(label_text, role=TextRole::Control, theme~, width~, height=26.0).foreground(
    form_field_label_color(status, theme),
  )
}

///|
fn[Msg] form_field_support_text(
  helper~ : String,
  error~ : String,
  status~ : FormFieldStatus,
  validation_display~ : FormValidationDisplay,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg]? {
  match validation_display {
    Hidden => None
    Always =>
      if error != "" {
        Some(form_error(error, theme~, width~))
      } else if status == FormFieldStatus::Validating {
        Some(
          form_helper_text(form_field_validating_text(helper), theme~, width~),
        )
      } else if helper != "" {
        Some(form_helper_text(helper, theme~, width~))
      } else {
        None
      }
    OnInvalid =>
      if status == FormFieldStatus::Invalid && error != "" {
        Some(form_error(error, theme~, width~))
      } else if status == FormFieldStatus::Validating {
        Some(
          form_helper_text(form_field_validating_text(helper), theme~, width~),
        )
      } else if helper != "" {
        Some(form_helper_text(helper, theme~, width~))
      } else {
        None
      }
  }
}

///|
fn form_field_label_color(
  status : FormFieldStatus,
  theme : @core.Theme,
) -> @core.Color {
  match status {
    Invalid => form_error_color(theme)
    Validating => theme.palette.primary
    Disabled => theme.palette.muted.multiply_alpha(0.68)
    ReadOnly => theme.palette.muted
    Normal | Required => theme.palette.foreground
  }
}

///|
fn form_field_validating_text(helper : String) -> String {
  if helper == "" {
    "Validating..."
  } else {
    helper + " Validating..."
  }
}

///|
fn form_field_semantics_description(
  status : FormFieldStatus,
  helper : String,
  error : String,
) -> String {
  if error != "" {
    error
  } else if status == FormFieldStatus::Validating {
    form_field_validating_text(helper)
  } else {
    helper
  }
}

///|
fn form_error_color(theme : @core.Theme) -> @core.Color {
  @core.FormValidationStyle::default(theme~).foreground
}

///|
fn form_field_accessibility_label(
  label : String,
  status : FormFieldStatus,
  error : String,
) -> String {
  match status {
    Invalid =>
      if error == "" {
        label + ", invalid"
      } else {
        label + ", invalid, " + error
      }
    Required => label + ", required"
    Validating => label + ", validating"
    Disabled => label + ", disabled"
    ReadOnly => label + ", read only"
    Normal => label
  }
}
