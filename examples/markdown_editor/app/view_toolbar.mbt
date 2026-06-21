///|
/// An icon-driven toolbar button with tooltip, active/disabled states and an
/// optional shortcut hint. Toggle commands pass `active=true` to render with
/// the `Tonal` variant (highlighted) instead of `Ghost`; commands that cannot
/// apply pass `disabled=true` to grey-out via `View::disabled`. The tooltip
/// shows the human-readable label plus the shortcut.
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

///|
/// The "More" popover collects low-frequency document commands (Save As,
/// Import/Export, HTML export, cycle Look) behind a single gear button so the
/// primary toolbar stays readable. Selecting any item dispatches its message
/// via `MoreMenuCommand`, which both runs the action and closes the popover.
fn MarkdownEditorApp::markdown_editor_more_menu(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  source : String,
  selection : MarkdownEditorSelection,
) -> @moui.View[MarkdownEditorMsg] {
  // Only the anchor button lives in the chrome bar; the popover content is
  // rendered as a top-level overlay (more_menu_overlay) so it floats above
  // the editor page card instead of being covered by it.
  let _ = source
  let _ = selection
  let expanded = self.more_menu_visible.get()
  markdown_editor_toolbar_button(
    @views.IconName::Settings,
    "More",
    ToggleMoreMenu,
    theme~,
    active=expanded,
  )
}

///|
/// The More-menu popover content, rendered as a top-level overlay anchored to
/// the top-right of the workspace (just below the title bar) so it paints
/// above the editor page card. Returns empty when the menu is closed.
fn MarkdownEditorApp::more_menu_overlay(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let expanded = self.more_menu_visible.get()
  if !expanded {
    @views.empty()
  } else {
    let row_height = 30.0
    let rows : Array[@moui.View[MarkdownEditorMsg]] = []
    for item in markdown_editor_more_menu_items() {
      rows.push(
        markdown_editor_more_menu_row(item, theme~, row_height~),
      )
    }
    let visible_rows = if rows.length() < 10 { rows.length() } else { 10 }
    let menu_height = row_height * visible_rows.to_double() +
      theme.spacing_scale.sm * 2.0
    let content = container(
      padding_edges(
        scroll_view(
          column(
            rows, spacing=theme.spacing_scale.xs, align=@views.CrossAlign::Start,
          ),
          width=232.0,
          height=menu_height,
        ),
        top=theme.spacing_scale.xs,
        right=theme.spacing_scale.sm,
        bottom=theme.spacing_scale.xs,
        left=theme.spacing_scale.sm,
      ),
      width=232.0,
      variant=@views.ContainerVariant::Overlay,
      theme~,
      padding=0.0,
    )
    // The caller wraps this in a top-trailing align with a top offset so the
    // popover drops from the ⋯ button in the title bar and paints above the
    // editor page card.
    content
  }
}

///|
/// Low-frequency commands surfaced in the "More" popover, each paired with the
/// message to dispatch and a shortcut hint for the trailing label.
fn markdown_editor_more_menu_items() -> Array[
  MarkdownEditorMoreMenuItem,
] {
  [
    { label: "Save As…", shortcut: "⌘⇧S", message: SaveDocumentAs },
    {
      label: "Import from Clipboard",
      shortcut: "⌘⌥I",
      message: ImportFromClipboard,
    },
    { label: "Export Markdown", shortcut: "⌘⌥S", message: ExportToClipboard },
    { label: "Export HTML", shortcut: "⌘⌥E", message: ExportHtmlToClipboard },
    {
      label: "Cycle Writing Look",
      shortcut: "⌘⌥L",
      message: CycleWritingAppearance,
    },
    { label: "Quick Format…", shortcut: "⌘⇧P", message: ToggleFormatPalette },
    { label: "Toggle Dark Mode", shortcut: "", message: ToggleDarkMode },
    { label: "Cycle Font Family", shortcut: "", message: CycleFontFamily },
    { label: "Focus Mode", shortcut: "⌘⇧F", message: ToggleFocusMode },
    { label: "Typewriter Mode", shortcut: "⌘⇧T", message: ToggleTypewriterMode },
    { label: "Zen Mode", shortcut: "⌘⌥Z", message: ToggleZenMode },
    { label: "Source Mode", shortcut: "⌘⇧/", message: ToggleSourceMode },
    { label: "Outline", shortcut: "⌘⌥O", message: ToggleOutline },
    { label: "Files", shortcut: "⌘⌥P", message: ToggleFileSidebar },
    { label: "Document Info", shortcut: "⌘⌥D", message: ToggleDocumentInfo },
    { label: "Source Preview", shortcut: "⌘/", message: ToggleSourcePreview },
  ]
}

///|
/// A single row inside the "More" popover: a full-width ghost button carrying
/// the command label and a muted shortcut hint. Selecting the row dispatches
/// `MoreMenuCommand` so the popover closes alongside the action.
fn markdown_editor_more_menu_row(
  item : MarkdownEditorMoreMenuItem,
  theme~ : @moui.Theme,
  row_height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  row(
    [
      button(
        item.label,
        on_click=MoreMenuCommand(item.message),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=168.0,
        height=row_height,
      ),
      text(item.shortcut, width=56.0, height=row_height)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}
