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
/// A vertical separator between toolbar groups.
fn markdown_editor_toolbar_separator(
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  @views.divider(
    axis=@core.Axis::Vertical,
    theme~,
    thickness=1.0,
    inset=4.0,
  )
}

///|
/// A compact row of toolbar buttons for the editor chrome. Commands are split
/// into four labelled groups (File / Edit / View / Panels) separated by thin
/// dividers, matching the affordance density of Typora / VS Code. Low-frequency
/// items (Import, Export, HTML, cycle Look) collapse into a "More" popover so
/// the bar never overflows on narrow windows.
fn MarkdownEditorApp::markdown_editor_toolbar(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  source : String,
  selection : MarkdownEditorSelection,
) -> @moui.View[MarkdownEditorMsg] {
  let transfer_active = self.transfer_in_progress()
  let dirty = self.is_dirty()
  let can_save = dirty && !transfer_active
  let file_group = row(
    [
      markdown_editor_toolbar_button(
        @views.IconName::FileNew,
        "New Document",
        NewDocument,
        theme~,
        shortcut="⌘N",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::FolderOpen,
        "Open Document",
        OpenDocument,
        theme~,
        disabled=transfer_active,
        shortcut="⌘O",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::Save,
        "Save",
        SaveDocument,
        theme~,
        disabled=!can_save,
        shortcut="⌘S",
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let edit_group = row(
    [
      markdown_editor_toolbar_button(
        @views.IconName::ChevronLeft,
        "Undo",
        Undo,
        theme~,
        disabled=!self.can_undo(),
        shortcut="⌘Z",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::ChevronRight,
        "Redo",
        Redo,
        theme~,
        disabled=!self.can_redo(),
        shortcut="⌘⇧Z",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::Search,
        "Find",
        ToggleFind,
        theme~,
        active=self.find_visible.get(),
        shortcut="⌘F",
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let view_group = row(
    [
      markdown_editor_toolbar_button(
        @views.IconName::Focus,
        "Focus Mode",
        ToggleFocusMode,
        theme~,
        active=self.focus_mode_enabled.get(),
        shortcut="⌘⇧F",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::Columns,
        "Typewriter Mode",
        ToggleTypewriterMode,
        theme~,
        active=self.typewriter_mode_enabled.get(),
        shortcut="⌘⇧T",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::Eye,
        "Zen Mode",
        ToggleZenMode,
        theme~,
        active=self.zen_mode_enabled.get(),
        shortcut="⌘⌥Z",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::CodeInline,
        "Source Mode",
        ToggleSourceMode,
        theme~,
        active=self.source_mode_enabled.get(),
        shortcut="⌘⇧/",
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let panels_group = row(
    [
      markdown_editor_toolbar_button(
        @views.IconName::ListBullet,
        "Outline",
        ToggleOutline,
        theme~,
        active=self.outline_visible.get(),
        shortcut="⌘⌥O",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::FolderOpen,
        "Files",
        ToggleFileSidebar,
        theme~,
        active=self.file_sidebar_visible.get(),
        shortcut="⌘⌥P",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::Info,
        "Document Info",
        ToggleDocumentInfo,
        theme~,
        active=self.document_info_visible.get(),
        shortcut="⌘⌥D",
      ),
      markdown_editor_toolbar_button(
        @views.IconName::Columns,
        "Source Preview",
        ToggleSourcePreview,
        theme~,
        active=self.source_preview_visible.get(),
        shortcut="⌘/",
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let more = self.markdown_editor_more_menu(theme, source, selection)
  row(
    [
      file_group,
      markdown_editor_toolbar_separator(theme),
      edit_group,
      markdown_editor_toolbar_separator(theme),
      panels_group,
      markdown_editor_toolbar_separator(theme),
      view_group,
      markdown_editor_toolbar_separator(theme),
      more,
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  ).repaint_boundary()
}

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
  let expanded = self.more_menu_visible.get()
  let anchor = markdown_editor_toolbar_button(
    @views.IconName::Settings,
    "More",
    ToggleMoreMenu,
    theme~,
    active=expanded,
  )
  let row_height = 30.0
  let rows : Array[@moui.View[MarkdownEditorMsg]] = []
  for item in markdown_editor_more_menu_items() {
    rows.push(
      markdown_editor_more_menu_row(item, theme~, row_height~),
    )
  }
  ignore(source)
  ignore(selection)
  let content = container(
    padding_edges(
      column(rows, spacing=theme.spacing_scale.xs, align=@views.CrossAlign::Start),
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
  popover(
    anchor~,
    content~,
    expanded~,
    theme~,
    width=240.0,
    height=row_height * rows.length().to_double() + theme.spacing_scale.sm,
  )
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
