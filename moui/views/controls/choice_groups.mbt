///|
pub fn choice_item(id : String, label : String) -> ChoiceItem {
  { id, label }
}

///|
pub fn[Msg] radio_group(
  items : Array[ChoiceItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  theme? : @core.Theme,
  spacing? : Double = @style.default_theme().spacing_scale.sm,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      @checkbox.radio(
        item.label,
        item.id == selected,
        on_change=_value => on_select(item.id),
        theme=resolved_theme,
      ).semantics_selected(selected=item.id == selected),
    )
  }
  @layout.column(rows, spacing~, align=@style.CrossAlign::Start).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
pub fn[Msg] checkbox_group(
  items : Array[ChoiceItem],
  selected~ : Array[String],
  on_change~ : (String, Bool) -> Msg,
  theme? : @core.Theme,
  spacing? : Double = @style.default_theme().spacing_scale.sm,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    let checked = string_array_contains(selected, item.id)
    rows.push(
      @checkbox.checkbox(
        item.label,
        checked~,
        on_change=value => on_change(item.id, value),
        theme=resolved_theme,
      ).semantics_checked(
        checked=if checked {
          @core.SemanticsCheckedState::Checked
        } else {
          @core.SemanticsCheckedState::Unchecked
        },
      ),
    )
  }
  @layout.column(rows, spacing~, align=@style.CrossAlign::Start).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
pub fn string_array_contains(items : Array[String], id : String) -> Bool {
  items.any(item => item == id)
}
