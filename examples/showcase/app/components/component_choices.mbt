///|
fn toggle_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  component_demo_section(
    "Toggle",
    "A toggle uses switch semantics while keeping the simple checkbox state shape.",
    column(
      [
        @views.toggle(
          "Sync component samples",
          model.feature_enabled,
          on_change=value => FeatureToggled(value),
          theme~,
          check_color=theme.palette.primary,
        ),
        status_badge(
          if model.feature_enabled {
            "on"
          } else {
            "off"
          },
          tone=if model.feature_enabled {
            @views.BadgeTone::Success
          } else {
            @views.BadgeTone::Neutral
          },
          detail="toggle state",
          theme~,
          width=84.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    theme,
    width,
  )
}

///|
fn radio_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  component_demo_section(
    "Radio",
    "Radio is the single-choice sibling of checkbox.",
    column(
      [
        @views.radio(
          "Canvas mode",
          model.selected_mode == "canvas",
          on_change=_value => SelectMode("canvas"),
          theme~,
          check_color=theme.palette.primary,
        ),
        @views.radio(
          "Runtime mode",
          model.selected_mode == "runtime",
          on_change=_value => SelectMode("runtime"),
          theme~,
          check_color=theme.palette.primary,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    theme,
    width,
  )
}

///|
fn radio_group_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  component_demo_section(
    "Radio Group",
    "A radio group collects related single-choice options.",
    @views.radio_group(
      [
        choice_item("canvas", "Canvas"),
        choice_item("states", "States"),
        choice_item("runtime", "Runtime"),
      ],
      selected=model.selected_mode,
      on_select=value => SelectMode(value),
      theme~,
    ),
    theme,
    width,
  )
}

///|
fn checkbox_group_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let selected = if model.feature_enabled {
    ["desktop", "mobile"]
  } else {
    ["desktop"]
  }
  component_demo_section(
    "Checkbox Group",
    "Checkbox groups model multiple independent selections.",
    @views.checkbox_group(
      [
        choice_item("desktop", "Desktop"),
        choice_item("mobile", "Mobile"),
        choice_item("web", "Web"),
      ],
      selected~,
      on_change=(_id, value) => FeatureToggled(value),
      theme~,
    ),
    theme,
    width,
  )
}

///|
fn chips_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let chip_width = if compact { inner } else { 132.0 }
  component_demo_section(
    "Chips",
    "Use chips for compact filters, tags, and quick choices.",
    responsive_grid(
      [
        @views.chip(
          "Canvas",
          selected=model.selected_mode == "canvas",
          on_click=Some(SelectMode("canvas")),
          theme~,
          width=chip_width,
        ),
        @views.choice_chip(
          "Runtime",
          selected=model.selected_mode == "runtime",
          on_select=SelectMode("runtime"),
          theme~,
          width=chip_width,
        ),
        @views.filter_chip(
          "Mobile",
          selected=model.feature_enabled,
          on_change=value => FeatureToggled(value),
          theme~,
          width=chip_width,
        ),
        @views.tag("Skia", theme~, width=chip_width),
      ],
      width=inner,
      min_column_width=if compact { inner } else { 132.0 },
      row_spacing=theme.spacing_scale.sm,
      column_spacing=theme.spacing_scale.sm,
    ),
    theme,
    width,
  )
}
