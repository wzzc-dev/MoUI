///|
pub fn[Msg] searchbar(
  query~ : String,
  on_input~ : (String) -> Msg,
  placeholder? : String = "Search...",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> @core.View[Msg] {
  // Style is resolved ambient-ly inside the control (an explicit theme?
  // overrides ctx.environment.theme) so the search bar tracks dark-mode / a11y
  // changes without the caller rebuilding the view tree.
  controlled_search_bar_control(
    query~,
    on_input~,
    placeholder~,
    theme?,
    variant~,
    on_submit~,
    on_clear~,
  )
}

///|
pub fn[Msg] searchbar_binding(
  query~ : @core.Binding[String],
  placeholder? : String = "Search...",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> @core.View[Msg] {
  search_bar_control(
    query~,
    placeholder~,
    theme?,
    variant~,
    on_submit~,
    on_clear~,
  )
}
