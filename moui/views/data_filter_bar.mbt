///|
pub fn[Msg] data_filter_bar(
  query~ : String,
  on_query~ : (String) -> Msg,
  filters? : Array[DataFilter[Msg]] = [],
  result_count? : Int = 0,
  on_clear? : Msg? = None,
  placeholder? : String = "Search rows",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
) -> @core.View[Msg] {
  let search_width = views_max_double(160.0, width * 0.46)
  let meta_width = views_max_double(88.0, width - search_width - 96.0)
  let rows : Array[@core.View[Msg]] = [
    row(
      [
        searchbar(
          query~,
          on_input=on_query,
          placeholder~,
          variant=TextFieldVariant::Outline,
          theme~,
        ).frame(width=search_width, height=36.0),
        text(
          data_filter_result_label(result_count),
          role=TextRole::Caption,
          theme~,
          width=meta_width,
          height=28.0,
        ).foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=CrossAlign::Center,
    ),
  ]
  let chips : Array[@core.View[Msg]] = []
  for filter in filters {
    chips.push(data_filter_button(filter, theme))
  }
  match on_clear {
    Some(message) =>
      chips.push(
        data_filter_clear_button(
          message,
          disabled=query == "" && !data_filter_has_selection(filters),
          theme,
        ),
      )
    None => ()
  }
  if chips.length() > 0 {
    rows.push(
      flow(
        chips,
        width=views_max_double(120.0, width - theme.spacing_scale.md * 2.0),
        spacing=theme.spacing_scale.xs,
        row_spacing=theme.spacing_scale.xs,
      ),
    )
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Stretch),
    width~,
    height=data_filter_bar_height(chips.length()),
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.sm,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Data filters")
}

///|
fn[Msg] data_filter_button(
  filter : DataFilter[Msg],
  theme : @core.Theme,
) -> @core.View[Msg] {
  button(
    filter.label,
    on_click=filter.message,
    variant=if filter.selected {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Tonal
    },
    theme~,
    width=data_filter_chip_width(filter.label),
    height=32.0,
  )
  .corner_radius(16.0)
  .semantics_selected(selected=filter.selected)
  .disabled(disabled=!filter.enabled)
  .key("data-filter-" + filter.id)
}

///|
fn[Msg] data_filter_clear_button(
  message : Msg,
  disabled~ : Bool,
  theme : @core.Theme,
) -> @core.View[Msg] {
  button(
    "Clear",
    on_click=message,
    variant=ButtonVariant::Ghost,
    theme~,
    width=74.0,
    height=32.0,
  )
  .corner_radius(16.0)
  .disabled(disabled~)
  .key("data-filter-clear")
}

///|
fn data_filter_result_label(result_count : Int) -> String {
  if result_count == 1 {
    "1 result"
  } else {
    "\{result_count} results"
  }
}

///|
fn data_filter_chip_width(label : String) -> Double {
  views_max_double(82.0, label.to_array().length().to_double() * 8.0 + 30.0)
}

///|
fn[Msg] data_filter_has_selection(filters : Array[DataFilter[Msg]]) -> Bool {
  filters.any(filter => filter.selected)
}

///|
fn data_filter_bar_height(chip_count : Int) -> Double {
  if chip_count == 0 {
    58.0
  } else {
    102.0
  }
}
