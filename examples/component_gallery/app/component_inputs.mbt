///|
fn text_area_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Text Area",
    "Use a text area when input can span multiple lines.",
    column(
      [
        @views.text_area(
          model.sample_text,
          on_input=value => SampleTextChanged(value),
          placeholder="Write a component note",
          lines=4,
          theme~,
          width=inner,
        ),
        wrapped_text(
          "Saved value: " + model.sample_text,
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=38.0,
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
fn clearable_text_field_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Clearable Text Field",
    "A text field with a nearby clear command keeps the reset affordance visible.",
    column(
      [
        @views.clearable_text_field(
          model.sample_text,
          on_input=value => SampleTextChanged(value),
          on_clear=SampleTextChanged(""),
          placeholder="Filter components",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=inner,
        ),
        wrapped_text(
          if model.sample_text == "" {
            "The field is empty."
          } else {
            "Current filter: " + model.sample_text
          },
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
fn password_field_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Password Field",
    "The reveal control is explicit app state, so every host follows the same update path.",
    column(
      [
        @views.password_field(
          model.sample_text,
          on_input=value => SampleTextChanged(value),
          revealed=model.password_revealed,
          on_toggle_reveal=TogglePasswordReveal,
          placeholder="Password",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=inner,
        ),
        status_badge(
          if model.password_revealed {
            "revealed"
          } else {
            "masked"
          },
          tone=if model.password_revealed {
            @views.BadgeTone::Warning
          } else {
            @views.BadgeTone::Neutral
          },
          detail="password visibility",
          theme~,
          width=112.0,
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
fn number_field_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Number Field",
    "Numeric entry can still stay a controlled text value.",
    column(
      [
        @views.number_field(
          model.sample_number,
          on_input=value => SampleNumberChanged(value),
          step=1.0,
          placeholder="0",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=inner,
        ),
        wrapped_text(
          "Current number: " + model.sample_number,
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
fn stepper_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  component_demo_section(
    "Stepper",
    "A compact stepper is useful when the value changes in predictable increments.",
    action_counter_panel(model, theme, inner, compact),
    theme,
    width,
  )
}
