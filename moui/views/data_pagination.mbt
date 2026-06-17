///|
pub fn[Msg] pagination(
  page~ : Int,
  page_count~ : Int,
  on_previous~ : Msg,
  on_next~ : Msg,
  theme? : @core.Theme = default_theme(),
  width? : Double = 360.0,
  previous_label? : String = "Previous",
  next_label? : String = "Next",
) -> @core.View[Msg] {
  let total_pages = views_max_int(1, page_count)
  let current_page = views_min_int(views_max_int(0, page), total_pages - 1)
  let has_previous = current_page > 0
  let has_next = current_page + 1 < total_pages
  let previous_width = pagination_button_width(previous_label)
  let next_width = pagination_button_width(next_label)
  let label_width = views_max_double(
    88.0,
    width - previous_width - next_width - theme.spacing_scale.sm * 2.0,
  )
  row(
    [
      button(
        previous_label,
        on_click=on_previous,
        variant=ButtonVariant::Outline,
        theme~,
        width=previous_width,
        height=36.0,
      ).disabled(disabled=!has_previous),
      text(
        "Page \{current_page + 1} of \{total_pages}",
        role=TextRole::Caption,
        theme~,
        width=label_width,
        height=28.0,
      ),
      button(
        next_label,
        on_click=on_next,
        variant=ButtonVariant::Outline,
        theme~,
        width=next_width,
        height=36.0,
      ).disabled(disabled=!has_next),
    ],
    spacing=theme.spacing_scale.sm,
    align=CrossAlign::Center,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Page \{current_page + 1} of \{total_pages}")
}

///|
fn pagination_button_width(label : String) -> Double {
  views_max_double(76.0, label.to_array().length().to_double() * 8.0 + 24.0)
}
