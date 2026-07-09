///|
using @views {
  button,
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
  let compact = page_width < 820.0
  container(
    scroll_view(
      container(
        gallery_body(model, theme, page_width, compact),
        width=page_width,
        background=theme.palette.background,
        padding=16.0,
        theme~,
      ),
      width=page_width,
      height=viewport.height.max(1.0),
      state=Some(model.page_scroll),
    ),
    width=page_width,
    height=viewport.height.max(1.0),
    background=theme.palette.background,
    padding=0.0,
    theme~,
  )
}

///|
fn gallery_body(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  page_width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let content_width = (page_width - 32.0).max(288.0)
  let header = gallery_header(model, theme, content_width, compact)
  if compact {
    column(
      [
        header,
        mobile_story_index(model, theme, content_width),
        story_workspace(model, theme, content_width, compact),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Stretch,
    )
  } else {
    let gap = theme.spacing_scale.md
    let sidebar_width = 270.0
    let main_width = (content_width - sidebar_width - gap).max(420.0)
    column(
      [
        header,
        row(
          [
            story_sidebar(model, theme, sidebar_width),
            story_workspace(model, theme, main_width, compact),
          ],
          spacing=gap,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Stretch,
    )
  }
}

///|
fn gallery_header(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let story = story_info(model.active_story)
  let inner_width = (width - 32.0).max(256.0)
  let gap = theme.spacing_scale.xs
  let host_badge_width = 128.0
  let story_badge_width = 148.0
  let count_badge_width = 118.0
  let badge_total_width = host_badge_width +
    story_badge_width +
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
        "Grouped MoUI component stories running on macOS, Linux, Windows, Android, iOS, and Web.",
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
      story.badge,
      tone=story.tone,
      detail=story.group,
      theme~,
      width=story_badge_width,
    ),
    status_badge(
      "\{filtered_story_count(model.search_query)} stories",
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
fn story_sidebar(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = width - 28.0
  let rows : Array[@moui.View[ComponentGalleryMsg]] = [
    text(
      "Stories",
      role=@views.TextRole::Subtitle,
      theme~,
      width=inner,
      height=28.0,
      align=@text.TextAlign::TextStart,
    ),
    text_field(
      model.search_query,
      on_input=value => SearchChanged(value),
      placeholder="Search stories",
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
  append_story_groups(rows, model, theme, inner)
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
fn mobile_story_index(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let rows : Array[@moui.View[ComponentGalleryMsg]] = [
    text_field(
      model.search_query,
      on_input=value => SearchChanged(value),
      placeholder="Search stories",
      variant=@views.TextFieldVariant::Outline,
      theme~,
      width~,
    ),
  ]
  let stories = filtered_stories(model.search_query)
  if stories.length() == 0 {
    rows.push(
      text(
        "No matching stories",
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
        stories.map(story => {
          story_nav_button(model, story, theme, (width - 12.0) / 2.0)
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
fn append_story_groups(
  rows : Array[@moui.View[ComponentGalleryMsg]],
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> Unit {
  for group in story_groups() {
    if story_group_has_matches(group.id, model.search_query) {
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
      rows.push(
        wrapped_text(
          group.detail,
          role=@views.TextRole::Caption,
          theme~,
          width~,
          height=38.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
      )
      for story in component_gallery_stories() {
        if story.group == group.id &&
          story_matches_query(story, model.search_query) {
          rows.push(story_nav_button(model, story, theme, width))
        }
      }
    }
  }
}

///|
fn story_nav_button(
  model : ComponentGalleryModel,
  story : ComponentGalleryStoryInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  button(
    story.name,
    on_click=SelectStory(story_id_to_string(story.id)),
    variant=if story.id == model.active_story {
      @views.ButtonVariant::Primary
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    width~,
  )
}

///|
fn story_workspace(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let story = story_info(model.active_story)
  column(
    [
      story_header(model, story, theme, width, compact),
      story_body(model, story.id, theme, width, compact),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn story_header(
  model : ComponentGalleryModel,
  story : ComponentGalleryStoryInfo,
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
        story.name,
        role=@views.TextRole::Headline,
        theme~,
        width=title_width,
        height=34.0,
        align=@text.TextAlign::TextStart,
      ),
      wrapped_text(
        story.description,
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
            tone=story.tone,
            detail=story.badge,
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
            tone=story.tone,
            detail=story.badge,
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
    PlatformId::Android | PlatformId::IOS => viewport_width.max(320.0)
    _ => viewport_width.max(360.0).min(1180.0)
  }
}
