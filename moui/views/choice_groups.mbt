///|
pub fn choice_item(id : String, label : String) -> ChoiceItem {
  { id, label }
}

///|
pub fn[Msg] radio_group(
  items : Array[ChoiceItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  theme? : @core.Theme = default_theme(),
  spacing? : Double = default_theme().spacing_scale.sm,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      radio(
        item.label,
        item.id == selected,
        on_change=_value => on_select(item.id),
        theme~,
      ).semantics_selected(selected=item.id == selected),
    )
  }
  column(rows, spacing~, align=CrossAlign::Start).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
pub fn[Msg] checkbox_group(
  items : Array[ChoiceItem],
  selected~ : Array[String],
  on_change~ : (String, Bool) -> Msg,
  theme? : @core.Theme = default_theme(),
  spacing? : Double = default_theme().spacing_scale.sm,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    let checked = string_array_contains(selected, item.id)
    rows.push(
      checkbox(
        item.label,
        checked~,
        on_change=value => on_change(item.id, value),
        theme~,
      ).semantics_checked(checked~),
    )
  }
  column(rows, spacing~, align=CrossAlign::Start).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
fn string_array_contains(items : Array[String], id : String) -> Bool {
  items.any(item => item == id)
}
