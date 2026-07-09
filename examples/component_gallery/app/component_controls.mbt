///|
fn button_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  column(
    [
      component_demo_section(
        "Variants",
        "Primary actions, tonal actions, outlines, and quiet buttons.",
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
          min_column_width=128.0,
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        theme,
        width,
      ),
      component_demo_section(
        "State",
        "Clicks flow through the shared update function.",
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
fn text_field_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Text Field",
    "A controlled single-line input with the value stored in the gallery model.",
    column(
      [
        text_field(
          model.sample_text,
          on_input=value => SampleTextChanged(value),
          placeholder="Component label",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=inner,
        ),
        wrapped_text(
          "Value: " + model.sample_text,
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=36.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    theme,
    width,
  )
}

///|
fn checkbox_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Checkbox",
    "A boolean control for opt-in settings and lightweight filters.",
    column(
      [
        checkbox(
          "Enable mobile shell checks",
          checked=model.feature_enabled,
          on_change=value => FeatureToggled(value),
          theme~,
          check_color=theme.palette.primary,
        ),
        status_badge(
          if model.feature_enabled {
            "enabled"
          } else {
            "disabled"
          },
          tone=if model.feature_enabled {
            @views.BadgeTone::Success
          } else {
            @views.BadgeTone::Neutral
          },
          detail="checkbox state",
          theme~,
          width=112.0,
        ),
        wrapped_text(
          "Checkbox labels stay in normal layout, so a demo can add supporting copy around the control.",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=38.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    theme,
    width,
  )
}

///|
fn segmented_control_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Segmented Control",
    "Use a segmented control when all choices are visible and mutually exclusive.",
    column(
      [
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
        status_badge(
          mode_label(model.selected_mode),
          tone=@views.BadgeTone::Accent,
          detail="selected segment",
          theme~,
          width=128.0,
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
fn picker_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Picker",
    "A compact selector for choices that do not need to stay visible.",
    column(
      [
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
        wrapped_text(
          "Current density: " + density_label(model.selected_density),
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=28.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    theme,
    width,
  )
}

///|
fn slider_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Slider",
    "A continuous control backed by the same TEA message path as buttons and inputs.",
    column(
      [
        text(
          "Value: \{score_label(model)}",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=22.0,
          align=@text.TextAlign::TextStart,
        ).foreground(theme.palette.muted),
        @views.slider(
          model.slider_value,
          width=inner,
          foreground=theme.palette.primary,
          on_change=Some(value => SliderChanged(value)),
        ),
        progress_status(
          "Preview",
          value=model.slider_value,
          message="The slider drives this progress sample.",
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
  )
}
