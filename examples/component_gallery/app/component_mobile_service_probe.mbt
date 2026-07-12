///|
fn mobile_service_probe_image_source() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
fn mobile_service_probe(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
  height~ : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = (width - 32.0).max(240.0)
  let action_width = if compact { inner } else { 220.0 }
  @views.container(
    @views.column(
      [
        @views.text(
          "Mobile Service Probe",
          role=@views.TextRole::Title,
          theme~,
          width=inner,
          height=36.0,
          align=@text.TextAlign::TextStart,
        ),
        @views.status_badge(
          platform_display_name(model.active_platform),
          tone=@views.BadgeTone::Accent,
          detail="matching host",
          theme~,
          width=180.0,
        ),
        @views.text_field(
          model.probe_text,
          on_input=value => ProbeTextChanged(value),
          on_submit=Some(ProbeSubmit),
          placeholder="Service probe text",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=inner,
        ),
        @views.text(
          "IME value: " + model.probe_text,
          role=@views.TextRole::Body,
          theme~,
          width=inner,
          height=28.0,
          align=@text.TextAlign::TextStart,
        ).accessibility_label("Service probe value " + model.probe_text),
        @views.button(
          "Activate service probe",
          on_click=ProbeAction,
          variant=@views.ButtonVariant::Primary,
          theme~,
          width=action_width,
        ),
        @views.text(
          "Action count: \{model.probe_action_count}",
          role=@views.TextRole::Subtitle,
          theme~,
          width=inner,
          height=30.0,
          align=@text.TextAlign::TextStart,
        ).accessibility_label(
          "Service probe action count \{model.probe_action_count}",
        ),
        @views.text(
          "Submit count: \{model.probe_submit_count}",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=24.0,
          align=@text.TextAlign::TextStart,
        ),
        @views.text(
          "Viewport: \{width.to_int()} x \{height.to_int()}",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=24.0,
          align=@text.TextAlign::TextStart,
        ).accessibility_label(
          "Service probe viewport \{width.to_int()} by \{height.to_int()}",
        ),
        @views.image(
          mobile_service_probe_image_source(),
          width=160.0,
          height=240.0,
          corner_radius=6.0,
          fit=@graphics.ImageFit::Contain,
        ).accessibility_label("Service probe async image"),
        @views.spacer(min_length=260.0),
        @views.text(
          "Service probe end",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=24.0,
          align=@text.TextAlign::TextStart,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    variant=@views.ContainerVariant::Raised,
    padding=16.0,
    corner_radius=8.0,
    theme~,
  )
}
