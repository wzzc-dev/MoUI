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
      let clear = @graphics.Brush::solid(
        @graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
      )
      let normal = @views.new_control_state_style(
        foreground=theme.palette.foreground,
        background=clear,
        radius=0.0,
      )
      base.with_normal(normal~).with_focused(focused=normal)
    }
  }
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
    size=@geometry.Size::new(width~, height~),
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
/// Format a plain value into a RichTextDocument with a bold lead run.
/// Showcases RichTextDocument/RichTextBlock/RichTextRun composition for the
/// Text Diagnostics gallery.
fn showcase_format_rich_text(value : String) -> @moui_richtext.RichTextDocument {
  let bold_run = @moui_richtext.RichTextRun::new(
    text="Lead: ",
    font=Some(@core.FontSpec::new(weight=700)),
  )
  let body_run = @moui_richtext.RichTextRun::new(text=value)
  let block = @moui_richtext.RichTextBlock::new(runs=[bold_run, body_run])
  @moui_richtext.RichTextDocument::new(blocks=[block])
}
