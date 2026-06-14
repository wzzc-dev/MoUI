///|
pub fn[Msg] sidebar(
  title : String,
  items : Array[SidebarItem[Msg]],
  selected~ : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 240.0,
  height? : Double = 320.0,
) -> @core.View[Msg] {
  let inner_width = views_max_double(96.0, width - theme.spacing_scale.md * 2.0)
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=inner_width, height=28.0),
  ]
  for item in items {
    let variant = if item.id == selected {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Ghost
    }
    rows.push(
      button(
        item.label,
        on_click=item.message,
        variant~,
        theme~,
        width=inner_width,
        height=34.0,
      )
      .disabled(disabled=!item.enabled)
      .semantics_selected(selected=item.id == selected)
      .key("sidebar-item-" + item.id),
    )
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::List)
}

///|
pub fn[Msg] section_nav(
  title : String,
  items : Array[SectionNavItem[Msg]],
  selected~ : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  item_width? : Double = 150.0,
  item_height? : Double = 76.0,
  orientation? : @core.Axis = @core.Axis::Horizontal,
) -> @core.View[Msg] {
  let item_padding = theme.spacing_scale.sm
  let item_content_width = views_max_double(
    72.0,
    item_width - item_padding * 2.0,
  )
  let spacing = theme.spacing_scale.sm
  let item_views : Array[@core.View[Msg]] = []
  for item in items {
    let selected_item = item.id == selected
    let variant = if selected_item {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Tonal
    }
    let rows : Array[@core.View[Msg]] = [
      button(
        item.label,
        on_click=item.message,
        variant~,
        theme~,
        width=item_content_width,
        height=34.0,
      )
      .disabled(disabled=!item.enabled)
      .semantics_role(@core.SemanticsRole::Tab)
      .semantics_selected(selected=selected_item)
      .key("section-nav-button-" + item.id),
    ]
    if item.summary != "" {
      rows.push(
        text(
          item.summary,
          role=TextRole::Caption,
          theme~,
          width=item_content_width,
          height=24.0,
        ),
      )
    }
    item_views.push(
      surface(
        column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
        width=item_width,
        height=item_height,
        variant=if selected_item {
          SurfaceVariant::Raised
        } else {
          SurfaceVariant::Base
        },
        theme~,
        padding=item_padding,
      )
      .disabled(disabled=!item.enabled)
      .semantics_role(@core.SemanticsRole::ListItem)
      .semantics_selected(selected=selected_item)
      .accessibility_label(section_nav_item_accessibility_label(item))
      .key("section-nav-item-" + item.id),
    )
  }
  let body = match orientation {
    @core.Axis::Horizontal => row(item_views, spacing~, align=CrossAlign::Start)
    @core.Axis::Vertical =>
      column(item_views, spacing~, align=CrossAlign::Start)
  }
  let rows : Array[@core.View[Msg]] = []
  let title_height = if title == "" {
    0.0
  } else {
    rows.push(
      text(
        title,
        role=TextRole::Control,
        theme~,
        width=views_max_double(96.0, width - item_padding * 2.0),
        height=28.0,
      ),
    )
    28.0 + spacing
  }
  rows.push(body)
  let gap_count = navigation_shell_max_int(0, item_views.length() - 1).to_double()
  let body_height = match orientation {
    @core.Axis::Horizontal => item_height
    @core.Axis::Vertical =>
      item_height * item_views.length().to_double() + spacing * gap_count
  }
  surface(
    column(rows, spacing~, align=CrossAlign::Start),
    width~,
    height=title_height + body_height + item_padding * 2.0,
    variant=SurfaceVariant::Base,
    theme~,
    padding=item_padding,
  )
  .semantics_role(@core.SemanticsRole::List)
  .accessibility_label(if title == "" { "Section navigation" } else { title })
}

///|
pub fn[Msg] breadcrumb(
  items : Array[BreadcrumbItem[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  spacing? : Double = @core.Theme::default().spacing_scale.xs,
) -> @core.View[Msg] {
  let children : Array[@core.View[Msg]] = []
  for index, item in items {
    if index > 0 {
      children.push(
        text("/", role=TextRole::Caption, theme~, width=14.0, height=28.0),
      )
    }
    let child : @core.View[Msg] = match item.message {
      Some(message) =>
        button(
          item.label,
          on_click=message,
          variant=ButtonVariant::Ghost,
          theme~,
          width=breadcrumb_item_width(item.label),
          height=30.0,
        )
      None =>
        text(
          item.label,
          role=TextRole::Control,
          theme~,
          width=breadcrumb_item_width(item.label),
          height=30.0,
        )
    }
    children.push(child.key("breadcrumb-item-" + item.id))
  }
  row(children, spacing~, align=CrossAlign::Center).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
pub fn[Msg] route_header(
  title : String,
  subtitle? : String = "",
  actions? : Array[MenuItem[Msg]] = [],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
) -> @core.View[Msg] {
  let padding = theme.spacing_scale.md
  let content_width = views_max_double(120.0, width - padding * 2.0)
  let mut actions_width = 0.0
  for action in actions {
    actions_width = actions_width + route_header_action_width(action.label)
  }
  if actions.length() > 1 {
    actions_width = actions_width +
      theme.spacing_scale.xs * (actions.length() - 1).to_double()
  }
  let title_width = views_max_double(
    120.0,
    content_width - actions_width - theme.spacing_scale.md,
  )
  let title_rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=title_width, height=28.0),
  ]
  if subtitle != "" {
    title_rows.push(
      text(
        subtitle,
        role=TextRole::Caption,
        theme~,
        width=title_width,
        height=24.0,
      ),
    )
  }
  let action_buttons : Array[@core.View[Msg]] = []
  for action in actions {
    action_buttons.push(
      button(
        action.label,
        on_click=action.message,
        variant=ButtonVariant::Tonal,
        theme~,
        width=route_header_action_width(action.label),
        height=34.0,
      ).disabled(disabled=!action.enabled),
    )
  }
  let children : Array[@core.View[Msg]] = [
    column(title_rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
  ]
  if action_buttons.length() > 0 {
    children.push(
      row(
        action_buttons,
        spacing=theme.spacing_scale.xs,
        align=CrossAlign::Center,
      ),
    )
  }
  surface(
    row(
      children,
      spacing=theme.spacing_scale.md,
      justify=MainAlign::Between,
      align=CrossAlign::Center,
    ),
    width~,
    height=if subtitle == "" { 58.0 } else { 78.0 },
    variant=SurfaceVariant::Base,
    theme~,
    padding~,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label(title)
}

///|
fn breadcrumb_item_width(label : String) -> Double {
  views_max_double(42.0, label.to_array().length().to_double() * 8.0 + 24.0)
}

///|
fn route_header_action_width(label : String) -> Double {
  views_max_double(76.0, label.to_array().length().to_double() * 8.0 + 24.0)
}

///|
fn[Msg] section_nav_item_accessibility_label(
  item : SectionNavItem[Msg],
) -> String {
  if item.summary == "" {
    item.label
  } else {
    item.label + ", " + item.summary
  }
}

///|
fn navigation_shell_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
