///|
pub fn[Msg] toolbar(
  children : Array[@core.View[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 48.0,
) -> @core.View[Msg] {
  surface(
    row(children, spacing=theme.spacing_scale.sm, align=CrossAlign::Center),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] button_group(
  items : Array[MenuItem[Msg]],
  selected? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  button_width? : Double = 88.0,
  height? : Double = 36.0,
) -> @core.View[Msg] {
  let buttons : Array[@core.View[Msg]] = []
  for item in items {
    let variant = if item.id == selected {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Outline
    }
    buttons.push(
      button(item.label, on_click=item.message, variant~, theme~, width=button_width, height~)
      .disabled(disabled=!item.enabled),
    )
  }
  row(buttons, spacing=0.0, align=CrossAlign::Center).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
pub fn[Msg] command_bar(
  items : Array[MenuItem[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 48.0,
) -> @core.View[Msg] {
  let commands : Array[@core.View[Msg]] = []
  for item in items {
    commands.push(
      button(
        item.label,
        on_click=item.message,
        variant=ButtonVariant::Ghost,
        theme~,
        width=command_item_width(item.label),
        height=36.0,
      ).disabled(disabled=!item.enabled),
    )
  }
  toolbar(commands, theme~, width~, height~)
}

///|
pub fn[Msg] status_bar(
  items : Array[String],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 30.0,
) -> @core.View[Msg] {
  let segments : Array[@core.View[Msg]] = []
  for item in items {
    segments.push(text(item, role=TextRole::Caption, theme~, width=command_item_width(item), height=22.0))
  }
  surface(
    row(segments, spacing=theme.spacing_scale.sm, align=CrossAlign::Center),
    width~,
    height~,
    background=theme.palette.surface_variant.multiply_alpha(0.52),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.xs,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] disclosure(
  title : String,
  content~ : @core.View[Msg],
  expanded~ : Bool,
  on_toggle~ : Msg,
  subtitle? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let title_width = views_max_double(80.0, width - 54.0)
  let title_rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=title_width, height=24.0),
  ]
  if subtitle != "" {
    title_rows.push(text(subtitle, role=TextRole::Caption, theme~, width=title_width, height=22.0))
  }
  let header = row(
    [
      button(if expanded { "v" } else { ">" }, on_click=on_toggle, variant=ButtonVariant::Ghost, theme~, width=34.0, height=34.0),
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
}

///|
pub fn[Msg] accordion(
  sections : Array[WizardStep[Msg]],
  expanded~ : Array[String],
  on_toggle~ : (String) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
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
  column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start)
  .semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] collapsible_panel(
  title : String,
  content~ : @core.View[Msg],
  expanded~ : Bool,
  on_toggle~ : Msg,
  subtitle? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 420.0,
) -> @core.View[Msg] {
  surface(
    disclosure(title, content~, expanded~, on_toggle~, subtitle~, theme~, width=width - theme.spacing_scale.md * 2.0),
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
  theme? : @core.Theme = @core.Theme::default(),
  height? : Double = 160.0,
  min_size? : Double = 120.0,
  max_size? : Double = 520.0,
) -> @core.View[Msg] {
  let panel_width = toolbar_clamp_double(size, min_size, max_size)
  row(
    [
      surface(
        content.frame(width=panel_width - theme.spacing_scale.md * 2.0, height=height - theme.spacing_scale.md * 2.0),
        width=panel_width,
        height~,
        variant=SurfaceVariant::Raised,
        theme~,
        padding=theme.spacing_scale.md,
      ),
      surface(
        empty(),
        width=8.0,
        height~,
        background=theme.palette.primary.multiply_alpha(0.38),
        corner_radius=4.0,
        theme~,
        padding=0.0,
      ).accessibility_label("Resize handle"),
    ],
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Start,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
fn command_item_width(label : String) -> Double {
  views_max_double(54.0, label.to_array().length().to_double() * 8.0 + 24.0)
}

///|
fn toolbar_clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

