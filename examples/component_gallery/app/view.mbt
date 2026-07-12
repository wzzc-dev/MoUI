///|
using @views {
  badge,
  button,
  card,
  checkbox,
  choice_item,
  column,
  container,
  picker,
  picker_item,
  progress_status,
  responsive_grid,
  row,
  scroll_view,
  spacer,
  stat_card,
  status_badge,
  segmented_control,
  text,
  text_field,
}

///|
pub fn view(
  model : ComponentGalleryModel,
  env : @moui.ViewEnvironment,
) -> @moui.View[ComponentGalleryMsg] {
  let theme = @views.light_theme()
  let viewport = env.viewport_size()
  let page_width = responsive_page_width(model.active_platform, viewport.width)
  let page_height = viewport.height.max(1.0)
  let compact = page_width < 820.0
  if compact && model.active_item == ComponentGalleryItemId::MobileServiceProbe {
    let content_width = (page_width - 32.0).max(288.0)
    container(
      scroll_view(
        container(
          column(
            [
              spacer(min_length=44.0),
              column(
                [
                  text(
                    "Component Gallery",
                    role=@views.TextRole::Subtitle,
                    theme~,
                    width=content_width,
                    height=30.0,
                    align=@text.TextAlign::TextStart,
                  ),
                  button(
                    "Browse all components",
                    on_click=SelectItem("welcome"),
                    variant=@views.ButtonVariant::Outline,
                    theme~,
                    width=content_width,
                  ),
                ],
                spacing=theme.spacing_scale.sm,
                align=@views.CrossAlign::Stretch,
              ),
              mobile_service_probe(
                model,
                theme,
                content_width,
                compact,
                height=page_height,
              ),
            ],
            spacing=theme.spacing_scale.md,
            align=@views.CrossAlign::Stretch,
          ),
          width=page_width,
          background=theme.palette.background,
          padding=16.0,
          theme~,
        ),
        width=page_width,
        height=page_height,
        state=Some(model.page_scroll),
      ),
      width=page_width,
      height=page_height,
      background=theme.palette.background,
      padding=0.0,
      theme~,
    )
  } else if compact {
    container(
      scroll_view(
        container(
          gallery_body(model, theme, page_width, page_height, compact),
          width=page_width,
          background=theme.palette.background,
          padding=16.0,
          theme~,
        ),
        width=page_width,
        height=page_height,
        state=Some(model.page_scroll),
      ),
      width=page_width,
      height=page_height,
      background=theme.palette.background,
      padding=0.0,
      theme~,
    )
  } else {
    container(
      gallery_body(model, theme, page_width, page_height, compact),
      width=page_width,
      height=page_height,
      background=theme.palette.background,
      padding=16.0,
      theme~,
    )
  }
}

