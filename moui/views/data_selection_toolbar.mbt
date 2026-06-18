///|
pub fn[Msg] selection_toolbar(
  selected_count~ : Int,
  total_count? : Int = 0,
  actions? : Array[MenuItem[Msg]] = [],
  on_clear? : Msg? = None,
  theme? : @core.Theme = default_theme(),
  width? : Double = 520.0,
) -> @core.View[Msg] {
  let selected = views_max_int(0, selected_count)
  let summary_width = views_max_double(120.0, width * 0.36)
  let action_width = views_max_double(80.0, width - summary_width - 92.0)
  let action_views : Array[@core.View[Msg]] = []
  for action in actions {
    action_views.push(
      button(
        action.label,
        on_click=action.message,
        variant=ButtonVariant::Tonal,
        theme~,
        width=selection_toolbar_action_width(action.label),
        height=32.0,
      ).disabled(disabled=selected == 0 || !action.enabled),
    )
  }
  match on_clear {
    Some(message) =>
      action_views.push(
        button(
          "Clear",
          on_click=message,
          variant=ButtonVariant::Ghost,
          theme~,
          width=70.0,
          height=32.0,
        ).disabled(disabled=selected == 0),
      )
    None => ()
  }
  container(
    row(
      [
        text(
          selection_toolbar_label(selected, total_count),
          role=TextRole::Caption,
          theme~,
          width=summary_width,
          height=28.0,
        ).foreground(
          if selected == 0 {
            theme.palette.muted
          } else {
            theme.palette.foreground
          },
        ),
        flow(
          action_views,
          width=action_width,
          spacing=theme.spacing_scale.xs,
          row_spacing=theme.spacing_scale.xs,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=CrossAlign::Center,
    ),
    width~,
    height=selection_toolbar_height(action_views.length()),
    variant=ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.sm,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_selected(selected=selected > 0)
  .semantics_description(selection_toolbar_label(selected, total_count))
  .accessibility_label("Selection toolbar")
}

///|
fn selection_toolbar_label(selected_count : Int, total_count : Int) -> String {
  if selected_count == 0 {
    "No rows selected"
  } else if total_count > 0 {
    "\{selected_count} of \{total_count} selected"
  } else if selected_count == 1 {
    "1 row selected"
  } else {
    "\{selected_count} rows selected"
  }
}

///|
fn selection_toolbar_action_width(label : String) -> Double {
  views_max_double(76.0, label.to_array().length().to_double() * 8.0 + 24.0)
}

///|
fn selection_toolbar_height(action_count : Int) -> Double {
  if action_count > 3 {
    86.0
  } else {
    54.0
  }
}
