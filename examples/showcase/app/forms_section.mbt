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
    "Form primitives compose validation, helper text, field states, and input wrappers.",
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
        form_section(
          [
            form_field(
              label="Search",
              child=clearable_text_field(
                self.draft,
                on_input=value => DraftChanged(value),
                on_clear=ClearFilter,
                placeholder="Clearable input",
                theme~,
                width=field_width,
              ),
              helper="Clearable inputs expose an app-owned clear message.",
              theme~,
              width=field_width,
            ),
            form_field(
              label="Amount",
              child=input_group(
                child=number_field(
                  "42",
                  on_input=value => DraftChanged(value),
                  on_step=Some(_delta => ToggleActive),
                  theme~,
                  width=240.0,
                ),
                prefix=Some(text("$", width=20.0, height=24.0)),
                suffix=Some(text("USD", width=44.0, height=24.0)),
                theme~,
                width=field_width,
              ),
              helper="Number fields keep parsing in the app model.",
              theme~,
              width=field_width,
            ),
            form_field(
              label="Secret",
              child=password_field(
                "secret",
                on_input=value => DraftChanged(value),
                revealed=self.active,
                on_toggle_reveal=ToggleActive,
                theme~,
                width=field_width,
              ),
              helper="Reveal state is controlled by the app.",
              theme~,
              width=field_width,
            ),
            form_field(
              label="Notes",
              child=multiline_text_area_shell(
                "First line of notes",
                on_input=value => DraftChanged(value),
                placeholder="Add notes",
                lines=3,
                theme~,
                width=field_width,
              ),
              helper="The shell preserves sizing without adding a new editor engine.",
              theme~,
              width=field_width,
            ),
            stepper(
              on_decrement=SliderChanged(self.slider_value - 0.1),
              on_increment=SliderChanged(self.slider_value + 0.1),
              label="Stepper",
              theme~,
              width=180.0,
            ),
          ],
          title="Enhanced Inputs",
          summary="Prefix/suffix, clearable, password, number, stepper, and text area shells",
          width=field_width,
          theme~,
        ),
      ],
      spacing=theme.spacing_scale.lg,
      theme~,
      width=metrics.body_width,
    ),
    metrics~,
  )
}
