///|
fn MarkdownEditorApp::root(
  self : MarkdownEditorApp,
  viewport_height? : Double = 520.0,
) -> @moui.View[MarkdownEditorMsg] {
  let theme = self.chrome_theme()
  let document = self.document.get()
  let appearance = self.appearance_spec()
  let editor_font = markdown_editor_appearance_font(appearance)
  let snapshot = MarkdownEditorSnapshot::parse_with_font(document, editor_font)
  let zen = self.zen_mode_enabled.get()
  let show_source = if zen { false } else { self.source_preview_visible.get() }
  let show_outline = if zen { false } else { self.outline_visible.get() }
  let show_files = if zen { false } else { self.file_sidebar_visible.get() }
  let show_info = if zen { false } else { self.document_info_visible.get() }
  let workspace_width = markdown_editor_workspace_width(
    show_source, show_outline, show_files, show_info, appearance,
  )
  let target_bar = self.target_bar(theme)
  let selection = self.selection.get()
  let target_kind = self.target_kind.get()
  let block_label = self.block_label.get()
  let scroll_offset = self.editor_scroll.offset()
  let children : Array[@moui.View[MarkdownEditorMsg]] = []
  if !zen {
    children.push(
      self.chrome(
        theme, document, selection, workspace_width,
      ),
    )
  }
  if !zen && self.find_visible.get() {
    children.push(self.find_bar(theme, document, selection, workspace_width))
  }
  if !zen && self.format_palette_visible.get() {
    children.push(self.format_palette(theme, workspace_width))
  }
  children.push(
    row(
      [
        editor_source_layout(
          self,
          document,
          snapshot,
          editor_font,
          appearance,
          theme,
          show_source,
          show_outline,
          show_files,
          show_info,
          target_bar,
          selection,
          target_kind,
          scroll_offset,
          (caret, selection) => SetSelection(caret, selection),
          offset => ToggleTaskAt(offset),
          viewport_height~,
        ),
      ],
      spacing=theme.spacing_scale.lg,
      align=@views.CrossAlign::Start,
    ),
  )
  if !zen {
    children.push(
      self.bottom_status_bar(
        theme, snapshot, block_label, document, selection, workspace_width,
      ),
    )
  }
  let workspace = column(
    children,
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Start,
  )
  let centered = markdown_editor_centered_workspace(
    appearance,
    padding_edges(
      workspace,
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.xl,
      bottom=theme.spacing_scale.xl,
      left=theme.spacing_scale.md,
    ),
  )
  // Stack the toast layer, More-menu popover, and confirm dialog above the
  // workspace so they float over the editor without displacing it. The More
  // menu is a top-level overlay so it paints above the editor page card.
  @views.stack([
    centered,
    @views.align(
      self.toast_layer(theme),
      alignment=@core.Alignment::new(x=0.5, y=0.0),
    ),
    // The More menu sits at the top-right, offset down past the title bar
    // (36px) plus a small gap so it drops from the ⋯ button. A padding-top
    // on the content pushes it below the bar; align keeps it top-trailing.
    @views.align(
      padding_edges(
        self.more_menu_overlay(theme),
        top=44.0,
        right=theme.spacing_scale.md,
      ),
      alignment=@core.Alignment::top_trailing(),
    ),
    @views.align(
      self.confirm_dialog(theme),
      alignment=@core.Alignment::center(),
    ),
  ])
}

///|
/// Resolve the chrome theme from the dark-mode toggle. The framework ships a
/// full dark theme (`@views.dark_theme()`), so toggling is a one-liner here;
/// the editor surface and panels inherit the theme via the environment.
fn MarkdownEditorApp::chrome_theme(self : MarkdownEditorApp) -> @moui.Theme {
  if self.dark_mode_enabled.get() {
    @views.dark_theme()
  } else {
    @views.light_theme()
  }
}

