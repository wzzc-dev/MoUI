///|
pub fn[Msg] searchbar(
  query~ : @core.Binding[String],
  placeholder? : String = "Search...",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = @core.Theme::default(),
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> @core.View[Msg] {
  let style = variant.style(theme)
  let normal = style.normal
  let focused = style.focused
  @core.View::search_bar(
    query~,
    placeholder~,
    font=style.font,
    foreground=normal.foreground,
    placeholder_color=style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=style.cursor_color,
    corner_radius=normal.radius,
    on_submit~,
    on_clear~,
  )
}
