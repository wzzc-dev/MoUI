///|
/// Inline text editor: an idle label that turns into a single-line field.
///
/// The caller owns both states — `editing` and the draft `text` — so the
/// control carries no state of its own: one branch of the app's view function
/// is the whole editor. Enter commits with the draft that is on screen,
/// Escape cancels when `on_cancel` is supplied (without it the field leaves
/// Escape to the enclosing overlay), and a tap on the idle label asks to
/// start editing through `on_start`.
///
/// Caret placement is a runtime concern, not a control one: after focusing
/// the field the caller uses `AppRuntime::select_focused_text_all` or
/// `AppRuntime::place_focused_text_caret` to decide where typing lands, which
/// is what keeps a rename prompt from prefixing the prefilled name.
pub fn[Msg] inline_edit(
  key~ : String,
  text~ : String,
  editing~ : Bool,
  on_input~ : (String) -> Msg,
  on_commit~ : (String) -> Msg,
  on_start? : Msg,
  on_cancel? : Msg,
  placeholder~ : String = "",
  theme? : @core.Theme,
  width~ : Double = 0.0,
  height? : Double,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  if editing {
    return @text.text_field(
      text,
      on_input~,
      on_submit=Some(on_commit(text)),
      on_cancel?,
      key~,
      placeholder~,
      theme=resolved_theme,
      width=if width > 0.0 { width } else { 240.0 },
      height?,
    )
  }
  let idle_height = height.unwrap_or(0.0)
  let idle_width = if width > 0.0 { width } else { 0.0 }
  let idle = (if text == "" {
    // An empty draft shows the placeholder in the muted palette rather than
    // an empty box, so the field still reads as "editable here".
    @text.text(
      placeholder,
      role=Label,
      theme=resolved_theme,
      width=idle_width,
      height=idle_height,
      align=@core.TextAlign::TextStart,
    ).foreground(resolved_theme.palette.muted)
  } else {
    @text.text(
      text,
      role=Body,
      theme=resolved_theme,
      width=idle_width,
      height=idle_height,
      align=@core.TextAlign::TextStart,
    )
  }).key(key)
  match on_start {
    Some(message) => idle.on_tap(message)
    None => idle
  }
}
