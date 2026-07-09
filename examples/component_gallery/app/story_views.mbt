///|
fn story_body(
  model : ComponentGalleryModel,
  story : ComponentGalleryStoryId,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  match story {
    ComponentGalleryStoryId::Welcome =>
      welcome_story(model, theme, width, compact)
    ComponentGalleryStoryId::Buttons =>
      buttons_story(model, theme, width, compact)
    ComponentGalleryStoryId::Inputs =>
      inputs_story(model, theme, width, compact)
    ComponentGalleryStoryId::Feedback =>
      feedback_story(model, theme, width, compact)
    ComponentGalleryStoryId::Layout =>
      layout_story(model, theme, width, compact)
    ComponentGalleryStoryId::Platforms =>
      platforms_story(model, theme, width, compact)
  }
}

///|
fn welcome_story(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  column(
    [
      story_section(
        "Story Browser",
        "A reusable shared app package powers every host route.",
        column(
          [
            wrapped_text(
              "Component Gallery groups MoUI controls into focused stories. The same model/update/view app is rendered by desktop Skia, mobile embedded sessions, and Web wasm-gc.",
              role=@views.TextRole::Body,
              theme~,
              width=section_inner_width(width),
              height=72.0,
              align=@text.TextAlign::TextStart,
            ),
            welcome_summary_badges(model, theme, section_inner_width(width)),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Stretch,
        ),
        theme,
        width,
      ),
      story_section(
        "Runtime Targets",
        "Six entrypoints stay thin while the gallery content remains shared.",
        platform_badge_grid(model, theme, section_inner_width(width), compact),
        theme,
        width,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn buttons_story(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  column(
    [
      story_section(
        "Variants",
        "Primary actions, secondary surfaces, outlines, and quiet navigation buttons.",
        responsive_grid(
          [
            button(
              "Primary",
              on_click=Increment,
              variant=@views.ButtonVariant::Primary,
              theme~,
              width=128.0,
            ),
            button(
              "Tonal",
              on_click=Increment,
              variant=@views.ButtonVariant::Tonal,
              theme~,
              width=128.0,
            ),
            button(
              "Outline",
              on_click=Increment,
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=128.0,
            ),
            button(
              "Ghost",
              on_click=Increment,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=128.0,
            ),
            button(
              "Subtle",
              on_click=Increment,
              variant=@views.ButtonVariant::Subtle,
              theme~,
              width=128.0,
            ),
          ],
          width=inner,
          min_column_width=if compact { 128.0 } else { 124.0 },
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        theme,
        width,
      ),
      story_section(
        "Actions",
        "The story uses the normal TEA update loop, so every host exercises the same state path.",
        action_counter_panel(model, theme, inner, compact),
        theme,
        width,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn inputs_story(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  _compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  story_section(
    "Form Controls",
    "Inputs share app-owned state and resize across mobile and desktop routes.",
    column(
      [
        text_field(
          model.sample_text,
          on_input=value => SampleTextChanged(value),
          placeholder="Story label",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=inner,
        ),
        segmented_control(
          [
            choice_item("canvas", "Canvas"),
            choice_item("states", "States"),
            choice_item("runtime", "Runtime"),
          ],
          selected=model.selected_mode,
          on_select=value => SelectMode(value),
          size=@views.SegmentedControlSize::Regular,
          theme~,
          width=inner,
        ),
        picker(
          [
            picker_item("compact", "Compact density"),
            picker_item("regular", "Regular density"),
            picker_item("comfortable", "Comfortable density"),
          ],
          selected=model.selected_density,
          on_select=value => SelectDensity(value),
          placeholder="Density",
          theme~,
        ).frame(width=inner, height=40.0),
        checkbox(
          "Enable mobile shell checks",
          checked=model.feature_enabled,
          on_change=value => FeatureToggled(value),
          theme~,
          check_color=theme.palette.primary,
        ),
        text(
          "Control value: \{score_label(model)}",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=22.0,
          align=@text.TextAlign::TextStart,
        ),
        @views.slider(
          model.slider_value,
          width=inner,
          foreground=theme.palette.primary,
          on_change=Some(value => SliderChanged(value)),
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    theme,
    width,
  )
}

///|
fn feedback_story(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let card_width = if compact {
    inner
  } else {
    (inner - theme.spacing_scale.md * 2.0) / 3.0
  }
  column(
    [
      story_section(
        "Status",
        "Badges and progress components provide compact runtime evidence.",
        column(
          [
            row(
              [
                status_badge(
                  "ready",
                  tone=@views.BadgeTone::Success,
                  theme~,
                  width=96.0,
                ),
                status_badge(
                  "active",
                  tone=@views.BadgeTone::Accent,
                  theme~,
                  width=96.0,
                ),
                status_badge(
                  "review",
                  tone=@views.BadgeTone::Warning,
                  theme~,
                  width=96.0,
                ),
                status_badge(
                  "idle",
                  tone=@views.BadgeTone::Neutral,
                  theme~,
                  width=96.0,
                ),
              ],
              spacing=theme.spacing_scale.xs,
              align=@views.CrossAlign::Center,
            ),
            progress_status(
              "Control coverage",
              value=model.slider_value,
              message=if model.feature_enabled {
                "Mobile shells included"
              } else {
                "Desktop and Web only"
              },
              status=score_label(model),
              tone=feedback_tone(model),
              theme~,
              width=inner,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Stretch,
        ),
        theme,
        width,
      ),
      responsive_grid(
        [
          stat_card(
            "Stories",
            "\{component_gallery_stories().length()}",
            caption="grouped examples",
            tone=@views.FeedbackTone::Info,
            theme~,
            width=card_width,
          ),
          stat_card(
            "Hosts",
            "6",
            caption="native, mobile, web",
            tone=@views.FeedbackTone::Success,
            theme~,
            width=card_width,
          ),
          stat_card(
            "Counter",
            "\{model.counter}",
            caption="shared update state",
            tone=@views.FeedbackTone::Warning,
            theme~,
            width=card_width,
          ),
        ],
        width~,
        min_column_width=if compact { inner } else { 190.0 },
        row_spacing=theme.spacing_scale.md,
        column_spacing=theme.spacing_scale.md,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn layout_story(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  story_section(
    "Adaptive Surfaces",
    "The gallery switches from sidebar workspace to compact index while preserving story state.",
    column(
      [
        responsive_grid(
          [
            layout_tile(
              "Sidebar",
              if compact {
                "stacked"
              } else {
                "visible"
              },
              theme,
              tile_width(inner, compact),
            ),
            layout_tile(
              "Content",
              mode_label(model.selected_mode),
              theme,
              tile_width(inner, compact),
            ),
            layout_tile(
              "Density",
              density_label(model.selected_density),
              theme,
              tile_width(inner, compact),
            ),
            layout_tile("Scroll", "stateful", theme, tile_width(inner, compact)),
          ],
          width=inner,
          min_column_width=if compact { inner } else { 150.0 },
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        text(
          "Active width mode: \{if compact { "compact" } else { "desktop" }}",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=24.0,
          align=@text.TextAlign::TextStart,
        ),
      ],
      spacing=story_spacing(model, theme),
      align=@views.CrossAlign::Stretch,
    ),
    theme,
    width,
  )
}

///|
fn platforms_story(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let card_width = if compact { inner } else { 300.0 }
  story_section(
    "Platform Routes",
    "Each card points at a thin entrypoint that launches the same Component Gallery program.",
    responsive_grid(
      platform_runtime_infos().map(info => {
        platform_route_card(model, info, theme, card_width)
      }),
      width=inner,
      min_column_width=if compact { inner } else { 280.0 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    theme,
    width,
  )
}

///|
fn platform_badge_grid(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let spacing = theme.spacing_scale.sm
  let min_column_width = if compact { width } else { 168.0 }
  let columns = gallery_grid_columns(width, min_column_width, spacing)
  let chip_width = gallery_grid_column_width(width, columns, spacing)
  responsive_grid(
    platform_runtime_infos().map(info => {
      platform_chip(model, info, theme, chip_width)
    }),
    width~,
    min_column_width~,
    row_spacing=spacing,
    column_spacing=spacing,
  )
}

///|
fn welcome_summary_badges(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let spacing = theme.spacing_scale.xs
  let min_column_width = 126.0
  let columns = gallery_grid_columns(width, min_column_width, spacing)
  let badge_width = gallery_grid_column_width(width, columns, spacing)
  responsive_grid(
    [
      status_badge(
        platform_display_name(model.active_platform),
        tone=@views.BadgeTone::Accent,
        detail="active host",
        theme~,
        width=badge_width,
      ),
      status_badge(
        "\{component_gallery_stories().length()} stories",
        tone=@views.BadgeTone::Neutral,
        detail="catalog",
        theme~,
        width=badge_width,
      ),
      status_badge(
        density_label(model.selected_density),
        tone=@views.BadgeTone::Neutral,
        detail="density",
        theme~,
        width=badge_width,
      ),
    ],
    width~,
    min_column_width~,
    row_spacing=spacing,
    column_spacing=spacing,
  )
}

///|
fn platform_chip(
  model : ComponentGalleryModel,
  info : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let active = info.id == model.active_platform
  let padding = 10.0
  let badge_width = 76.0
  let gap = theme.spacing_scale.xs
  let content_width = (width - padding * 2.0).max(1.0)
  let label_width = (content_width - badge_width - gap).max(1.0)
  container(
    row(
      [
        text(
          info.name,
          role=@views.TextRole::Control,
          theme~,
          width=label_width,
          height=24.0,
          align=@text.TextAlign::TextStart,
        ),
        spacer(weight=1.0),
        status_badge(
          if active {
            "host"
          } else {
            info.status
          },
          tone=if active { @views.BadgeTone::Accent } else { info.badge_tone },
          theme~,
          width=badge_width,
        ),
      ],
      spacing=gap,
      align=@views.CrossAlign::Center,
    ),
    width~,
    variant=@views.ContainerVariant::Base,
    background=theme.palette.surface_variant.multiply_alpha(0.45),
    padding~,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn action_counter_panel(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let label = text(
    "Count: \{model.counter}",
    role=@views.TextRole::Subtitle,
    theme~,
    width=if compact { width } else { (width - 220.0).max(180.0) },
    height=30.0,
    align=@text.TextAlign::TextStart,
  )
  let controls = row(
    [
      button(
        "-",
        on_click=Decrement,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=52.0,
      ),
      button(
        "Reset",
        on_click=Reset,
        variant=@views.ButtonVariant::Tonal,
        theme~,
        width=92.0,
      ),
      button(
        "+",
        on_click=Increment,
        variant=@views.ButtonVariant::Primary,
        theme~,
        width=52.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
  if compact {
    column(
      [label, controls],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    )
  } else {
    row(
      [label, spacer(weight=1.0), controls],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    )
  }
}

///|
fn platform_route_card(
  model : ComponentGalleryModel,
  info : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let selected = info.id == model.selected_platform
  let active = info.id == model.active_platform
  let border_color = if selected {
    theme.palette.primary
  } else {
    theme.palette.outline.multiply_alpha(0.5)
  }
  let inner = width - 28.0
  container(
    column(
      [
        row(
          [
            text(
              info.name,
              role=@views.TextRole::Subtitle,
              theme~,
              width=(inner - 104.0).max(130.0),
              height=28.0,
              align=@text.TextAlign::TextStart,
            ),
            spacer(weight=1.0),
            status_badge(
              if active {
                "host"
              } else {
                info.status
              },
              tone=if active {
                @views.BadgeTone::Accent
              } else {
                info.badge_tone
              },
              theme~,
              width=92.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
        wrapped_text(
          info.route,
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=36.0,
          align=@text.TextAlign::TextStart,
        ),
        wrapped_text(
          info.command,
          role=@views.TextRole::Mono,
          theme~,
          width=inner,
          height=44.0,
          align=@text.TextAlign::TextStart,
        ),
        progress_status(
          "Evidence",
          value=info.progress,
          status=info.status,
          tone=info.tone,
          theme~,
          width=inner,
        ),
        button(
          "Select",
          on_click=SelectPlatform(platform_id_to_string(info.id)),
          variant=if selected {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Tonal
          },
          theme~,
          width=112.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=244.0,
    variant=@views.ContainerVariant::Raised,
    padding=14.0,
    corner_radius=8.0,
    theme~,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border_color),
      width=if selected { 2.0 } else { 1.0 },
    ),
  )
}

///|
fn layout_tile(
  title : String,
  value : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  container(
    column(
      [
        text(
          title,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
          height=22.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
        text(
          value,
          role=@views.TextRole::Subtitle,
          theme~,
          width=width - 24.0,
          height=28.0,
          align=@text.TextAlign::TextStart,
        ),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=76.0,
    variant=@views.ContainerVariant::Base,
    background=theme.palette.surface_variant.multiply_alpha(0.48),
    padding=12.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn story_section(
  title : String,
  detail : String,
  body : @moui.View[ComponentGalleryMsg],
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  container(
    column(
      [
        column(
          [
            text(
              title,
              role=@views.TextRole::Subtitle,
              theme~,
              width=inner,
              height=28.0,
              align=@text.TextAlign::TextStart,
            ),
            wrapped_text(
              detail,
              role=@views.TextRole::Caption,
              theme~,
              width=inner,
              height=42.0,
              align=@text.TextAlign::TextStart,
            ).foreground(theme.palette.muted),
          ],
          spacing=2.0,
          align=@views.CrossAlign::Stretch,
        ),
        body,
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    variant=@views.ContainerVariant::Raised,
    padding=16.0,
    corner_radius=8.0,
    theme~,
  )
}

///|
fn section_inner_width(width : Double) -> Double {
  (width - 32.0).max(256.0)
}

///|
fn tile_width(width : Double, compact : Bool) -> Double {
  if compact {
    width
  } else {
    (width - 24.0) / 2.0
  }
}

///|
fn story_spacing(model : ComponentGalleryModel, theme : @moui.Theme) -> Double {
  match model.selected_density {
    "compact" => theme.spacing_scale.xs
    "comfortable" => theme.spacing_scale.lg
    _ => theme.spacing_scale.sm
  }
}

///|
fn mode_label(id : String) -> String {
  match id {
    "canvas" => "Canvas"
    "states" => "States"
    "runtime" => "Runtime"
    _ => "Canvas"
  }
}

///|
fn density_label(id : String) -> String {
  match id {
    "compact" => "Compact"
    "regular" => "Regular"
    "comfortable" => "Comfortable"
    _ => "Regular"
  }
}

///|
fn score_label(model : ComponentGalleryModel) -> String {
  "\{(model.slider_value * 100.0).round().to_int()}%"
}

///|
fn feedback_tone(model : ComponentGalleryModel) -> @views.FeedbackTone {
  if model.slider_value >= 0.82 {
    @views.FeedbackTone::Success
  } else if model.slider_value >= 0.48 {
    @views.FeedbackTone::Info
  } else {
    @views.FeedbackTone::Warning
  }
}
