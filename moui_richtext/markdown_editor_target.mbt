///|
/// What a selection currently points at, in the vocabulary an editor chrome
/// (context menu, format bubble, toolbar) needs.
///
/// A host used to derive this from separate string probes — a "Table" label
/// compare, a selected-link target, a selected-image target — in the wrong
/// order and with no single place that owns the precedence. This enum makes
/// the precedence explicit and lets a caller ask once.
#derive(Eq, Debug, ToJson)
pub(all) enum MarkdownEditorTargetKind {
  PlainSelection
  LinkTarget
  ImageTarget
  FootnoteTarget
  HtmlBlockTarget
  TableTools
}

///|
pub extend MarkdownEditorTargetKind with Debug::{to_repr}

///|
pub extend MarkdownEditorTargetKind with Eq::{not_equal, equal}

///|
pub extend MarkdownEditorTargetKind with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct MarkdownEditorTarget {
  kind : MarkdownEditorTargetKind
  block_kind : MarkdownBlockKind
  block_label : String
  link_target : String?
  image_target : String?
  footnote_text : String?
  html_block_text : String?
}

///|
pub extend MarkdownEditorTarget with Debug::{to_repr}

///|
pub extend MarkdownEditorTarget with Eq::{not_equal, equal}

///|
pub extend MarkdownEditorTarget with ToJson::{to_json}

///|
/// True when `open target` should be offered for this selection.
pub fn MarkdownEditorTarget::has_openable_target(
  self : MarkdownEditorTarget,
) -> Bool {
  match self.kind {
    LinkTarget | ImageTarget | FootnoteTarget | HtmlBlockTarget => true
    PlainSelection | TableTools => false
  }
}

///|
fn markdown_editor_target_anchor(selection : MarkdownEditorSelection) -> Int32 {
  match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
}

///|
/// Classify the selection.
///
/// Precedence is html block, footnote, link, image, table, plain. An html
/// block wins outright because its rendered view hides markup the caret is
/// meant to reach; a reference wins over the table fallback so a link inside a
/// cell still opens. A footnote reference outranks a link because `[^1]` is
/// *also* a valid CommonMark reference link once its definition exists — left
/// to the link probe it would hand back the footnote's text as a URL. Wiki
/// links are resolved with the host scheme here — the single place a target
/// leaves the library besides a viewer click — so a host routes one URL shape
/// from every entry point.
pub fn MarkdownDocumentSession::target_at(
  self : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
) -> MarkdownEditorTarget {
  let source = self.source()
  let anchor = markdown_editor_clamp_int(
    markdown_editor_target_anchor(selection),
    0,
    self.source_length,
  )
  let block_kind = match
    markdown_editor_block_index_at_offset(self.editor_blocks, anchor) {
    Some(index) => self.editor_blocks[index].block.kind
    None => Paragraph
  }
  let block_label = markdown_editor_block_kind_label(block_kind)
  let html_block_text = markdown_editor_selected_html_block_text(
    source, selection,
  )
  let footnote_text = markdown_editor_selected_footnote_text(source, selection)
  let link_target = if footnote_text is Some(_) {
    None
  } else {
    match markdown_editor_selected_link_target(source, selection) {
      // A bracketed run such as `[[Note]]` can satisfy the reference probe with
      // an empty target. That is not an openable link, and treating it as one
      // would shadow the wiki fallback.
      Some(target) if target != "" => Some(target)
      _ => markdown_editor_wiki_target_at(source, anchor, self.wiki_links)
    }
  }
  let image_target = markdown_editor_selected_image_target(source, selection)
  let kind = if html_block_text is Some(_) {
    HtmlBlockTarget
  } else if link_target is Some(_) {
    LinkTarget
  } else if image_target is Some(_) {
    ImageTarget
  } else if footnote_text is Some(_) {
    FootnoteTarget
  } else if block_kind is Table {
    TableTools
  } else {
    PlainSelection
  }
  {
    kind,
    block_kind,
    block_label,
    link_target,
    image_target,
    footnote_text,
    html_block_text,
  }
}
