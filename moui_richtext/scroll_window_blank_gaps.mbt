///|
priv struct MarkdownWindowBlankGapRun {
  document_identity : Int32
  revision : Int32
  start : Int32
  end : Int32
}

///|
let markdown_window_blank_gap_run : Ref[MarkdownWindowBlankGapRun?] = Ref(None)

///|
/// The leading gap keeps its position in the document's blank-line run even
/// when the viewport starts partway through it. Cache that run, so scrolling
/// through a large empty region scans its boundaries only once per revision.
/// A window containing only gaps is a writing surface only when the entire
/// document is blank, not merely when the neighboring content is off-screen.
fn markdown_document_window_blank_gap_context(
  session : MarkdownDocumentSession,
  visible_start : Int32,
) -> (Int32, Bool) {
  let blocks = session.editor_blocks
  guard blocks.get(visible_start) is Some(block) else { return (0, false) }
  if !markdown_document_editor_block_is_blank(block) {
    return (0, true)
  }
  let run = match markdown_window_blank_gap_run.val {
    Some(run) if run.document_identity == session.document_identity &&
      run.revision == session.revision &&
      visible_start >= run.start &&
      visible_start < run.end => run
    _ => {
      let mut start = visible_start
      while start > 0 &&
            markdown_document_editor_block_is_blank(blocks[start - 1]) {
        start = start - 1
      }
      let mut end = visible_start + 1
      while end < blocks.length() &&
            markdown_document_editor_block_is_blank(blocks[end]) {
        end = end + 1
      }
      let run = {
        document_identity: session.document_identity,
        revision: session.revision,
        start,
        end,
      }
      markdown_window_blank_gap_run.val = Some(run)
      run
    }
  }
  (visible_start - run.start, run.start > 0 || run.end < blocks.length())
}
