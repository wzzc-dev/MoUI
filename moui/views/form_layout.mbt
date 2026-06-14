///|
pub fn[Msg] form(
  children : Array[@core.View[Msg]],
  spacing? : Double = @core.Theme::default().spacing_scale.lg,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double,
) -> @core.View[Msg] {
  column(children, spacing~, align=CrossAlign::Stretch)
  .frame(width?)
  .semantics_role(@core.SemanticsRole::Form)
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
      text(
        title,
        role=TextRole::Control,
        theme~,
        width=content_width,
        height=28.0,
      ),
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
