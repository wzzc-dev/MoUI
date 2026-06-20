///|
pub fn[Msg] form(
  children : Array[@core.View[Msg]],
  spacing? : Double = default_theme().spacing_scale.lg,
  theme? : @core.Theme,
  width? : Double,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  column(children, spacing~, align=CrossAlign::Stretch)
  .frame(width?)
  .semantics_role(@core.SemanticsRole::Form)
  .accessibility_label("Form")
  .theme(resolved_theme)
}

///|
pub fn[Msg] form_section(
  title? : String = "",
  children : Array[@core.View[Msg]],
  summary? : String = "",
  spacing? : Double = default_theme().spacing_scale.md,
  theme? : @core.Theme,
  width? : Double,
  padding? : Double = default_theme().spacing_scale.md,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
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
        theme=resolved_theme,
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
        theme=resolved_theme,
        width=content_width,
        height=24.0,
      ),
    )
  }
  // When the section has a header, separate it from the fields with a hairline
  // so the section reads as a titled group rather than a flat column.
  if title != "" || summary != "" {
    rows.push(divider(theme=resolved_theme))
  }
  for child in children {
    rows.push(child)
  }
  container(
    column(rows, spacing~, align=CrossAlign::Stretch),
    width?,
    variant=ContainerVariant::Base,
    theme=resolved_theme,
    padding~,
  ).semantics_role(@core.SemanticsRole::Group)
}
