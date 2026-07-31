///|
pub fn[Msg] section_nav(
  title : String,
  items : Array[SectionNavItem[Msg]],
  selected~ : String,
  theme? : @core.Theme,
  width? : Double = 520.0,
  item_width? : Double = 150.0,
  item_height? : Double = 76.0,
  orientation? : @core.Axis = @core.Axis::Horizontal,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let item_padding = resolved_theme.spacing_scale.sm
  let item_content_width = @common.view_max_double(
    72.0,
    item_width - item_padding * 2.0,
  )
  let spacing = resolved_theme.spacing_scale.sm
  let item_views : Array[@core.View[Msg]] = []
  for item in items {
    let selected_item = item.id == selected
    let variant = if selected_item {
      @style.ButtonVariant::Primary
    } else {
      @style.ButtonVariant::Tonal
    }
    let rows : Array[@core.View[Msg]] = [
      @button.button(
        item.label,
        on_click=item.message,
        variant~,
        theme=resolved_theme,
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
        @text.text(
          item.summary,
          role=@style.TextRole::Caption,
          theme=resolved_theme,
          width=item_content_width,
          height=24.0,
        ),
      )
    }
    item_views.push(
      @container.container(
        column(
          rows,
          spacing=resolved_theme.spacing_scale.xs,
          align=@style.CrossAlign::Start,
        ),
        width=item_width,
        height=item_height,
        variant=if selected_item {
          @style.ContainerVariant::Raised
        } else {
          @style.ContainerVariant::Base
        },
        theme=resolved_theme,
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
    @core.Axis::Horizontal =>
      row(item_views, spacing~, align=@style.CrossAlign::Start)
    @core.Axis::Vertical =>
      column(item_views, spacing~, align=@style.CrossAlign::Start)
  }
  let rows : Array[@core.View[Msg]] = []
  let title_height = if title == "" {
    0.0
  } else {
    rows.push(
      @text.text(
        title,
        role=@style.TextRole::Control,
        theme=resolved_theme,
        width=@common.view_max_double(96.0, width - item_padding * 2.0),
        height=28.0,
      ),
    )
    28.0 + spacing
  }
  rows.push(body)
  let gap_count = section_nav_max_int(0, item_views.length() - 1).to_double()
  let body_height = match orientation {
    @core.Axis::Horizontal => item_height
    @core.Axis::Vertical =>
      item_height * item_views.length().to_double() + spacing * gap_count
  }
  @container.container(
    column(rows, spacing~, align=@style.CrossAlign::Start),
    width~,
    height=title_height + body_height + item_padding * 2.0,
    variant=@style.ContainerVariant::Base,
    theme=resolved_theme,
    padding=item_padding,
  )
  .semantics_role(@core.SemanticsRole::List)
  .accessibility_label(if title == "" { "Section navigation" } else { title })
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
fn section_nav_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
