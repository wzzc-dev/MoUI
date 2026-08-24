///|
fn MarkdownEditorApp::root(
  self : MarkdownEditorApp,
  viewport_width? : Double = 1120.0,
  viewport_height? : Double = 520.0,
) -> @moui.View[MarkdownEditorMsg] {
  let theme = self.chrome_theme()
  let session = self.document_session
  let document = session.source
  let appearance = self.appearance_spec()
  let editor_font = markdown_editor_appearance_font(appearance)
  let zen = self.zen_mode_enabled
  let show_source = if zen { false } else { self.source_preview_visible }
  let show_outline = if zen { false } else { self.outline_visible }
  let show_files = if zen { false } else { self.file_sidebar_visible }
  let show_info = if zen { false } else { self.document_info_visible }
  let workspace_width = markdown_editor_workspace_width(
    show_source,
    show_outline,
    show_files,
    show_info,
    appearance,
    viewport_width~,
  )
  let target_bar = self.target_bar(theme)
  let selection = self.selection
  let target_kind = self.target_kind
  let block_label = self.block_label
  let scroll_offset = self.editor_scroll
  let children : Array[@moui.View[MarkdownEditorMsg]] = []
  if !zen && self.find_visible {
    children.push(self.find_bar(theme, selection, workspace_width))
  }
  if !zen && self.format_palette_visible {
    children.push(self.format_palette(theme, workspace_width))
  }
  children.push(
    editor_source_layout(
      self,
      session,
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
      viewport_width~,
      viewport_height~,
    ),
  )
  let workspace = column(
    children,
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Stretch,
  )
  // The chrome (title bar) lives in the same column as the centered
  // workspace.  Because it is OUTSIDE the workspace's padding edges, its
  // right-side buttons reach the window edge (Typora style).  The
  // centered layout only centers horizontally; the window-background fill
  // is handled by a sibling `fill` view so `centered` does not need
  // `constraints.max` and can live happily inside a column.
  let outer_children : Array[@moui.View[MarkdownEditorMsg]] = []
  if !zen {
    outer_children.push(self.chrome(theme))
  }
  // Use a spacer for bottom padding instead of padding_edges, because
  // padding_layout clamps child frame width to min(available, intrinsic),
  // which would prevent the workspace from filling the window width.
  outer_children.push(workspace.expanded())
  outer_children.push(spacer(min_length=theme.spacing_scale.xl, weight=0.0))
  if !zen {
    outer_children.push(
      self.bottom_status_bar(
        theme, session, block_label, document, selection, workspace_width,
      ),
    )
  }
  let outer = column(
    outer_children,
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
  // Stack: background fill → outer column (chrome + workspace) → overlays.
  let no_views : Array[@moui.View[MarkdownEditorMsg]] = []
  let window_bg = @views.custom_children_layout(
    children=no_views,
    measure=ctx => ctx.constraints.constrain(ctx.constraints.max),
    place=_ctx => {
      let rects : Array[@geometry.Rect] = []
      rects
    },
    paint=(ctx, bounds) => fill_rect(ctx, bounds, appearance.window_background),
    semantics_label="Window background",
  )
  let layers : Array[@moui.View[MarkdownEditorMsg]] = [window_bg, outer]
  layers.push(
    @views.align(
      self.toast_layer(theme),
      alignment=@geometry.Alignment::new(x=0.5, y=0.0),
    ),
  )
  layers.push(
    @views.align(
      self.confirm_dialog(theme),
      alignment=@geometry.Alignment::center(),
    ),
  )
  @views.stack(layers)
}

///|
/// Adapt the host viewport to the editor's fixed chrome and auxiliary panels.
/// This keeps the app on the immutable Program/ViewEnvironment path without
/// requiring a component-scoped context.
fn MarkdownEditorApp::root_with_environment(
  self : MarkdownEditorApp,
  view_environment : @core.ViewEnvironment,
) -> @moui.View[MarkdownEditorMsg] {
  let viewport = view_environment.viewport_size()
  let theme = self.chrome_theme()
  let zen = self.zen_mode_enabled
  let mut fixed_height = theme.spacing_scale.xl
  if !zen {
    fixed_height = fixed_height + 28.0 + 20.0
    let mut auxiliary_count = 0
    if self.find_visible {
      fixed_height = fixed_height + 42.0
      auxiliary_count = auxiliary_count + 1
    }
    if self.format_palette_visible {
      fixed_height = fixed_height + 240.0
      auxiliary_count = auxiliary_count + 1
    }
    fixed_height = fixed_height +
      theme.spacing_scale.sm * auxiliary_count.to_double()
  }
  let viewport_height = markdown_editor_max_double(
    320.0,
    viewport.height - fixed_height,
  )
  self.root(viewport_width=viewport.width, viewport_height~)
}

///|
/// Resolve the chrome theme from the dark-mode toggle. The framework ships a
/// full dark theme (`@views.dark_theme()`), so toggling is a one-liner here;
/// the editor surface and panels inherit the theme via the environment.
fn MarkdownEditorApp::chrome_theme(self : MarkdownEditorApp) -> @moui.Theme {
  if self.dark_mode_enabled {
    @views.dark_theme()
  } else {
    @views.light_theme()
  }
}

///|
fn markdown_editor_workspace_width(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  appearance : MarkdownEditorAppearanceSpec,
  viewport_width~ : Double,
) -> Double {
  let editor_width = markdown_editor_primary_editor_width_for_viewport(
    show_source,
    show_outline,
    show_files,
    show_info,
    appearance,
    viewport_width~,
  )
  let sidebars_width = markdown_editor_sidebar_total_width(
    show_source, show_outline, show_files, show_info,
  )
  markdown_editor_min_double(viewport_width, editor_width + sidebars_width)
}

///|
/// Typora-style title bar: sits inside the transparent 28px macOS titlebar
/// region. Left: traffic-light space. Center: file name + chevron.
/// Right: outline toggle, sidebar toggle.
///
/// Rendered as a stack overlay pinned to the top edge (alignment x=0, y=0).
/// The width is unconstrained — it inherits the full window width from the
/// stack frame — so right-side buttons reach the window edge like Typora.
/// `frame(height=28.0)` fixes the vertical size.
fn MarkdownEditorApp::chrome(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let title = markdown_editor_document_title(
    path=self.document_path,
    fallback="Untitled",
  )
  let dirty = self.is_dirty()
  let unsaved_dot = if dirty {
    text("·", width=8.0, height=16.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.primary)
  } else {
    empty()
  }

  // Center: clickable title + chevron (toggles document info)
  let title_button = button(
      title,
      on_click=ToggleDocumentInfo,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      height=22.0,
    )
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)

  let outline_btn = button(
    "",
    on_click=ToggleOutline,
    variant=if self.outline_visible {
      @views.ButtonVariant::Tonal
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    icon=Some(@views.IconName::ListBullet),
    width=26.0,
    height=22.0,
  )

  let right_group = row(
    [outline_btn],
    spacing=2.0,
    align=@views.CrossAlign::Center,
  )

  frame(
    row(
      [
        spacer(min_length=78.0, weight=1.0),
        title_button,
        unsaved_dot,
        spacer(min_length=0.0, weight=1.0),
        right_group,
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Center,
    ),
    height=28.0,
  ).repaint_boundary()
}

///|
/// Minimal bottom status bar: tree toggle + concise status + word count.
fn MarkdownEditorApp::bottom_status_bar(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  session : MarkdownDocumentSession,
  block_label : String,
  _source : String,
  selection : MarkdownEditorSelection,
  width : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let show_files = self.file_sidebar_visible
  let tree_button = button(
    "",
    on_click=ToggleFileSidebar,
    variant=if show_files {
      @views.ButtonVariant::Tonal
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    icon=Some(@views.IconName::Sidebar),
    width=26.0,
    height=20.0,
  )

  let save_state = if self.is_dirty() { "Unsaved" } else { "Saved" }
  let transfer = markdown_editor_transfer_status_label(self.transfer_status)
  let transfer_suffix = if transfer == "" { "" } else { " / " + transfer }
  let status = save_state +
    " / " +
    markdown_editor_session_status_label(block_label, session, selection) +
    transfer_suffix

  // 状态文字宽度自适应：最小 160px，最大撑满窗口宽度（减去 tree_button 26px），
  // 不再限制 500px 上限，长状态也能完整显示。
  let status_width = markdown_editor_max_double(160.0, width - 26.0)
  let status_frame = frame(
    row(
      [
        spacer(min_length=0.0, weight=1.0),
        text(status, width=status_width, height=15.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted.multiply_alpha(0.7)),
        spacer(min_length=0.0, weight=1.0),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Center,
    ),
    height=20.0,
  ).repaint_boundary()
  let tree_aligned = @views.align(
    tree_button,
    alignment=@geometry.Alignment::new(x=-1.0, y=0.0),
  )
  @views.stack([status_frame, tree_aligned])
}

///|
fn MarkdownEditorApp::find_bar(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  selection : MarkdownEditorSelection,
  width : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let query = self.find_query
  let matches = self.find_matches
  let options = self.find_options
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
          self.replace_text,
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
          options.case_sensitive,
          theme,
        ),
        editor_find_toggle(
          "W",
          "Whole word",
          ToggleFindWholeWord,
          options.whole_word,
          theme,
        ),
        editor_find_toggle(".*", "Regex", ToggleFindRegex, options.regex, theme),
        text(
          markdown_editor_find_status_label(query, matches, selection, options~),
          width=88.0,
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
  let query = self.format_palette_query
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
    { action: "files", label: "Files", group: "View", shortcut: "Meta+Alt+P" },
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
#warnings("-unused_value")
fn MarkdownEditorApp::source_mode_status_suffix(
  self : MarkdownEditorApp,
) -> String {
  if self.source_mode_enabled {
    " / Source Mode"
  } else {
    ""
  }
}

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
fn MarkdownEditorApp::writing_mode_status_suffix(
  self : MarkdownEditorApp,
) -> String {
  let modes : Array[String] = []
  if self.focus_mode_enabled {
    modes.push("Focus")
  }
  if self.typewriter_mode_enabled {
    modes.push("Typewriter")
  }
  if self.zen_mode_enabled {
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
#warnings("-unused_value")
fn markdown_editor_document_info(
  snapshot : MarkdownEditorSnapshot,
) -> MarkdownEditorDocumentInfo {
  markdown_editor_document_info_from_parts(snapshot.source, snapshot.blocks)
}

///|
fn markdown_editor_document_info_from_session(
  session : MarkdownDocumentSession,
) -> MarkdownEditorDocumentInfo {
  markdown_editor_document_info_from_parts(
    session.source,
    session.editor_blocks,
  )
}

///|
fn markdown_editor_document_info_from_parts(
  source : String,
  blocks : Array[MarkdownEditorBlock],
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
  for editor_block in blocks {
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
    character_count: markdown_editor_text_length(source),
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
