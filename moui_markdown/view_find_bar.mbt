///|
/// Msg-generic Markdown find/replace bar, extracted from MoMark's app chrome.
/// The caller owns the query/replace/options state and receives intent
/// messages; the bar itself renders the same layout as MoMark's (find field,
/// replace field, option toggles, status label, navigation, replace actions).

///|
/// A compact ghost icon button with a tooltip.
fn[Msg] markdown_find_icon_button(
  icon : @views.IconName,
  tooltip_label : String,
  message : Msg,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.tooltip(
    @views.button(
      "",
      on_click=message,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      icon=Some(icon),
      width=34.0,
      height=34.0,
    ),
    tooltip_label,
  )
}

///|
/// A compact option toggle chip: Ghost at rest, Tonal when active.
fn[Msg] markdown_find_toggle(
  glyph : String,
  tooltip_label : String,
  message : Msg,
  active : Bool,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let variant = if active {
    @views.ButtonVariant::Tonal
  } else {
    @views.ButtonVariant::Ghost
  }
  @views.tooltip(
    @views.button(
      glyph,
      on_click=message,
      variant~,
      theme~,
      width=34.0,
      height=34.0,
    ),
    tooltip_label,
  )
}

///|
/// A small text button sized like MoMark's editor chrome buttons.
fn[Msg] markdown_find_text_button(
  label : String,
  message : Msg,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let width = if @richtext.markdown_editor_text_length(label) > 5 {
    78.0
  } else {
    64.0
  }
  @views.button(
    label,
    on_click=message,
    variant=@views.ButtonVariant::Tonal,
    theme~,
    width~,
    height=34.0,
  )
}

///|
/// The find/replace bar. `status_label` is normally
/// `markdown_find_status_label(query, matches, selection, options~)`, but any
/// caller-composed label (e.g. localized text) works too.
///
/// The bar is `width` wide and 42pt tall, matching MoMark's chrome slot.
///
/// `compact=true` drops the inline "Find"/"Replace" captions (the fields keep
/// their placeholders), narrows both fields and the status slot, and halves the
/// row gap. The laid-out content drops from ~1130pt to ~750pt, so the bar fits
/// a narrow window instead of clipping its trailing buttons. Layout only —
/// every control stays present, and the widths stay fixed so the caller can
/// still compute its own slot.
pub fn[Msg] markdown_find_bar(
  theme~ : @moui.Theme,
  query~ : String,
  replace_text~ : String,
  options~ : MarkdownFindOptions,
  status_label~ : String,
  on_query_input~ : (String) -> Msg,
  on_replace_input~ : (String) -> Msg,
  on_submit_query~ : Msg,
  on_submit_replace~ : Msg,
  on_toggle_case_sensitive~ : Msg,
  on_toggle_whole_word~ : Msg,
  on_toggle_regex~ : Msg,
  on_previous~ : Msg,
  on_next~ : Msg,
  on_replace_current~ : Msg,
  on_replace_all~ : Msg,
  on_close~ : Msg,
  width~ : Double,
  compact~ : Bool = false,
  find_label~ : String = "Find",
  replace_label~ : String = "Replace",
  search_placeholder~ : String = "Search Markdown",
  replacement_placeholder~ : String = "Replacement",
  replace_button_label~ : String = "Replace",
  replace_all_button_label~ : String = "All",
  match_case_tooltip~ : String = "Match case",
  whole_word_tooltip~ : String = "Whole word",
  regex_tooltip~ : String = "Regex",
  previous_tooltip~ : String = "Previous match",
  next_tooltip~ : String = "Next match",
  close_tooltip~ : String = "Close find bar",
  key_prefix~ : String = "markdown",
) -> @moui.View[Msg] {
  let field_width = if compact { 104.0 } else { 196.0 }
  let status_width = if compact { 44.0 } else { 88.0 }
  let children : Array[@moui.View[Msg]] = []
  if !compact {
    children.push(
      @views.text(find_label, width=44.0, height=34.0, theme~)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    )
  }
  children.push(
    @views.text_field(
      query,
      on_input=on_query_input,
      on_submit=Some(on_submit_query),
      placeholder=search_placeholder,
      variant=@views.TextFieldVariant::Outline,
      theme~,
      width=field_width,
      height=34.0,
    ).key("\{key_prefix}-find-query"),
  )
  if !compact {
    children.push(
      @views.text(replace_label, width=64.0, height=34.0, theme~)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    )
  }
  children.push(
    @views.text_field(
      replace_text,
      on_input=on_replace_input,
      on_submit=Some(on_submit_replace),
      placeholder=replacement_placeholder,
      variant=@views.TextFieldVariant::Outline,
      theme~,
      width=field_width,
      height=34.0,
    ).key("\{key_prefix}-replace-text"),
  )
  children.push(
    markdown_find_toggle(
      "Aa",
      match_case_tooltip,
      on_toggle_case_sensitive,
      options.case_sensitive,
      theme,
    ),
  )
  children.push(
    markdown_find_toggle(
      "W",
      whole_word_tooltip,
      on_toggle_whole_word,
      options.whole_word,
      theme,
    ),
  )
  children.push(
    markdown_find_toggle(
      ".*",
      regex_tooltip,
      on_toggle_regex,
      options.regex,
      theme,
    ),
  )
  children.push(
    @views.text(status_label, width=status_width, height=34.0, theme~)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted),
  )
  children.push(
    markdown_find_icon_button(
      @views.IconName::ChevronLeft,
      previous_tooltip,
      on_previous,
      theme,
    ),
  )
  children.push(
    markdown_find_icon_button(
      @views.IconName::ChevronRight,
      next_tooltip,
      on_next,
      theme,
    ),
  )
  children.push(
    markdown_find_text_button(replace_button_label, on_replace_current, theme),
  )
  children.push(
    markdown_find_text_button(replace_all_button_label, on_replace_all, theme),
  )
  children.push(
    markdown_find_icon_button(
      @views.IconName::Close,
      close_tooltip,
      on_close,
      theme,
    ),
  )
  @views.frame(
    @views.row(
      children,
      spacing=if compact {
        theme.spacing_scale.xs * 0.5
      } else {
        theme.spacing_scale.xs
      },
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=42.0,
  )
}