///|
fn gallery_body(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  page_width : Double,
  page_height : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let content_width = (page_width - 32.0).max(288.0)
  let content_height = (page_height - 32.0).max(240.0)
  if compact {
    column(
      [
        gallery_header(model, theme, content_width, compact),
        mobile_component_index(model, theme, content_width),
        component_workspace(model, theme, content_width, compact),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Stretch,
    )
  } else {
    let gap = theme.spacing_scale.md
    let header_height = 110.0
    let sidebar_width = 270.0
    let main_width = (content_width - sidebar_width - gap).max(420.0)
    let panel_height = (content_height - header_height - gap).max(220.0)
    column(
      [
        gallery_header(model, theme, content_width, compact).frame(
          width=content_width,
          height=header_height,
        ),
        row(
          [
            scroll_view(
              gallery_sidebar(model, theme, sidebar_width),
              width=sidebar_width,
              height=panel_height,
              state=Some(model.sidebar_scroll),
            ),
            scroll_view(
              component_workspace(model, theme, main_width, compact),
              width=main_width,
              height=panel_height,
              state=Some(model.content_scroll),
            ),
          ],
          spacing=gap,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=gap,
      align=@views.CrossAlign::Stretch,
    ).frame(width=content_width, height=content_height)
  }
}

///|
fn gallery_header(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let item = gallery_item_info(model.active_item)
  let inner_width = (width - 32.0).max(256.0)
  let gap = theme.spacing_scale.xs
  let host_badge_width = 128.0
  let item_badge_width = 148.0
  let count_badge_width = 118.0
  let badge_total_width = host_badge_width +
    item_badge_width +
    count_badge_width +
    gap * 2.0
  let title_width = if compact {
    inner_width
  } else {
    (inner_width - badge_total_width - theme.spacing_scale.sm).max(220.0)
  }
  let title_block = column(
    [
      text(
        "Component Gallery",
        role=@views.TextRole::Title,
        theme~,
        width=title_width,
        height=34.0,
        align=@text.TextAlign::TextStart,
      ),
      wrapped_text(
        "Focused MoUI demos for controls, feedback, layout, and runtime routes.",
        role=@views.TextRole::Caption,
        theme~,
        width=title_width,
        height=42.0,
        align=@text.TextAlign::TextStart,
      ),
    ],
    spacing=2.0,
    align=@views.CrossAlign::Stretch,
  )
  let badge_items = [
    status_badge(
      platform_display_name(model.active_platform),
      tone=@views.BadgeTone::Accent,
      detail="host",
      theme~,
      width=host_badge_width,
    ),
    status_badge(
      item.badge,
      tone=item.tone,
      detail=item.group,
      theme~,
      width=item_badge_width,
    ),
    status_badge(
      "\{filtered_gallery_item_count(model.search_query)} demos",
      tone=@views.BadgeTone::Neutral,
      theme~,
      width=count_badge_width,
    ),
  ]
  let badges = if compact {
    responsive_grid(
      badge_items,
      width=inner_width,
      min_column_width=count_badge_width,
      row_spacing=gap,
      column_spacing=gap,
    )
  } else {
    row(badge_items, spacing=gap, align=@views.CrossAlign::Center)
  }
  container(
    if compact {
      column(
        [title_block, badges],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Stretch,
      )
    } else {
      row(
        [title_block, spacer(weight=1.0), badges],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      )
    },
    width~,
    variant=@views.ContainerVariant::Raised,
    padding=16.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn gallery_sidebar(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = width - 28.0
  let rows : Array[@moui.View[ComponentGalleryMsg]] = [
    text(
      "Components",
      role=@views.TextRole::Subtitle,
      theme~,
      width=inner,
      height=28.0,
      align=@text.TextAlign::TextStart,
    ),
    text_field(
      model.search_query,
      on_input=value => SearchChanged(value),
      placeholder="Search components",
      variant=@views.TextFieldVariant::Outline,
      theme~,
      width=inner,
    ),
    status_badge(
      platform_display_name(model.active_platform),
      tone=@views.BadgeTone::Accent,
      detail="active host",
      theme~,
      width=inner,
    ),
  ]
  append_component_gallery_groups(rows, model, theme, inner)
  container(
    column(
      rows,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    variant=@views.ContainerVariant::Raised,
    padding=14.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn mobile_component_index(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let rows : Array[@moui.View[ComponentGalleryMsg]] = [
    text_field(
      model.search_query,
      on_input=value => SearchChanged(value),
      placeholder="Search components",
      variant=@views.TextFieldVariant::Outline,
      theme~,
      width~,
    ),
  ]
  let items = filtered_gallery_items(model.search_query)
  if items.length() == 0 {
    rows.push(
      text(
        "No matching components",
        role=@views.TextRole::Caption,
        theme~,
        width~,
        height=24.0,
        align=@text.TextAlign::TextStart,
      ),
    )
  } else {
    rows.push(
      responsive_grid(
        items.map(item => {
          gallery_nav_button(model, item, theme, (width - 12.0) / 2.0)
        }),
        width~,
        min_column_width=150.0,
        row_spacing=theme.spacing_scale.xs,
        column_spacing=theme.spacing_scale.xs,
      ),
    )
  }
  container(
    column(
      rows,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    variant=@views.ContainerVariant::Raised,
    padding=14.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn append_component_gallery_groups(
  rows : Array[@moui.View[ComponentGalleryMsg]],
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> Unit {
  for group in component_gallery_groups() {
    if gallery_group_has_matches(group.id, model.search_query) {
      rows.push(
        text(
          group.name,
          role=@views.TextRole::Overline,
          theme~,
          width~,
          height=22.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
      )
      for item in component_gallery_items() {
        if item.group == group.id &&
          gallery_item_matches_query(item, model.search_query) {
          rows.push(gallery_nav_button(model, item, theme, width))
        }
      }
    }
  }
}

///|
fn gallery_nav_button(
  model : ComponentGalleryModel,
  item : ComponentGalleryItemInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  button(
    item.name,
    on_click=SelectItem(gallery_item_id_to_string(item.id)),
    variant=if item.id == model.active_item {
      @views.ButtonVariant::Primary
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    width~,
  )
}

///|
fn component_workspace(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let item = gallery_item_info(model.active_item)
  column(
    [
      component_header(model, item, theme, width, compact),
      component_body(model, item.id, theme, width, compact),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn component_header(
  model : ComponentGalleryModel,
  item : ComponentGalleryItemInfo,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let padding = 16.0
  let badge_width = 164.0
  let row_spacing = theme.spacing_scale.sm
  let inner_width = (width - padding * 2.0).max(1.0)
  let title_width = if compact {
    inner_width
  } else {
    (inner_width - badge_width - row_spacing * 2.0).max(1.0)
  }
  let title_block = column(
    [
      text(
        item.name,
        role=@views.TextRole::Headline,
        theme~,
        width=title_width,
        height=34.0,
        align=@text.TextAlign::TextStart,
      ),
      wrapped_text(
        item.description,
        role=@views.TextRole::Body,
        theme~,
        width=title_width,
        height=52.0,
        align=@text.TextAlign::TextStart,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Stretch,
  )
  container(
    if compact {
      column(
        [
          title_block,
          status_badge(
            mode_label(model.selected_mode),
            tone=item.tone,
            detail=item.badge,
            theme~,
            width=badge_width,
          ),
        ],
        spacing=row_spacing,
        align=@views.CrossAlign::Start,
      )
    } else {
      row(
        [
          title_block,
          spacer(weight=1.0),
          status_badge(
            mode_label(model.selected_mode),
            tone=item.tone,
            detail=item.badge,
            theme~,
            width=badge_width,
          ),
        ],
        spacing=row_spacing,
        align=@views.CrossAlign::Center,
      )
    },
    width~,
    variant=@views.ContainerVariant::Raised,
    padding=16.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn responsive_page_width(
  platform : PlatformId,
  viewport_width : Double,
) -> Double {
  match platform {
    PlatformId::Android | PlatformId::IOS | PlatformId::HarmonyOs =>
      viewport_width.max(320.0)
    _ => viewport_width.max(360.0).min(1180.0)
  }
}
