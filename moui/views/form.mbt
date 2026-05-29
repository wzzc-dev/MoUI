///|
pub fn[Msg] form(
  children : Array[@core.View[Msg]],
  spacing? : Double = @core.Theme::default().spacing_scale.lg,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double,
) -> @core.View[Msg] {
  column(children, spacing~, align=CrossAlign::Stretch)
  .frame(width?)
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Form")
  .theme(theme)
}

///|
pub fn[Msg] form_section(
  title? : String = "",
  children : Array[@core.View[Msg]],
  summary? : String = "",
  spacing? : Double = @core.Theme::default().spacing_scale.md,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double,
  padding? : Double = @core.Theme::default().spacing_scale.md,
) -> @core.View[Msg] {
  let content_width = match width {
    Some(value) => views_max_double(40.0, value - padding * 2.0)
    None => 320.0
  }
  let rows : Array[@core.View[Msg]] = []
  if title != "" {
    rows.push(
      text(title, role=TextRole::Control, theme~, width=content_width, height=28.0),
    )
  }
  if summary != "" {
    rows.push(
      text(
        summary,
        role=TextRole::Caption,
        theme~,
        width=content_width,
        height=24.0,
      ),
    )
  }
  for child in children {
    rows.push(child)
  }
  surface(
    column(rows, spacing~, align=CrossAlign::Stretch),
    width?,
    variant=SurfaceVariant::Base,
    theme~,
    padding~,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] form_field(
  label~ : String,
  child~ : @core.View[Msg],
  helper? : String = "",
  error? : String = "",
  status? : FormFieldStatus = FormFieldStatus::Normal,
  layout? : FormFieldLayout = FormFieldLayout::Vertical,
  validation_display? : FormValidationDisplay = FormValidationDisplay::OnInvalid,
  required? : Bool = false,
  disabled? : Bool = false,
  read_only? : Bool = false,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
  label_width? : Double = 120.0,
) -> @core.View[Msg] {
  let resolved_status = form_field_resolved_status(
    status,
    required,
    disabled,
    read_only,
    error,
  )
  let content_width = match layout {
    Vertical => width
    Horizontal => views_max_double(80.0, width - label_width - theme.spacing_scale.md)
  }
  let label_view = form_field_label(
    label,
    status=resolved_status,
    required=required || resolved_status == FormFieldStatus::Required,
    width=match layout {
      Vertical => width
      Horizontal => label_width
    },
    theme~,
  )
  let body_rows : Array[@core.View[Msg]] = [
    child.frame(width=content_width).disabled(disabled=disabled),
  ]
  match form_field_support_text(
    helper~,
    error~,
    status=resolved_status,
    validation_display~,
    theme~,
    width=content_width,
  ) {
    Some(view) => body_rows.push(view)
    None => ()
  }
  let body = column(body_rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Stretch)
  let field = match layout {
    Vertical => column([label_view, body], spacing=theme.spacing_scale.xs)
    Horizontal =>
      row(
        [label_view, body],
        spacing=theme.spacing_scale.md,
        align=CrossAlign::Start,
      )
  }
  field
  .frame(width~)
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label(form_field_accessibility_label(label, resolved_status, error))
}

///|
pub fn[Msg] form_field_state(
  field~ : @core.FormFieldState,
  child~ : @core.View[Msg],
  helper? : String = "",
  validation_display? : FormValidationDisplay = FormValidationDisplay::OnInvalid,
  required? : Bool = false,
  disabled? : Bool = false,
  read_only? : Bool = false,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
  label_width? : Double = 120.0,
) -> @core.View[Msg] {
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
    status=if error == "" { FormFieldStatus::Normal } else { FormFieldStatus::Invalid },
    validation_display~,
    required~,
    disabled~,
    read_only~,
    theme~,
    width~,
    label_width~,
  )
}

///|
pub fn[Msg] form_error(
  message : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  text(message, role=TextRole::Caption, theme~, width~, height=24.0)
  .foreground(form_error_color(theme))
  .semantics_role(@core.SemanticsRole::Text)
  .accessibility_label("Error: " + message)
}

///|
pub fn[Msg] form_helper_text(
  message : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  text(message, role=TextRole::Caption, theme~, width~, height=24.0)
  .foreground(theme.palette.muted)
  .semantics_role(@core.SemanticsRole::Text)
}

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
  text(label_text, role=TextRole::Control, theme~, width~, height=26.0)
  .foreground(form_field_label_color(status, theme))
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
      } else if helper != "" {
        Some(form_helper_text(helper, theme~, width~))
      } else {
        None
      }
    OnInvalid =>
      if status == FormFieldStatus::Invalid && error != "" {
        Some(form_error(error, theme~, width~))
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
    Disabled => theme.palette.muted.multiply_alpha(0.68)
    ReadOnly => theme.palette.muted
    Normal | Required => theme.palette.foreground
  }
}

///|
fn form_error_color(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => @core.Color::rgba(r=0.74, g=0.12, b=0.16)
    @core.ColorScheme::Dark => @core.Color::rgba(r=1.0, g=0.48, b=0.52)
  }
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
    Disabled => label + ", disabled"
    ReadOnly => label + ", read only"
    Normal => label
  }
}
