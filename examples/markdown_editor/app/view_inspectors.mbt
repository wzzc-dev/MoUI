///|
fn markdown_editor_reading_label(snapshot : MarkdownEditorSnapshot) -> String {
  let minutes = if snapshot.reading_minutes == 0 {
    "less than 1 min"
  } else if snapshot.reading_minutes == 1 {
    "1 min"
  } else {
    snapshot.reading_minutes.to_string() + " min"
  }
  "\{snapshot.word_count} words / \{snapshot.line_count} lines / " + minutes
}

///|
fn markdown_editor_session_reading_label(
  session : MarkdownDocumentSession,
) -> String {
  let minutes = if session.reading_minutes == 0 {
    "less than 1 min"
  } else if session.reading_minutes == 1 {
    "1 min"
  } else {
    session.reading_minutes.to_string() + " min"
  }
  "\{session.word_count} words / \{session.line_count} lines / " + minutes
}

///|
fn files_inspector(
  app : MarkdownEditorApp,
  session : MarkdownDocumentSession,
  theme : @moui.Theme,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let content_width = markdown_editor_file_sidebar_content_width()
  let recent_paths = app.recent_document_paths.get()
  let recent_content = if recent_paths.length() == 0 {
    text("No recent files", width=content_width, height=28.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)
  } else {
    scroll_view(
      file_sidebar_recent_rows(
        recent_paths,
        current_path=app.document_path.get(),
        theme,
      ),
      width=content_width,
      height=markdown_editor_max_double(0.0, height - 180.0),
    )
  }
  let working_directory = app.working_directory.get()
  let file_rows : Array[@moui.View[MarkdownEditorMsg]] = [
    text("Files", width=content_width, height=24.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted),
    text(
      markdown_editor_file_sidebar_current_label(
        path=app.document_path.get(),
        fallback=session.active_heading,
        dirty=app.is_dirty(),
      ),
      width=content_width,
      height=30.0,
    )
    .font(theme.typography.caption)
    .foreground(theme.palette.foreground),
    editor_button(
      if working_directory == "" {
        "Pick folder"
      } else {
        "Change folder"
      },
      PickWorkingDirectory,
      @views.ButtonVariant::Ghost,
      theme,
    ),
  ]
  if working_directory != "" {
    let tree_expanded = app.file_tree_expanded.get()
    let fold_label = if tree_expanded { "▾" } else { "▸" }
    file_rows.push(
      row(
        [
          text("Folder", width=content_width - 28.0, height=24.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          button(
            fold_label,
            on_click=ToggleFileTree,
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=24.0,
            height=24.0,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      ),
    )
    if tree_expanded {
      file_rows.push(
        @views.tree_view(
          app.directory_tree_items.get(),
          expanded=app.expanded_tree_paths.get(),
          on_select=Some(id => SelectTreePath(id)),
          on_toggle=Some(id => ToggleTreePath(id)),
          theme~,
          width=content_width,
        ),
      )
    }
  }
  file_rows.push(
    text("Recent", width=content_width, height=24.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted),
  )
  file_rows.push(recent_content)
  container(
    padding_edges(
      column(
        file_rows,
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=markdown_editor_file_sidebar_width(),
    height~,
    variant=@views.ContainerVariant::Base,
    theme~,
    background=theme.palette.surface,
    corner_radius=theme.radius_scale.sm,
    padding=0.0,
  )
}

///|
fn document_info_inspector(
  session : MarkdownDocumentSession,
  theme : @moui.Theme,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let info = markdown_editor_document_info_from_session(session)
  let content_width = markdown_editor_info_content_width()
  let rows = column(
    [
      markdown_editor_info_row("Words", session.word_count.to_string(), theme),
      markdown_editor_info_row(
        "Characters",
        info.character_count.to_string(),
        theme,
      ),
      markdown_editor_info_row("Lines", session.line_count.to_string(), theme),
      markdown_editor_info_row(
        "Reading",
        markdown_editor_session_reading_time_short_label(session),
        theme,
      ),
      markdown_editor_info_divider(theme),
      markdown_editor_info_row(
        "Headings",
        info.heading_count.to_string(),
        theme,
      ),
      markdown_editor_info_row(
        "Paragraphs",
        info.paragraph_count.to_string(),
        theme,
      ),
      markdown_editor_info_row(
        "List items",
        info.list_item_count.to_string(),
        theme,
      ),
      markdown_editor_info_row(
        "Tasks",
        info.checked_task_count.to_string() + "/" + info.task_count.to_string(),
        theme,
      ),
      markdown_editor_info_row("Quotes", info.quote_count.to_string(), theme),
      markdown_editor_info_divider(theme),
      markdown_editor_info_row(
        "Code blocks",
        info.code_block_count.to_string(),
        theme,
      ),
      markdown_editor_info_row("Tables", info.table_count.to_string(), theme),
      markdown_editor_info_row("Links", info.link_count.to_string(), theme),
      markdown_editor_info_row("Images", info.image_count.to_string(), theme),
      markdown_editor_info_row(
        "Footnotes",
        info.footnote_reference_count.to_string() +
        "/" +
        info.footnote_definition_count.to_string(),
        theme,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Start,
  )
  container(
    padding_edges(
      column(
        [
          text("Info", width=content_width, height=24.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          scroll_view(
            rows,
            width=content_width,
            height=markdown_editor_max_double(0.0, height - 52.0),
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=markdown_editor_info_inspector_width(),
    height~,
    variant=@views.ContainerVariant::Base,
    theme~,
    background=theme.palette.surface,
    corner_radius=theme.radius_scale.sm,
    padding=0.0,
  )
}

///|
fn markdown_editor_info_row(
  label : String,
  value : String,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  row(
    [
      text(label, width=126.0, height=24.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      text(value, width=80.0, height=24.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}

///|
fn markdown_editor_info_divider(
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  frame(empty(), width=markdown_editor_info_content_width(), height=1.0).background(
    theme.palette.muted.multiply_alpha(0.24),
  )
}

///|
#warnings("-unused_value")
fn markdown_editor_reading_time_short_label(
  snapshot : MarkdownEditorSnapshot,
) -> String {
  if snapshot.reading_minutes == 0 {
    "<1 min"
  } else if snapshot.reading_minutes == 1 {
    "1 min"
  } else {
    snapshot.reading_minutes.to_string() + " min"
  }
}

///|
fn markdown_editor_session_reading_time_short_label(
  session : MarkdownDocumentSession,
) -> String {
  if session.reading_minutes == 0 {
    "<1 min"
  } else if session.reading_minutes == 1 {
    "1 min"
  } else {
    session.reading_minutes.to_string() + " min"
  }
}

///|
fn file_sidebar_recent_rows(
  paths : Array[String],
  current_path~ : String,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let rows : Array[@moui.View[MarkdownEditorMsg]] = []
  for path in paths {
    rows.push(
      file_sidebar_recent_row(path, current=path == current_path, theme),
    )
  }
  column(rows, spacing=theme.spacing_scale.xs, align=@views.CrossAlign::Start)
}

///|
fn file_sidebar_recent_row(
  path : String,
  current~ : Bool,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  button(
    markdown_editor_file_sidebar_recent_label(path),
    on_click=OpenRecentDocument(path),
    variant=if current {
      @views.ButtonVariant::Tonal
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    width=markdown_editor_file_sidebar_content_width(),
    height=30.0,
  )
}

///|
fn markdown_editor_file_sidebar_current_label(
  path~ : String,
  fallback~ : String,
  dirty~ : Bool,
) -> String {
  let suffix = if dirty { " / Unsaved" } else { " / Saved" }
  markdown_editor_document_title(path~, fallback~) + suffix
}

///|
fn markdown_editor_file_sidebar_recent_label(path : String) -> String {
  let file = markdown_editor_file_name(path)
  if file == "" {
    "Untitled"
  } else {
    markdown_editor_outline_title(file)
  }
}

///|
fn source_preview(
  text : String,
  theme : @moui.Theme,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  scroll_view(source_preview_lines(text, theme), width=260.0, height~)
}

///|
fn source_inspector(
  source : String,
  theme : @moui.Theme,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  container(
    padding_edges(
      column(
        [
          text("Markdown source", width=260.0, height=24.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          source_preview(
            source,
            theme,
            height=markdown_editor_max_double(0.0, height - 52.0),
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=markdown_editor_source_inspector_width(),
    height~,
    variant=@views.ContainerVariant::Base,
    theme~,
    background=theme.palette.surface,
    corner_radius=theme.radius_scale.sm,
    padding=0.0,
  )
}

///|
fn outline_inspector(
  app : MarkdownEditorApp,
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  theme : @moui.Theme,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let visible_outline = markdown_editor_folded_outline(
    session.outline,
    app.folded_headings.get(),
  )
  let active_index = markdown_editor_active_outline_index(
    session.outline,
    selection.caret,
  )
  let content = if visible_outline.length() == 0 {
    text(
      "No headings",
      width=markdown_editor_outline_content_width(),
      height=28.0,
    )
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)
  } else {
    scroll_view(
      outline_rows(app, session.outline, visible_outline, active_index, theme),
      width=markdown_editor_outline_content_width(),
      height=markdown_editor_max_double(0.0, height - 52.0),
    )
  }
  container(
    padding_edges(
      column(
        [
          text(
            "Outline",
            width=markdown_editor_outline_content_width(),
            height=24.0,
          )
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          content,
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=markdown_editor_outline_inspector_width(),
    height~,
    variant=@views.ContainerVariant::Base,
    theme~,
    background=theme.palette.surface,
    corner_radius=theme.radius_scale.sm,
    padding=0.0,
  )
}

///|
fn outline_rows(
  app : MarkdownEditorApp,
  full_outline : Array[MarkdownEditorOutlineItem],
  visible : Array[MarkdownEditorOutlineItem],
  active_index : Int,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let rows : Array[@moui.View[MarkdownEditorMsg]] = []
  for item in visible {
    let active = markdown_editor_outline_item_is_active(
      full_outline, item, active_index,
    )
    rows.push(outline_row(app, item, active~, theme))
  }
  column(rows, spacing=theme.spacing_scale.xs, align=@views.CrossAlign::Start)
}

///|
/// True when `item` matches the outline entry at `active_index` in the full
/// outline (so the active heading stays highlighted even while some are folded).
fn markdown_editor_outline_item_is_active(
  full_outline : Array[MarkdownEditorOutlineItem],
  item : MarkdownEditorOutlineItem,
  active_index : Int,
) -> Bool {
  if active_index < 0 || active_index >= full_outline.length() {
    false
  } else {
    full_outline[active_index].source_start == item.source_start
  }
}

///|
fn outline_row(
  app : MarkdownEditorApp,
  item : MarkdownEditorOutlineItem,
  active~ : Bool,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let indent = markdown_editor_outline_indent_width(item.level)
  // A folded heading renders a '▸' prefix in its label to signal the folded
  // state; tapping the row still jumps to the heading. The dedicated toggle
  // affordance is intentionally not a separate button to preserve the row's
  // indent geometry that existing tests rely on.
  let folded = app.heading_is_folded(item.source_start)
  let label = if folded {
    "▸ " + markdown_editor_outline_label(item)
  } else {
    markdown_editor_outline_label(item)
  }
  padding_edges(
    button(
      label,
      on_click=JumpToOutline(item.source_start),
      variant=if active {
        @views.ButtonVariant::Tonal
      } else {
        @views.ButtonVariant::Ghost
      },
      theme~,
      width=markdown_editor_max_double(
        96.0,
        markdown_editor_outline_content_width() - indent,
      ),
      height=30.0,
    ).on_long_press(ToggleHeadingFold(item.source_start)),
    left=indent,
  )
}

///|

///|
fn markdown_editor_outline_indent_width(level : Int) -> Double {
  markdown_editor_max_int(0, level - 1).to_double() * 12.0
}

///|
fn markdown_editor_outline_label(item : MarkdownEditorOutlineItem) -> String {
  let title = if item.title == "" { "Untitled" } else { item.title }
  "H" + item.level.to_string() + " " + markdown_editor_outline_title(title)
}

///|
fn markdown_editor_outline_title(title : String) -> String {
  if markdown_editor_text_length(title) <= 24 {
    title
  } else {
    markdown_editor_substring(title, 0, 21) + "..."
  }
}

///|
fn markdown_editor_active_outline_index(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int,
) -> Int {
  let mut active = -1
  for index in 0..<outline.length() {
    if outline[index].source_start <= caret {
      active = index
    }
  }
  active
}

///|
