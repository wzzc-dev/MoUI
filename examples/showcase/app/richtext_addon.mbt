///|
fn showcase_text_field_style(
  variant : @views.TextFieldVariant,
  theme : @moui.Theme,
) -> @views.TextFieldStyle {
  match variant {
    Filled => @views.TextFieldStyle::filled(theme~)
    Outline => @views.TextFieldStyle::outline(theme~)
    Plain => {
      let base = @views.TextFieldStyle::filled(theme~)
      let clear = @core.Brush::solid(
        @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
      )
      let normal = {
        ..base.normal,
        background: clear,
        border: None,
        radius: 0.0,
      }
      { ..base, normal, focused: normal }
    }
  }
}

///|
fn[Msg] showcase_rich_text_editor(
  value : String,
  format : (String) -> @moui_richtext.RichTextDocument,
  on_input~ : (String) -> Msg,
  placeholder? : String = "",
  width? : Double = 240.0,
  height? : Double = 40.0,
  variant? : @views.TextFieldVariant = Filled,
  theme? : @moui.Theme = @views.default_theme(),
) -> @moui.View[Msg] {
  let style = showcase_text_field_style(variant, theme)
  let normal = style.normal
  let focused = style.focused
  @moui_richtext.controlled_rich_text_editor(
    value~,
    on_input~,
    placeholder~,
    size=@moui.Size::new(width~, height~),
    format~,
    font=style.font,
    foreground=normal.foreground,
    placeholder_color=style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=style.cursor_color,
    corner_radius=normal.radius,
  )
}

///|
fn[Msg] showcase_markdown_editor(
  value : String,
  on_input~ : (String) -> Msg,
  placeholder? : String = "",
  width? : Double = 240.0,
  height? : Double = 40.0,
  variant? : @views.TextFieldVariant = Filled,
  theme? : @moui.Theme = @views.default_theme(),
) -> @moui.View[Msg] {
  let style = showcase_text_field_style(variant, theme)
  let normal = style.normal
  let focused = style.focused
  @moui_richtext.controlled_markdown_editor(
    value~,
    on_input~,
    placeholder~,
    size=@moui.Size::new(width~, height~),
    font=style.font,
    foreground=normal.foreground,
    placeholder_color=style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=style.cursor_color,
    corner_radius=normal.radius,
  )
}
