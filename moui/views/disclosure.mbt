///|
pub fn[Msg] disclosure(
  title : String,
  content~ : @core.View[Msg],
  expanded~ : Bool,
  on_toggle~ : Msg,
  subtitle? : String = "",
  theme? : @core.Theme = default_theme(),
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let title_width = views_max_double(80.0, width - 54.0)
  let title_rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=title_width, height=24.0),
  ]
  if subtitle != "" {
    title_rows.push(
      text(
        subtitle,
        role=TextRole::Caption,
        theme~,
        width=title_width,
        height=22.0,
      ),
    )
  }
  let header = row(
    [
      button(
        if expanded {
          "v"
        } else {
          ">"
        },
        on_click=on_toggle,
        variant=ButtonVariant::Ghost,
        theme~,
        width=34.0,
        height=34.0,
      ),
      column(title_rows, spacing=0.0, align=CrossAlign::Start),
    ],
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Center,
  )
  let rows : Array[@core.View[Msg]] = [header]
  if expanded {
    rows.push(content.frame(width=width - theme.spacing_scale.md * 2.0))
  }
  column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start)
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_expanded(expanded~)
  .semantics_description(subtitle)
}

///|
pub fn[Msg] accordion(
  sections : Array[WizardStep[Msg]],
  expanded~ : Array[String],
  on_toggle~ : (String) -> Msg,
  theme? : @core.Theme = default_theme(),
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for section in sections {
    rows.push(
      collapsible_panel(
        section.title,
        content=section.content,
        expanded=string_array_contains(expanded, section.id),
        on_toggle=on_toggle(section.id),
        subtitle=section.subtitle,
        theme~,
        width~,
      ).disabled(disabled=!section.enabled),
    )
  }
  column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
pub fn[Msg] collapsible_panel(
  title : String,
  content~ : @core.View[Msg],
  expanded~ : Bool,
  on_toggle~ : Msg,
  subtitle? : String = "",
  theme? : @core.Theme = default_theme(),
  width? : Double = 420.0,
) -> @core.View[Msg] {
  surface(
    disclosure(
      title,
      content~,
      expanded~,
      on_toggle~,
      subtitle~,
      theme~,
      width=width - theme.spacing_scale.md * 2.0,
    ),
    width~,
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
  ).border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(theme.palette.outline.multiply_alpha(0.64)),
      width=1.0,
    ),
  )
}

///|
pub fn[Msg] resizable_panel(
  content~ : @core.View[Msg],
  size~ : Double,
  theme? : @core.Theme = default_theme(),
  height? : Double = 160.0,
  min_size? : Double = 120.0,
  max_size? : Double = 520.0,
  on_drag? : ((Double) -> Msg)? = None,
) -> @core.View[Msg] {
  let panel_width = disclosure_clamp_double(size, min_size, max_size)
  let handle = surface(
    empty(),
    width=8.0,
    height~,
    background=theme.palette.primary.multiply_alpha(0.38),
    corner_radius=4.0,
    theme~,
    padding=0.0,
  ).accessibility_label("Resize handle")
  let handle = match on_drag {
    Some(handler) =>
      handle.on_drag(event => {
        handler(
          disclosure_clamp_double(
            size + event.translation.x,
            min_size,
            max_size,
          ),
        )
      })
    None => handle
  }
  row(
    [
      surface(
        content.frame(
          width=panel_width - theme.spacing_scale.md * 2.0,
          height=height - theme.spacing_scale.md * 2.0,
        ),
        width=panel_width,
        height~,
        variant=SurfaceVariant::Raised,
        theme~,
        padding=theme.spacing_scale.md,
      ),
      handle,
    ],
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Start,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
fn disclosure_clamp_double(
  value : Double,
  min : Double,
  max : Double,
) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