///|
fn MarkdownEditorApp::reactive_root(
  self : MarkdownEditorApp,
  ctx : @core.ComponentContext,
) -> @moui.View[MarkdownEditorMsg] {
  ignore(ctx.watch(self.document))
  ignore(ctx.watch(self.selection))
  ignore(ctx.watch(self.link_target))
  ignore(ctx.watch(self.image_target))
  ignore(ctx.watch(self.footnote_text))
  ignore(ctx.watch(self.html_block_text))
  ignore(ctx.watch(self.target_kind))
  ignore(ctx.watch(self.block_label))
  ignore(ctx.watch(self.source_preview_visible))
  ignore(ctx.watch(self.source_mode_enabled))
  ignore(ctx.watch(self.outline_visible))
  ignore(ctx.watch(self.file_sidebar_visible))
  ignore(ctx.watch(self.document_info_visible))
  ignore(ctx.watch(self.focus_mode_enabled))
  ignore(ctx.watch(self.typewriter_mode_enabled))
  ignore(ctx.watch(self.zen_mode_enabled))
  ignore(ctx.watch(self.format_palette_visible))
  ignore(ctx.watch(self.format_palette_query))
  ignore(ctx.watch(self.more_menu_visible))
  ignore(ctx.watch(self.toasts))
  ignore(ctx.watch(self.pending_confirm))
  ignore(ctx.watch(self.dark_mode_enabled))
  ignore(ctx.watch(self.font_family))
  ignore(ctx.watch(self.folded_headings))
  ignore(ctx.watch(self.writing_appearance))
  ignore(ctx.watch(self.find_visible))
  ignore(ctx.watch(self.find_query))
  ignore(ctx.watch(self.find_options))
  ignore(ctx.watch(self.replace_text))
  ignore(ctx.watch(self.document_path))
  ignore(ctx.watch(self.recent_document_paths))
  ignore(ctx.watch(self.saved_document))
  ignore(ctx.watch(self.transfer_status))
  ignore(ctx.watch(self.working_directory))
  ignore(ctx.watch(self.expanded_tree_paths))
  ignore(ctx.watch(self.directory_tree_items))
  ignore(ctx.watch(self.file_tree_expanded))
  ignore(ctx.watch(self.selected_image_offset))
  ignore(ctx.watch(self.image_centered))
  ignore(ctx.watch_scroll(self.editor_scroll))
  // Make the editor viewport fill the window instead of a fixed 520px. Reserve
  // room for the chrome bar (34px) plus spacing so the page doesn't overflow.
  let window_height = ctx.viewport_size().height
  let viewport_height = markdown_editor_max_double(320.0, window_height - 112.0)
  self.root(viewport_height~)
}

///|
fn markdown_editor_workspace_width(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  appearance : MarkdownEditorAppearanceSpec,
) -> Double {
  let mut width = markdown_editor_primary_editor_width(
    show_source, show_outline, show_files, show_info, appearance,
  )
  let mut gaps = 0
  if show_files {
    width = width + markdown_editor_file_sidebar_width()
    gaps = gaps + 1
  }
  if show_info {
    width = width + markdown_editor_info_inspector_width()
    gaps = gaps + 1
  }
  if show_outline {
    width = width + markdown_editor_outline_inspector_width()
    gaps = gaps + 1
  }
  if show_source {
    width = width + markdown_editor_source_inspector_width()
    gaps = gaps + 1
  }
  width + @views.light_theme().spacing_scale.lg * gaps.to_double()
}

///|
fn markdown_editor_centered_workspace(
  appearance : MarkdownEditorAppearanceSpec,
  child : @moui.View[MarkdownEditorMsg],
) -> @moui.View[MarkdownEditorMsg] {
  @views.custom_children_layout(
    children=[child],
    measure=ctx => ctx.constraints.max,
    place=ctx => {
      let child_size = ctx.child_sizes[0]
      let x = if ctx.frame.size.width > child_size.width {
        ctx.frame.origin.x +
        markdown_editor_max_double(
          0.0,
          (ctx.frame.size.width - child_size.width) / 2.0,
        )
      } else {
        ctx.frame.origin.x
      }
      let y = ctx.frame.origin.y
      [
        @core.Rect::new(
          x~,
          y~,
          width=child_size.width,
          height=child_size.height,
        ),
      ]
    },
    paint=bounds => {
      [@core.DrawCommand::FillRect(bounds, appearance.window_background)]
    },
    semantics_label="Markdown editor workspace",
  )
}

