///|
/// Opt-in wiki link support for markdown documents.
///
/// `[[target]]` and `[[target|label]]` parse into ordinary `Link` inlines
/// tagged with `wiki = true`, so a host keeps dispatching links through the
/// single `on_link_click` path it already has instead of growing a second
/// click vocabulary. `scheme` is injected by the host — richtext never
/// hard-codes a wiki prefix — and `resolve` is applied where a target leaves
/// the library: link clicks and `MarkdownDocumentSession::target_at`.
///
/// The inline itself keeps the *raw* target. That is what makes the round
/// trip lossless: `markdown_editor_inline_source` rebuilds `[[target|label]]`
/// from `target`/`text` without having to strip a scheme back off, and an
/// ordinary `[label](wiki:foo)` link can never be mistaken for a wiki link.
#derive(Eq, Debug, ToJson)
pub(all) struct MarkdownWikiLinkOptions {
  scheme : String
}

///|
pub extend MarkdownWikiLinkOptions with Debug::{to_repr}

///|
pub extend MarkdownWikiLinkOptions with Eq::{not_equal, equal}

///|
pub extend MarkdownWikiLinkOptions with ToJson::{to_json}

///|
pub fn MarkdownWikiLinkOptions::new(scheme : String) -> MarkdownWikiLinkOptions {
  { scheme, }
}

///|
/// Prefix `target` with the host scheme. An empty scheme leaves the target
/// untouched, which lets a host opt into wiki *syntax* without inventing a
/// routing scheme.
pub fn MarkdownWikiLinkOptions::resolve(
  self : MarkdownWikiLinkOptions,
  target : String,
) -> String {
  if self.scheme == "" {
    return target
  }
  self.scheme + target
}

///|
priv struct MarkdownWikiLinkSpan {
  // Byte-independent char offsets of the whole `[[...]]` run in the run text.
  start : Int32
  end : Int32
  target : String
  label : String
}

///|
fn markdown_wiki_link_char_at(chars : Array[Char], index : Int32) -> Char {
  if index < 0 || index >= chars.length() {
    return '\u{0}'
  }
  chars[index]
}

///|
/// True when `chars` starts with the two-char run `first second` at `index`.
fn markdown_wiki_link_has_pair(
  chars : Array[Char],
  index : Int32,
  first : Char,
  second : Char,
) -> Bool {
  markdown_wiki_link_char_at(chars, index) == first &&
  markdown_wiki_link_char_at(chars, index + 1) == second
}

///|
fn markdown_wiki_link_is_blank(ch : Char) -> Bool {
  ch == ' ' || ch == '\t'
}

///|
/// Trim the blanks a wikilink author leaves around the `|` separator. Only
/// spaces and tabs are trimmed: a newline never reaches here because the span
/// scan stops at the end of the line.
fn markdown_wiki_link_trim(
  chars : Array[Char],
  start : Int32,
  end : Int32,
) -> String {
  let mut from = start
  while from < end && markdown_wiki_link_is_blank(chars[from]) {
    from = from + 1
  }
  let mut to = end
  while to > from && markdown_wiki_link_is_blank(chars[to - 1]) {
    to = to - 1
  }
  String::from_array(chars[from:to])
}

///|
/// Split the body of `[[...]]` into `(target, label)`. `[[target]]` uses the
/// target as its own label; an empty alias falls back the same way, and an
/// empty target is not a wikilink at all.
fn markdown_wiki_link_parts(
  chars : Array[Char],
  start : Int32,
  end : Int32,
) -> MarkdownWikiLinkSpan? {
  let mut pipe = -1
  let mut index = start
  while index < end && pipe < 0 {
    if chars[index] == '|' {
      pipe = index
    }
    index = index + 1
  }
  let target = if pipe < 0 {
    markdown_wiki_link_trim(chars, start, end)
  } else {
    markdown_wiki_link_trim(chars, start, pipe)
  }
  if target == "" {
    return None
  }
  let label = if pipe < 0 {
    target
  } else {
    let alias_text = markdown_wiki_link_trim(chars, pipe + 1, end)
    if alias_text == "" {
      target
    } else {
      alias_text
    }
  }
  Some({ start, end, target, label, })
}

