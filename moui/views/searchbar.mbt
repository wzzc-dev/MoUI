///|
pub fn[Msg] searchbar(
  query~ : String,
  on_input~ : (String) -> Msg,
  placeholder? : String = "Search...",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> @core.View[Msg] {
  let style = variant.style(theme)
  let normal = style.normal
  let focused = style.focused
  @widget.controlled_search_bar(
    query~,
    on_input~,
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

///|
pub fn[Msg] searchbar_binding(
  query~ : @core.Binding[String],
  placeholder? : String = "Search...",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> @core.View[Msg] {
  let style = variant.style(theme)
  let normal = style.normal
  let focused = style.focused
  @widget.search_bar(
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
