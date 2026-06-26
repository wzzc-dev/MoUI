///|
/// An icon-driven toolbar button with tooltip, active/disabled states and an
/// optional shortcut hint. Toggle commands pass `active=true` to render with
/// the `Tonal` variant (highlighted) instead of `Ghost`; commands that cannot
/// apply pass `disabled=true` to grey-out via `View::disabled`. The tooltip
/// shows the human-readable label plus the shortcut.
#warnings("-unused_value")
fn markdown_editor_toolbar_button(
  icon : @views.IconName,
  label : String,
  message : MarkdownEditorMsg,
  theme~ : @moui.Theme,
  active? : Bool = false,
  disabled? : Bool = false,
  shortcut? : String = "",
) -> @moui.View[MarkdownEditorMsg] {
  let tooltip_text = if shortcut == "" {
    label
  } else {
    label + "  " + shortcut
  }
  let variant = if active {
    @views.ButtonVariant::Tonal
  } else {
    @views.ButtonVariant::Ghost
  }
  let btn = button(
    "",
    on_click=message,
    variant~,
    theme~,
    icon=Some(icon),
    width=34.0,
    height=30.0,
  ).disabled(disabled~)
  tooltip(btn, tooltip_text)
}

///|
/// The top-level toolbar was removed in favor of Typora's title-bar + menu
/// aesthetic; the per-group buttons below are retained for the "More" popover
/// anchor and future affordances.
