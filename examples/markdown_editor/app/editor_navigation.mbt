///|
fn MarkdownEditorApp::toggle_source_preview(self : MarkdownEditorApp) -> Unit {
  self.source_preview_visible.set(!self.source_preview_visible.get())
}

///|
fn MarkdownEditorApp::toggle_source_mode(self : MarkdownEditorApp) -> Unit {
  self.source_mode_enabled.set(!self.source_mode_enabled.get())
}

///|
fn MarkdownEditorApp::toggle_outline(self : MarkdownEditorApp) -> Unit {
  self.outline_visible.set(!self.outline_visible.get())
}

///|
fn MarkdownEditorApp::toggle_file_sidebar(self : MarkdownEditorApp) -> Unit {
  self.file_sidebar_visible.set(!self.file_sidebar_visible.get())
}

///|
fn MarkdownEditorApp::toggle_document_info(self : MarkdownEditorApp) -> Unit {
  self.document_info_visible.set(!self.document_info_visible.get())
}

///|
fn MarkdownEditorApp::toggle_focus_mode(self : MarkdownEditorApp) -> Unit {
  self.focus_mode_enabled.set(!self.focus_mode_enabled.get())
}

///|
fn MarkdownEditorApp::toggle_typewriter_mode(self : MarkdownEditorApp) -> Unit {
  self.typewriter_mode_enabled.set(!self.typewriter_mode_enabled.get())
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::toggle_zen_mode(self : MarkdownEditorApp) -> Unit {
  if self.zen_mode_enabled.get() {
    self.zen_mode_enabled.set(false)
  } else {
    self.zen_mode_enabled.set(true)
    self.close_find()
    self.reset_format_palette()
    self.file_sidebar_visible.set(false)
    self.document_info_visible.set(false)
    self.outline_visible.set(false)
    self.source_preview_visible.set(false)
  }
}

///|
fn MarkdownEditorApp::toggle_format_palette(self : MarkdownEditorApp) -> Unit {
  if self.format_palette_visible.get() {
    self.reset_format_palette()
  } else {
    self.format_palette_visible.set(true)
  }
}

///|
fn MarkdownEditorApp::reset_format_palette(self : MarkdownEditorApp) -> Unit {
  self.format_palette_visible.set(false)
  self.format_palette_query.set("")
}

///|
fn MarkdownEditorApp::cycle_writing_appearance(
  self : MarkdownEditorApp,
) -> Unit {
  self.writing_appearance.set(self.writing_appearance.get().next())
}

///|
fn MarkdownEditorApp::set_writing_appearance(
  self : MarkdownEditorApp,
  appearance : MarkdownEditorAppearance,
) -> Unit {
  self.writing_appearance.set(appearance)
}

///|
fn MarkdownEditorApp::toggle_find(self : MarkdownEditorApp) -> Unit {
  if self.find_visible.get() {
    self.find_visible.set(false)
  } else {
    self.open_find()
  }
}

///|
fn MarkdownEditorApp::open_find(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(true)
  match
    markdown_editor_find_query_from_selection(
      self.document.get(),
      self.selection.get(),
    ) {
    Some(query) => self.find_query.set(query)
    None =>
      match
        markdown_editor_find_seed_from_caret_word(
          self.document.get(),
          self.selection.get(),
        ) {
        Some(seed) => {
          self.find_query.set(seed.query)
          self.select_find_match(seed.range)
        }
        None => ()
      }
  }
}

///|
fn MarkdownEditorApp::close_find(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(false)
}

///|
fn MarkdownEditorApp::reset_find_session(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(false)
  self.find_query.set("")
  self.replace_text.set("")
}

///|
fn MarkdownEditorApp::dismiss_auxiliary_panels(
  self : MarkdownEditorApp,
) -> Unit {
  if self.zen_mode_enabled.get() {
    self.zen_mode_enabled.set(false)
  } else if self.find_visible.get() {
    self.close_find()
  } else if self.format_palette_visible.get() ||
    self.file_sidebar_visible.get() ||
    self.document_info_visible.get() ||
    self.outline_visible.get() ||
    self.source_preview_visible.get() {
    self.reset_format_palette()
    self.file_sidebar_visible.set(false)
    self.document_info_visible.set(false)
    self.outline_visible.set(false)
    self.source_preview_visible.set(false)
  } else {
    let selection = self.selection.get()
    if selection.selection is Some(_) {
      self.selection.set({ caret: selection.caret, selection: None })
      self.sync_target_inputs()
    }
  }
}

///|
fn MarkdownEditorApp::jump_to_outline(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Unit {
  let caret = markdown_editor_clamp_int(
    source_start,
    0,
    markdown_editor_text_length(self.document.get()),
  )
  self.selection.set({ caret, selection: None })
  self.sync_target_inputs()
  self.scroll_to_source(caret)
}

///|
fn MarkdownEditorApp::maybe_center_typewriter_selection(
  self : MarkdownEditorApp,
) -> Unit {
  if self.typewriter_mode_enabled.get() {
    let selection = self.selection.get()
    let anchor = match selection.selection {
      Some(range) => range.normalized().start
      None => selection.caret
    }
    self.center_typewriter_source(anchor)
  }
}

///|
fn MarkdownEditorApp::jump_to_next_heading(self : MarkdownEditorApp) -> Unit {
  let snapshot = MarkdownEditorSnapshot::parse(self.document.get())
  match
    markdown_editor_next_outline_start(
      snapshot.outline,
      self.selection.get().caret,
    ) {
    Some(source_start) => self.jump_to_outline(source_start)
    None => ()
  }
}

///|
fn MarkdownEditorApp::jump_to_previous_heading(
  self : MarkdownEditorApp,
) -> Unit {
  let snapshot = MarkdownEditorSnapshot::parse(self.document.get())
  match
    markdown_editor_previous_outline_start(
      snapshot.outline,
      self.selection.get().caret,
    ) {
    Some(source_start) => self.jump_to_outline(source_start)
    None => ()
  }
}

///|
fn markdown_editor_next_outline_start(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int,
) -> Int? {
  if outline.length() == 0 {
    return None
  }
  for item in outline {
    if item.source_start > caret {
      return Some(item.source_start)
    }
  }
  Some(outline[0].source_start)
}

///|
fn markdown_editor_previous_outline_start(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int,
) -> Int? {
  if outline.length() == 0 {
    return None
  }
  let mut previous : Int? = None
  for item in outline {
    if item.source_start < caret {
      previous = Some(item.source_start)
    }
  }
  match previous {
    Some(source_start) => Some(source_start)
    None => Some(outline[outline.length() - 1].source_start)
  }
}

///|
fn MarkdownEditorApp::scroll_to_source(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Unit {
  self.scroll_to_source_with_anchor(source_start, center=false)
}

///|
fn MarkdownEditorApp::center_typewriter_source(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Unit {
  self.scroll_to_source_with_anchor(source_start, center=true)
}

///|
fn MarkdownEditorApp::scroll_to_source_with_anchor(
  self : MarkdownEditorApp,
  source_start : Int,
  center~ : Bool,
) -> Unit {
  let appearance = self.appearance_spec()
  let editor_font = markdown_editor_appearance_font(appearance)
  let snapshot = MarkdownEditorSnapshot::parse_with_font(
    self.document.get(),
    editor_font,
  )
  let editor_width = markdown_editor_primary_editor_width(
    self.source_preview_visible.get(),
    self.outline_visible.get(),
    self.file_sidebar_visible.get(),
    self.document_info_visible.get(),
    appearance,
  )
  let viewport_height = markdown_editor_viewport_height()
  let content_height = markdown_editor_max_double(
    viewport_height,
    @core.rich_text_document_height(snapshot.rich_text, editor_font) + 96.0,
  )
  let max_scroll = markdown_editor_max_double(
    0.0,
    content_height - viewport_height,
  )
  let editor_frame = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=editor_width,
    height=content_height,
  )
  let content = @core.rich_text_editor_content_rect(editor_frame)
  match
    @core.rich_text_document_caret_rect_at_source(
      snapshot.rich_text,
      source_start,
      content,
      editor_font,
    ) {
    Some(rect) =>
      self.editor_scroll.scroll_to(
        x=0.0,
        y=markdown_editor_clamp_double(
          markdown_editor_scroll_anchor_y(rect, viewport_height, center~),
          0.0,
          max_scroll,
        ),
      )
    None => self.editor_scroll.scroll_to(x=0.0, y=0.0)
  }
}

///|
fn markdown_editor_scroll_anchor_y(
  rect : @core.Rect,
  viewport_height : Double,
  center~ : Bool,
) -> Double {
  if center {
    rect.origin.y + rect.size.height / 2.0 - viewport_height / 2.0
  } else {
    rect.origin.y - 48.0
  }
}

///|
fn MarkdownEditorApp::find_next(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(true)
  let matches = markdown_editor_find_matches(
    self.document.get(),
    self.find_query.get(),
  )
  if matches.length() == 0 {
    return
  }
  let index = markdown_editor_find_next_index(matches, self.selection.get())
  self.select_find_match(matches[index])
}

///|
fn MarkdownEditorApp::find_previous(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(true)
  let matches = markdown_editor_find_matches(
    self.document.get(),
    self.find_query.get(),
  )
  if matches.length() == 0 {
    return
  }
  let index = markdown_editor_find_previous_index(matches, self.selection.get())
  self.select_find_match(matches[index])
}

///|
fn MarkdownEditorApp::update_find_query(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.find_query.set(query)
  if !self.find_visible.get() {
    return
  }
  if query == "" {
    let selection = self.selection.get()
    if selection.selection is Some(_) {
      self.selection.set({ caret: selection.caret, selection: None })
      self.sync_target_inputs()
    }
    return
  }
  let matches = markdown_editor_find_matches(self.document.get(), query)
  if matches.length() == 0 {
    let selection = self.selection.get()
    if selection.selection is Some(_) {
      self.selection.set({ caret: selection.caret, selection: None })
      self.sync_target_inputs()
    }
    return
  }
  let index = markdown_editor_find_live_update_index(
    matches,
    self.selection.get(),
  )
  if index >= 0 {
    self.select_find_match(matches[index])
  }
}

///|
fn MarkdownEditorApp::select_find_match(
  self : MarkdownEditorApp,
  range : @core.TextRange,
) -> Unit {
  self.selection.set({ caret: range.end, selection: Some(range) })
  self.sync_target_inputs()
  self.scroll_to_source(range.start)
}

///|
fn MarkdownEditorApp::replace_current_find_match(
  self : MarkdownEditorApp,
) -> Unit {
  let source = self.document.get()
  let query = self.find_query.get()
  let replacement = self.replace_text.get()
  let matches = markdown_editor_find_matches(source, query)
  if matches.length() == 0 {
    return
  }
  let active = markdown_editor_find_active_index(matches, self.selection.get())
  let index = if active >= 0 {
    active
  } else {
    markdown_editor_find_next_index(matches, self.selection.get())
  }
  let range = matches[index]
  let before = self.history_entry()
  let next_source = markdown_editor_replace_source_range(
    source, range, replacement,
  )
  if next_source == source {
    return
  }
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(next_source)
  let end = range.start + markdown_editor_text_length(replacement)
  let next_matches = markdown_editor_find_matches(next_source, query)
  match
    markdown_editor_next_match_after_replacement(next_matches, range.start, end) {
    Some(next_range) => self.select_find_match(next_range)
    None => {
      self.selection.set({
        caret: end,
        selection: markdown_editor_replacement_selection(range.start, end),
      })
      self.sync_target_inputs()
      self.scroll_to_source(range.start)
    }
  }
}

///|
fn MarkdownEditorApp::replace_all_find_matches(
  self : MarkdownEditorApp,
) -> Unit {
  let source = self.document.get()
  let query = self.find_query.get()
  let replacement = self.replace_text.get()
  let matches = markdown_editor_find_matches(source, query)
  if matches.length() == 0 {
    return
  }
  let next_source = markdown_editor_replace_all_matches(
    source, matches, replacement,
  )
  if next_source == source {
    return
  }
  let before = self.history_entry()
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(next_source)
  let start = matches[0].start
  let end = start + markdown_editor_text_length(replacement)
  self.selection.set({
    caret: end,
    selection: markdown_editor_replacement_selection(start, end),
  })
  self.sync_target_inputs()
  self.scroll_to_source(start)
}

///|
fn MarkdownEditorApp::sync_target_inputs(self : MarkdownEditorApp) -> Unit {
  let selection = self.selection.get()
  let block_label = markdown_editor_active_block_label(
    self.document.get(),
    selection,
  )
  self.block_label.set(block_label)
  match markdown_editor_selected_link_target(self.document.get(), selection) {
    Some(target) => {
      self.link_target.set(target)
      self.target_kind.set(LinkTarget)
      return
    }
    None => ()
  }
  match markdown_editor_selected_image_target(self.document.get(), selection) {
    Some(target) => {
      self.image_target.set(target)
      self.target_kind.set(ImageTarget)
    }
    None =>
      match
        markdown_editor_selected_footnote_text(self.document.get(), selection) {
        Some(text) => {
          self.footnote_text.set(text)
          self.target_kind.set(FootnoteTarget)
        }
        None =>
          match
            markdown_editor_selected_html_block_text(
              self.document.get(),
              selection,
            ) {
            Some(text) => {
              self.html_block_text.set(text)
              self.target_kind.set(HtmlBlockTarget)
            }
            None =>
              if block_label == "Table" {
                self.target_kind.set(TableTools)
              } else {
                self.target_kind.set(PlainSelection)
              }
          }
      }
  }
}

///|
