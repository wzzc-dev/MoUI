///|
fn badge_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let badge_width = if compact { inner } else { 112.0 }
  component_demo_section(
    "Badge",
    "Use badges for short metadata and status labels.",
    responsive_grid(
      [
        badge(
          "neutral",
          tone=@views.BadgeTone::Neutral,
          theme~,
          width=badge_width,
        ),
        badge(
          "accent",
          tone=@views.BadgeTone::Accent,
          theme~,
          width=badge_width,
        ),
        status_badge(
          "success",
          tone=@views.BadgeTone::Success,
          detail="ready state",
          theme~,
          width=badge_width,
        ),
        status_badge(
          "warning",
          tone=@views.BadgeTone::Warning,
          detail="review state",
          theme~,
          width=badge_width,
        ),
        status_badge(
          "danger",
          tone=@views.BadgeTone::Danger,
          detail="blocked state",
          theme~,
          width=badge_width,
        ),
      ],
      width=inner,
      min_column_width=badge_width,
      row_spacing=theme.spacing_scale.sm,
      column_spacing=theme.spacing_scale.sm,
    ),
    theme,
    width,
  )
}

///|
fn progress_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Progress Status",
    "A status panel combines title, badge, progress bar, and supporting text.",
    column(
      [
        progress_status(
          "Component coverage",
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
fn stat_card_demo(
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
  component_demo_section(
    "Stat Card",
    "Metric cards keep dashboard summaries scannable.",
    responsive_grid(
      [
        stat_card(
          "Components",
          "\{component_gallery_items().length()}",
          caption="catalog entries",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=card_width,
        ),
        stat_card(
          "Hosts",
          "6",
          caption="shared app routes",
          tone=@views.FeedbackTone::Success,
          theme~,
          width=card_width,
        ),
        stat_card(
          "Counter",
          "\{model.counter}",
          caption="update state",
          tone=@views.FeedbackTone::Warning,
          theme~,
          width=card_width,
        ),
      ],
      width=inner,
      min_column_width=card_width,
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    theme,
    width,
  )
}
