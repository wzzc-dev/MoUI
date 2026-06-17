///|
/// App-facing rich text document contracts are exposed from views.
pub using @widget {type RichTextFormatter}

///|
pub using @widget {type RichTextInputTransform}

///|
pub using @widget {type RichTextSourceRange}

///|
pub using @widget {type RichTextDecoration}

///|
pub using @widget {type RichTextRun}

///|
pub using @widget {type RichTextTableCell}

///|
pub using @widget {type RichTextTable}

///|
pub using @widget {type RichTextBlock}

///|
pub using @widget {type RichTextDocument}

///|
pub fn rich_text_editor_content_rect(frame : @core.Rect) -> @core.Rect {
  @widget.rich_text_editor_content_rect(frame)
}

///|
pub fn rich_text_document_height(
  document : RichTextDocument,
  base_font : @core.FontSpec,
) -> Double {
  @widget.rich_text_document_height(document, base_font)
}

///|
pub fn rich_text_document_caret_rect_at_source(
  document : RichTextDocument,
  source_caret : Int,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> @core.Rect? {
  @widget.rich_text_document_caret_rect_at_source(
    document,
    source_caret,
    content,
    base_font,
    text_system~,
  )
}