///|
/// Quiet title bar in Typora style: document title with a subtle unsaved dot
/// on the left, and a single "⋯" menu button on the right. No toolbar
/// clutter — all formatting flows through the format bubble / format palette
/// or keyboard shortcuts. The bottom status bar carries word count and mode
/// indicators so the title bar stays clean and focused on the document name.
fn MarkdownEditorApp::chrome(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  source : String,
  selection : MarkdownEditorSelection,
  width : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let title = markdown_editor_document_title(
    path=self.document_path.get(),
    fallback="Untitled",
  )
  let dirty = self.is_dirty()
  let unsaved_dot = if dirty {
    text("·", width=10.0, height=20.0)
      .font(theme.typography.body)
      .foreground(theme.palette.primary)
  } else {
    empty()
  }
  let title_text = text(title, height=20.0)
    .font(theme.typography.body)
    .foreground(theme.palette.foreground)
  // The "⋯" menu button reuses the More popover (file/view/format commands).
  let menu = self.markdown_editor_more_menu(theme, source, selection)
  frame(
    row(
      [unsaved_dot, title_text, spacer(), menu],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=32.0,
  ).repaint_boundary()
}

///|
/// Minimal bottom status bar: word/line count + active format + mode
/// indicators. Slim enough to stay out of the way while still keeping the
/// writer informed.
fn MarkdownEditorApp::bottom_status_bar(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  snapshot : MarkdownEditorSnapshot,
  block_label : String,
  source : String,
  selection : MarkdownEditorSelection,
  width : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let _ = snapshot
  let _ = block_label
  frame(
    text(
      self.document_status_label(snapshot, block_label, selection) +
      markdown_editor_active_format_suffix(source, selection),
      width~,
      height=18.0,
    )
    .font(theme.typography.caption)
    .foreground(theme.palette.muted.multiply_alpha(0.7)),
    width~,
    height=20.0,
  ).repaint_boundary()
}

///|
fn MarkdownEditorApp::find_bar(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  source : String,
  selection : MarkdownEditorSelection,
  width : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let query = self.find_query.get()
  let matches = markdown_editor_find_matches(
    source,
    query,
    options=self.find_options.get(),
  )
  frame(
    row(
      [
        text("Find", width=44.0, height=34.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text_field(
          query,
          on_input=value => UpdateFindQuery(value),
          on_submit=Some(FindNext),
          placeholder="Search Markdown",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=196.0,
          height=34.0,
        ).key("markdown-find-query"),
        text("Replace", width=64.0, height=34.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text_field(
          self.replace_text.get(),
          on_input=value => UpdateReplaceText(value),
          on_submit=Some(ReplaceFindCurrent),
          placeholder="Replacement",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=196.0,
          height=34.0,
        ).key("markdown-replace-text"),
        editor_find_toggle(
          "Aa",
          "Match case",
          ToggleFindCaseSensitive,
          self.find_options.get().case_sensitive,
          theme,
        ),
        editor_find_toggle(
          "W",
          "Whole word",
          ToggleFindWholeWord,
          self.find_options.get().whole_word,
          theme,
        ),
        editor_find_toggle(
          ".*",
          "Regex",
          ToggleFindRegex,
          self.find_options.get().regex,
          theme,
        ),
        text(
          markdown_editor_find_status_label(query, matches, selection),
          width=72.0,
          height=34.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        editor_find_icon_button(
          @views.IconName::ChevronLeft,
          "Previous match",
          FindPrevious,
          theme,
        ),
        editor_find_icon_button(
          @views.IconName::ChevronRight,
          "Next match",
          FindNext,
          theme,
        ),
        editor_button(
          "Replace",
          ReplaceFindCurrent,
          @views.ButtonVariant::Tonal,
          theme,
        ),
        editor_button("All", ReplaceFindAll, @views.ButtonVariant::Tonal, theme),
        editor_find_icon_button(
          @views.IconName::Close,
          "Close find bar",
          CloseFind,
          theme,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=42.0,
  )
}

///|
fn MarkdownEditorApp::format_palette(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let panel_width = markdown_editor_min_double(540.0, width)
  let content_width = markdown_editor_max_double(
    120.0,
    panel_width - theme.spacing_scale.md * 2.0,
  )
  let query = self.format_palette_query.get()
  let rows : Array[@moui.View[MarkdownEditorMsg]] = []
  for item in markdown_editor_format_palette_filtered_items(query) {
    rows.push(
      markdown_editor_format_palette_row(item, theme, width=content_width),
    )
  }
  if rows.length() == 0 {
    rows.push(
      text("No commands", width=content_width, height=30.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    )
  }
  container(
    padding_edges(
      column(
        [
          row(
            [
              text("Quick Format", width=112.0, height=34.0)
              .font(theme.typography.caption)
              .foreground(theme.palette.muted),
              text_field(
                query,
                on_input=value => UpdateFormatPaletteQuery(value),
                on_submit=Some(ApplyFirstFormatPaletteAction),
                placeholder="Filter",
                variant=@views.TextFieldVariant::Outline,
                theme~,
                width=markdown_editor_max_double(120.0, content_width - 190.0),
                height=34.0,
              ).key("markdown-format-palette-query"),
              editor_button(
                "Done",
                ToggleFormatPalette,
                @views.ButtonVariant::Ghost,
                theme,
              ),
            ],
            spacing=theme.spacing_scale.xs,
            align=@views.CrossAlign::Center,
          ),
          scroll_view(
            column(
              rows,
              spacing=theme.spacing_scale.xs,
              align=@views.CrossAlign::Start,
            ),
            width=content_width,
            height=176.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.sm,
      right=theme.spacing_scale.md,
      bottom=theme.spacing_scale.sm,
      left=theme.spacing_scale.md,
    ),
    width=panel_width,
    height=240.0,
    variant=@views.ContainerVariant::Overlay,
    theme~,
    padding=0.0,
  )
}

///|
fn markdown_editor_format_palette_row(
  item : MarkdownEditorFormatPaletteItem,
  theme : @moui.Theme,
  width~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let label_width = markdown_editor_max_double(120.0, width - 250.0)
  row(
    [
      button(
        item.label,
        on_click=ApplyFormatPaletteAction(item.action),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=label_width,
        height=32.0,
      ),
      text(item.group, width=82.0, height=32.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      text(item.shortcut, width=152.0, height=32.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}

///|
fn markdown_editor_format_palette_filtered_items(
  query : String,
) -> Array[MarkdownEditorFormatPaletteItem] {
  let items = markdown_editor_format_palette_items()
  let needle = query.trim().to_owned().to_lower()
  if needle == "" {
    items
  } else {
    items.filter(item => markdown_editor_format_palette_matches(item, needle))
  }
}

///|
fn markdown_editor_format_palette_matches(
  item : MarkdownEditorFormatPaletteItem,
  needle : String,
) -> Bool {
  item.label.to_lower().contains(needle) ||
  item.group.to_lower().contains(needle) ||
  item.shortcut.to_lower().contains(needle)
}

///|
fn markdown_editor_format_palette_items() -> Array[
  MarkdownEditorFormatPaletteItem,
] {
  [
    {
      action: "paragraph",
      label: "Paragraph",
      group: "Block",
      shortcut: "Meta+0 / Ctrl+0",
    },
    {
      action: "h1",
      label: "Heading 1",
      group: "Block",
      shortcut: "Meta+1 / Ctrl+1",
    },
    {
      action: "h2",
      label: "Heading 2",
      group: "Block",
      shortcut: "Meta+2 / Ctrl+2",
    },
    {
      action: "h3",
      label: "Heading 3",
      group: "Block",
      shortcut: "Meta+3 / Ctrl+3",
    },
    {
      action: "bold",
      label: "Bold",
      group: "Inline",
      shortcut: "Meta+B / Ctrl+B",
    },
    {
      action: "italic",
      label: "Italic",
      group: "Inline",
      shortcut: "Meta+I / Ctrl+I",
    },
    {
      action: "code",
      label: "Inline Code",
      group: "Inline",
      shortcut: "Meta+E / Ctrl+E",
    },
    {
      action: "strike",
      label: "Strikethrough",
      group: "Inline",
      shortcut: "Meta+Shift+X",
    },
    {
      action: "link",
      label: "Link",
      group: "Inline",
      shortcut: "Meta+L / Ctrl+K",
    },
    {
      action: "image",
      label: "Image",
      group: "Inline",
      shortcut: "Meta+Shift+I",
    },
    { action: "ul", label: "Bullet List", group: "Block", shortcut: "Meta+U" },
    { action: "task", label: "Task List", group: "Block", shortcut: "Meta+T" },
    { action: "ol", label: "Ordered List", group: "Block", shortcut: "Meta+O" },
    { action: "quote", label: "Quote", group: "Block", shortcut: "Meta+Q" },
    {
      action: "codeblock",
      label: "Code Block",
      group: "Block",
      shortcut: "Meta+K",
    },
    { action: "table", label: "Table", group: "Block", shortcut: "" },
    {
      action: "toc",
      label: "Table of Contents",
      group: "Document",
      shortcut: "Meta+Alt+T",
    },
    {
      action: "front-matter",
      label: "YAML Front Matter",
      group: "Document",
      shortcut: "Meta+Alt+Y",
    },
    { action: "rule", label: "Horizontal Rule", group: "Block", shortcut: "" },
    {
      action: "duplicate-block",
      label: "Duplicate Block",
      group: "Block",
      shortcut: "Meta+Shift+D",
    },
    {
      action: "focus-mode",
      label: "Focus Mode",
      group: "View",
      shortcut: "Meta+Shift+F",
    },
    {
      action: "typewriter-mode",
      label: "Typewriter Mode",
      group: "View",
      shortcut: "Meta+Shift+T",
    },
    {
      action: "zen-mode",
      label: "Zen Mode",
      group: "View",
      shortcut: "Meta+Alt+Z",
    },
    {
      action: "source-mode",
      label: "Source Mode",
      group: "View",
      shortcut: "Meta+Shift+/",
    },
    {
      action: "files",
      label: "Files",
      group: "View",
      shortcut: "Meta+Alt+P",
    },
    {
      action: "image-center",
      label: "Center Image",
      group: "Block",
      shortcut: "",
    },
    {
      action: "html-export",
      label: "Export HTML",
      group: "Document",
      shortcut: "Meta+Alt+E",
    },
    {
      action: "document-info",
      label: "Document Info",
      group: "View",
      shortcut: "Meta+Alt+D",
    },
    { action: "look-paper", label: "Paper Look", group: "View", shortcut: "" },
    {
      action: "look-warm",
      label: "Warm Look",
      group: "View",
      shortcut: "Meta+Alt+L",
    },
    {
      action: "look-wide",
      label: "Wide Look",
      group: "View",
      shortcut: "Meta+Alt+L",
    },
  ]
}

///|
fn MarkdownEditorApp::document_status_label(
  self : MarkdownEditorApp,
  snapshot : MarkdownEditorSnapshot,
  block_label : String,
  selection : MarkdownEditorSelection,
) -> String {
  let title = markdown_editor_document_title(
    path=self.document_path.get(),
    fallback=snapshot.active_heading,
  )
  let save_state = if self.is_dirty() { "Unsaved" } else { "Saved" }
  let transfer = self.transfer_status_label()
  let transfer_suffix = if transfer == "" { "" } else { " / " + transfer }
  let mode_suffix = self.writing_mode_status_suffix()
  let look_suffix = self.appearance_status_suffix()
  let source_suffix = self.source_mode_status_suffix()
  title +
  " / " +
  save_state +
  " / " +
  markdown_editor_status_label(block_label, snapshot, selection) +
  mode_suffix +
  source_suffix +
  look_suffix +
  transfer_suffix
}

///|
fn MarkdownEditorApp::source_mode_status_suffix(
  self : MarkdownEditorApp,
) -> String {
  if self.source_mode_enabled.get() {
    " / Source Mode"
  } else {
    ""
  }
}

///|
fn MarkdownEditorApp::appearance_status_suffix(
  self : MarkdownEditorApp,
) -> String {
  let label = self.appearance_label()
  if label == "Paper" {
    ""
  } else {
    " / Look: " + label
  }
}

///|
fn MarkdownEditorApp::writing_mode_status_suffix(
  self : MarkdownEditorApp,
) -> String {
  let modes : Array[String] = []
  if self.focus_mode_enabled.get() {
    modes.push("Focus")
  }
  if self.typewriter_mode_enabled.get() {
    modes.push("Typewriter")
  }
  if self.zen_mode_enabled.get() {
    modes.push("Zen")
  }
  if modes.length() == 0 {
    ""
  } else {
    " / " + markdown_join_strings_with_separator(modes, " + ")
  }
}

///|
fn markdown_join_strings_with_separator(
  parts : Array[String],
  separator : String,
) -> String {
  let chars : Array[Char] = []
  for index, part in parts {
    if index > 0 {
      chars.append(separator.to_array())
    }
    chars.append(part.to_array())
  }
  String::from_array(chars)
}

///|
fn markdown_editor_document_info(
  snapshot : MarkdownEditorSnapshot,
) -> MarkdownEditorDocumentInfo {
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_item_count = 0
  let mut task_count = 0
  let mut checked_task_count = 0
  let mut quote_count = 0
  let mut code_block_count = 0
  let mut table_count = 0
  let mut link_count = 0
  let mut image_count = 0
  let mut footnote_reference_count = 0
  let mut footnote_definition_count = 0
  for editor_block in snapshot.blocks {
    match editor_block.block.kind {
      Heading(_) => heading_count = heading_count + 1
      Paragraph =>
        if editor_block.block.text.trim().to_owned() != "" {
          paragraph_count = paragraph_count + 1
        }
      UnorderedListItem | OrderedListItem(_) =>
        list_item_count = list_item_count + 1
      TaskListItem(checked) => {
        task_count = task_count + 1
        list_item_count = list_item_count + 1
        if checked {
          checked_task_count = checked_task_count + 1
        }
      }
      Blockquote => quote_count = quote_count + 1
      CodeBlock => code_block_count = code_block_count + 1
      Table => table_count = table_count + 1
      FootnoteDefinition(_) =>
        footnote_definition_count = footnote_definition_count + 1
      HorizontalRule | HtmlBlock | FrontMatter => ()
    }
    for inline in editor_block.block.inlines {
      match inline.kind {
        Link | Autolink => link_count = link_count + 1
        Image => image_count = image_count + 1
        FootnoteReference =>
          footnote_reference_count = footnote_reference_count + 1
        Plain | Bold | Italic | Code | Strikethrough | HtmlInline => ()
      }
    }
  }
  {
    character_count: markdown_editor_text_length(snapshot.source),
    heading_count,
    paragraph_count,
    list_item_count,
    task_count,
    checked_task_count,
    quote_count,
    code_block_count,
    table_count,
    link_count,
    image_count,
    footnote_reference_count,
    footnote_definition_count,
  }
}

///|
