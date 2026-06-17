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
  theme? : @core.Theme = default_theme(),
  width? : Double = 320.0,
  label_width? : Double = 120.0,
) -> @core.View[Msg] {
  let resolved_status = form_field_resolved_status(
    status, required, disabled, read_only, error,
  )
  let content_width = match layout {
    Vertical => width
    Horizontal =>
      views_max_double(80.0, width - label_width - theme.spacing_scale.md)
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
    child.frame(width=content_width).disabled(disabled~),
  ]
  match
    form_field_support_text(
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
  let body = column(
    body_rows,
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Stretch,
  )
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
  .semantics_role(@core.SemanticsRole::FormField)
  .semantics_required(
    required=required || resolved_status == FormFieldStatus::Required,
  )
  .semantics_invalid(invalid=resolved_status == FormFieldStatus::Invalid)
  .semantics_description(
    form_field_semantics_description(resolved_status, helper, error),
  )
  .accessibility_label(
    form_field_accessibility_label(label, resolved_status, error),
  )
}
