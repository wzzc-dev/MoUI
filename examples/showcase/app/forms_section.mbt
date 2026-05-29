///|
fn ShowcaseModel::forms_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let field_width = if metrics.compact { metrics.body_width } else { 420.0 }
  section_panel(
    theme,
    "Forms",
    "Form primitives compose labels, validation, helper text, and field states.",
    form(
      [
        form_section(
          [
            form_field(
              label="Display name",
              child=text_field(
                self.draft,
                on_input=value => DraftChanged(value),
                placeholder="Name shown in the app",
                variant=@views.TextFieldVariant::Outline,
                theme~,
                width=field_width,
              ),
              helper="Shown on normal fields",
              required=true,
              theme~,
              width=field_width,
            ),
            form_field(
              label="Email",
              child=text_field(
                "",
                on_input=value => DraftChanged(value),
                placeholder="name@example.com",
                variant=@views.TextFieldVariant::Outline,
                theme~,
                width=field_width,
              ),
              error="Email is required",
              status=@views.FormFieldStatus::Invalid,
              theme~,
              width=field_width,
            ),
            form_field(
              label="Account ID",
              child=text("moui-preview-001", width=240.0, height=28.0)
                .background(theme.palette.surface_variant.multiply_alpha(0.5))
                .corner_radius(theme.radius_scale.sm)
                .padding(6.0),
              helper="Read-only values can still be explained.",
              status=@views.FormFieldStatus::ReadOnly,
              layout=@views.FormFieldLayout::Horizontal,
              theme~,
              width=field_width,
            ),
          ],
          title="Profile",
          summary="Required, helper, and validation states",
          width=field_width,
          theme~,
        ),
        row(
          [
            form_helper_text(
              "Helper text can be reused outside a field.",
              theme~,
              width=260.0,
            ),
            form_error("Standalone error message", theme~, width=220.0),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.lg,
      theme~,
      width=metrics.body_width,
    ),
    metrics~,
  )
}