///|
/// All `[[...]]` spans in one plain-text run. `![[...]]` is an embed, not a
/// link, and an unclosed or multi-line double bracket stays literal text — the
/// same shape a wiki editor shows while the author is still typing it.
fn markdown_wiki_link_spans(text : String) -> Array[MarkdownWikiLinkSpan] {
  let spans : Array[MarkdownWikiLinkSpan] = []
  if text == "" {
    return spans
  }
  let chars = text.to_array()
  let length = chars.length()
  let mut index = 0
  while index + 1 < length {
    if markdown_wiki_link_has_pair(chars, index, '[', '[') {
      if markdown_wiki_link_char_at(chars, index - 1) == '!' {
        index = index + 2
        continue
      }
      let mut scan = index + 2
      let mut closed = false
      while scan + 1 < length {
        let ch = chars[scan]
        if ch == '\n' {
          break
        }
        if ch == ']' && chars[scan + 1] == ']' {
          closed = true
          break
        }
        if ch == '[' || ch == ']' {
          break
        }
        scan = scan + 1
      }
      if closed {
        match markdown_wiki_link_parts(chars, index + 2, scan) {
          Some(parts) =>
            // `parts` describes the body between the brackets; the span itself
            // covers the whole run so a caret anywhere in `[[...]]` hits it.
            spans.push({ ..parts, start: index, end: scan + 2, })
          None => ()
        }
        index = scan + 2
      } else {
        index = index + 2
      }
    } else {
      index = index + 1
    }
  }
  spans
}

///|
/// Expand the `[[...]]` runs that live inside plain text spans into `Link`
/// inlines. `None` means nothing changed, so the caller keeps the shared array
/// it was handed and the disabled path costs a single substring scan per run.
///
/// A wiki link inside `**bold**`/`` `code` `` is out of scope: mizchi already
/// split it out of the plain run, so it renders exactly as it did before the
/// feature was switched on.
fn markdown_apply_wiki_links(
  inlines : Array[MarkdownInline],
) -> Array[MarkdownInline]? {
  let expanded : Array[MarkdownInline] = []
  let mut changed = false
  for inline in inlines {
    let mut replaced = false
    if inline.kind is Plain {
      let spans = markdown_wiki_link_spans(inline.text)
      if spans.length() > 0 {
        let chars = inline.text.to_array()
        let mut cursor = 0
        for span in spans {
          if span.start > cursor {
            expanded.push(
              markdown_inline(
                String::from_array(chars[cursor:span.start]),
                Plain,
              ),
            )
          }
          expanded.push(
            markdown_inline(
              span.label,
              Link,
              target=Some(span.target),
              wiki=true,
            ),
          )
          cursor = span.end
        }
        if cursor < chars.length() {
          expanded.push(
            markdown_inline(String::from_array(chars[cursor:]), Plain),
          )
        }
        replaced = true
        changed = true
      }
    }
    if !replaced {
      expanded.push(inline)
    }
  }
  if changed {
    Some(expanded)
  } else {
    None
  }
}

///|
/// Apply wiki links to a materialized editor block. Callers run this *after*
/// `markdown_editor_block_materialized`, not inside it: the materialization
/// memo is keyed on the source digest alone and would either go permanently
/// cold or hand back a block parsed under the wrong wiki setting.
///
/// The returned record is a copy. Its source/content ranges are read straight
/// away at the call site and never cached across an apply, so the shared
/// mutable range contract is not violated.
fn markdown_editor_block_with_wiki_links(
  editor_block : MarkdownEditorBlock,
  options : MarkdownWikiLinkOptions?,
) -> MarkdownEditorBlock {
  match options {
    None => editor_block
    Some(_) =>
      match markdown_apply_wiki_links(editor_block.block.inlines) {
        Some(inlines) =>
          {
            block: { ..editor_block.block, inlines, },
            source_range: editor_block.source_range,
            content_range: editor_block.content_range,
          }
        None => editor_block
      }
  }
}

///|
/// Materialize one block with the session's wiki setting applied. Every live
/// call site needs exactly this, and folding it into one helper keeps the
/// near-budget call sites from growing: the call replaces the multi-line
/// `markdown_editor_block_materialized` invocation it wraps.
fn markdown_editor_block_materialize_with_wiki(
  session : MarkdownDocumentSession,
  editor_block : MarkdownEditorBlock,
) -> MarkdownEditorBlock {
  markdown_editor_block_with_wiki_links(
    markdown_editor_block_materialized(
      session.source(),
      source_length=session.source_length,
      source_digest=session.source_digest,
      editor_block,
    ),
    session.wiki_links,
  )
}

///|
/// The wiki target under `caret`, already resolved with the host scheme. The
/// viewer's ordinary link probe reads `[label](target)` out of the source, so
/// it can never see `[[target]]`; this is the wiki counterpart of it, and it
/// runs only when the host opted in.
fn markdown_editor_wiki_target_at(
  source : String,
  caret : Int32,
  options : MarkdownWikiLinkOptions?,
) -> String? {
  match options {
    None => None
    Some(options) => {
      for span in markdown_wiki_link_spans(source) {
        if caret >= span.start && caret <= span.end {
          return Some(options.resolve(span.target))
        }
      }
      None
    }
  }
}
