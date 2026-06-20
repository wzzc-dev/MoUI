///|
pub fn[Msg] disclosure(
  title : String,
  content~ : @core.View[Msg],
  expanded~ : Bool,
  on_toggle~ : Msg,
  subtitle? : String = "",
  theme? : @core.Theme,
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let title_width = views_max_double(80.0, width - 54.0)
  let title_rows : Array[@core.View[Msg]] = [
    text(
      title,
      role=TextRole::Control,
      theme=resolved_theme,
      width=title_width,
      height=24.0,
    ),
  ]
  if subtitle != "" {
    title_rows.push(
      text(
        subtitle,
        role=TextRole::Caption,
        theme=resolved_theme,
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
        theme=resolved_theme,
        width=34.0,
        height=34.0,
      ),
      column(title_rows, spacing=0.0, align=CrossAlign::Start),
    ],
    spacing=resolved_theme.spacing_scale.xs,
    align=CrossAlign::Center,
  )
  let rows : Array[@core.View[Msg]] = [header]
  if expanded {
    rows.push(
      content.frame(width=width - resolved_theme.spacing_scale.md * 2.0),
    )
  }
  column(rows, spacing=resolved_theme.spacing_scale.sm, align=CrossAlign::Start)
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_expanded(expanded~)
  .semantics_description(subtitle)
}

///|
pub fn[Msg] accordion(
  sections : Array[WizardStep[Msg]],
  expanded~ : Array[String],
  on_toggle~ : (String) -> Msg,
  theme? : @core.Theme,
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let rows : Array[@core.View[Msg]] = []
  for section in sections {
    rows.push(
      collapsible_panel(
        section.title,
        content=section.content,
        expanded=string_array_contains(expanded, section.id),
        on_toggle=on_toggle(section.id),
        subtitle=section.subtitle,
        theme=resolved_theme,
        width~,
      ).disabled(disabled=!section.enabled),
    )
  }
  column(rows, spacing=resolved_theme.spacing_scale.sm, align=CrossAlign::Start).semantics_role(
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
  theme? : @core.Theme,
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  container(
    disclosure(
      title,
      content~,
      expanded~,
      on_toggle~,
      subtitle~,
      theme=resolved_theme,
      width=width - resolved_theme.spacing_scale.md * 2.0,
    ),
    width~,
    variant=ContainerVariant::Base,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  ).border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(
        resolved_theme.palette.outline.multiply_alpha(0.64),
      ),
      width=1.0,
    ),
  )
}

///|
pub fn[Msg] resizable_panel(
  content~ : @core.View[Msg],
  size~ : Double,
  theme? : @core.Theme,
  height? : Double = 160.0,
  min_size? : Double = 120.0,
  max_size? : Double = 520.0,
  on_drag? : ((Double) -> Msg)? = None,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let panel_width = disclosure_clamp_double(size, min_size, max_size)
  let handle = container(
    empty(),
    width=8.0,
    height~,
    background=resolved_theme.palette.primary.multiply_alpha(0.38),
    corner_radius=4.0,
    theme=resolved_theme,
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
      container(
        content.frame(
          width=panel_width - resolved_theme.spacing_scale.md * 2.0,
          height=height - resolved_theme.spacing_scale.md * 2.0,
        ),
        width=panel_width,
        height~,
        variant=ContainerVariant::Raised,
        theme=resolved_theme,
        padding=resolved_theme.spacing_scale.md,
      ),
      handle,
    ],
    spacing=resolved_theme.spacing_scale.xs,
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
