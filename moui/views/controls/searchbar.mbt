///|
pub fn[Msg] searchbar(
  query~ : String,
  on_input~ : (String) -> Msg,
  placeholder? : String = "Search...",
  variant? : @style.TextFieldVariant = @style.TextFieldVariant::Filled,
  theme? : @core.Theme,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> @core.View[Msg] {
  @text.controlled_search_bar_control(
    query~,
    on_input~,
    placeholder~,
    theme?,
    variant~,
    on_submit~,
    on_clear~,
  )
}
