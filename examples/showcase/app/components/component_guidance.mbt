///|
fn banner_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Banner",
    "Banners are prominent messages that still live inline with content.",
    @views.banner(
      "Build ready",
      "The Component Gallery app package passed focused checks.",
      tone=@views.FeedbackTone::Success,
      action=Some(@views.StateViewAction::new(label="Reset", message=Reset)),
      theme~,
      width=inner,
    ),
    theme,
    width,
  )
}

///|
fn callout_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let card_width = if compact { inner } else { (inner - 12.0) / 2.0 }
  component_demo_section(
    "Callout",
    "Callouts provide nearby guidance without taking over the page.",
    responsive_grid(
      [
        @views.callout(
          "Tip",
          "Keep component examples short and direct.",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=card_width,
        ),
        @views.callout(
          "Check",
          "Use focused package checks before packaging.",
          tone=@views.FeedbackTone::Warning,
          theme~,
          width=card_width,
        ),
      ],
      width=inner,
      min_column_width=card_width,
      row_spacing=theme.spacing_scale.sm,
      column_spacing=theme.spacing_scale.sm,
    ),
    theme,
    width,
  )
}

///|
fn state_panel_demo(
  _model : ComponentGalleryModel,
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
    "State Panel",
    "Workflow states keep loading, empty, and error surfaces consistent.",
    responsive_grid(
      [
        @views.empty_state(
          "No selection",
          "Choose a component from the catalog.",
          action=Some(@views.StateViewAction::new(label="Reset", message=Reset)),
          theme~,
          width=card_width,
        ),
        @views.loading_state(
          title="Loading",
          message="Preparing component preview.",
          theme~,
          width=card_width,
        ),
        @views.error_state(
          "Unavailable",
          "This demo uses local app state only.",
          action=Some(@views.StateViewAction::new(label="Retry", message=Reset)),
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

///|
fn inline_error_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Inline Error",
    "Inline errors sit close to the control or workflow they describe.",
    @views.inline_error(
      "Component name is required.",
      action=Some(@views.StateViewAction::new(label="Reset", message=Reset)),
      theme~,
      width=inner,
    ),
    theme,
    width,
  )
}

///|
fn toast_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let toast_width = if compact { inner } else { (inner - 12.0) / 2.0 }
  component_demo_section(
    "Toast",
    "Toast surfaces are transient notices owned by app state.",
    responsive_grid(
      [
        @views.toast(
          "Saved component settings.",
          tone=@views.FeedbackTone::Success,
          theme~,
          width=toast_width,
        ),
        @views.toast(
          "Renderer fallback active.",
          tone=@views.FeedbackTone::Warning,
          action=Some(@views.StateViewAction::new(label="Reset", message=Reset)),
          theme~,
          width=toast_width,
        ),
      ],
      width=inner,
      min_column_width=toast_width,
      row_spacing=theme.spacing_scale.sm,
      column_spacing=theme.spacing_scale.sm,
    ),
    theme,
    width,
  )
}

///|
fn snackbar_demo(
  _model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Snackbar",
    "Snackbars are short action messages at the edge of a workflow.",
    @views.snackbar(
      "Component copied",
      action=Some(@views.StateViewAction::new(label="Undo", message=Reset)),
      theme~,
      width=inner,
    ),
    theme,
    width,
  )
}
