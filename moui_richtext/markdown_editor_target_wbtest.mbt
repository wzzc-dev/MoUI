///|
/// A caret in ordinary prose is the fallback case: no target to open, no table
/// commands, just the block label.
test "target_at reports a plain selection for prose" {
  let session = MarkdownDocumentSession::new("hello world")
  let target = session.target_at({ caret: 3, selection: None, })
  assert_true(target.kind is PlainSelection)
  assert_true(target.block_kind is Paragraph)
  assert_eq(target.block_label, "Paragraph")
  assert_true(target.link_target is None)
  assert_false(target.has_openable_target())
}

///|
/// A wiki link is a `LinkTarget` whose target already carries the host scheme,
/// so the caller routes it exactly like an ordinary link click.
test "target_at resolves a wiki link with the host scheme" {
  let session = MarkdownDocumentSession::new("see [[Note]] now").with_wiki_links(
    Some(MarkdownWikiLinkOptions::new("wiki:")),
  )
  let target = session.target_at({ caret: 6, selection: None, })
  assert_true(target.kind is LinkTarget)
  assert_eq(target.link_target, Some("wiki:Note"))
  assert_true(target.has_openable_target())
}

///|
/// With the feature switched off the same caret is plain prose: the wiki
/// syntax never leaks into a session that did not opt in.
test "target_at ignores wiki syntax when the feature is off" {
  let session = MarkdownDocumentSession::new("see [[Note]] now")
  let target = session.target_at({ caret: 6, selection: None, })
  assert_true(target.kind is PlainSelection)
  assert_true(target.link_target is None)
}

///|
/// An empty scheme keeps the raw target; the host still gets one URL shape,
/// just without inventing a prefix.
test "target_at keeps a raw wiki target for an empty scheme" {
  let session = MarkdownDocumentSession::new("[[Note]]").with_wiki_links(
    Some(MarkdownWikiLinkOptions::new("")),
  )
  let target = session.target_at({ caret: 2, selection: None, })
  assert_true(target.kind is LinkTarget)
  assert_eq(target.link_target, Some("Note"))
}

///|
/// The ordinary `[label](target)` probe still wins its own case, and it does
/// not mistake a wiki run for a bracketed link.
test "target_at reads an ordinary link" {
  let session = MarkdownDocumentSession::new(
    "see [label](https://example.com) now",
  )
  let target = session.target_at({ caret: 8, selection: None, })
  assert_true(target.kind is LinkTarget)
  assert_eq(target.link_target, Some("https://example.com"))
  let wiki = MarkdownDocumentSession::new("[[Note]]").with_wiki_links(
    Some(MarkdownWikiLinkOptions::new("wiki:")),
  )
  assert_eq(
    wiki.target_at({ caret: 2, selection: None, }).link_target,
    Some("wiki:Note"),
  )
}

///|
/// An image reference is an `ImageTarget`, keeping target and alt apart.
test "target_at reads an image" {
  let session = MarkdownDocumentSession::new("![alt](img.png)")
  let target = session.target_at({ caret: 2, selection: None, })
  assert_true(target.kind is ImageTarget)
  assert_eq(target.image_target, Some("img.png"))
  assert_true(target.has_openable_target())
}

///|
/// A footnote reference resolves to its definition text, which is what an
/// inspector needs to show.
test "target_at reads a footnote" {
  let session = MarkdownDocumentSession::new("text[^1]\n\n[^1]: note")
  let target = session.target_at({ caret: 5, selection: None, })
  assert_true(target.kind is FootnoteTarget)
  assert_eq(target.footnote_text, Some("note"))
  assert_true(target.has_openable_target())
}

///|
/// A caret inside an html block targets the block text, because the rendered
/// view hides the markup the user is trying to reach.
test "target_at reads an html block" {
  let session = MarkdownDocumentSession::new("<div>\nhi\n</div>")
  let target = session.target_at({ caret: 7, selection: None, })
  assert_true(target.kind is HtmlBlockTarget)
  assert_true(target.html_block_text is Some(_))
  assert_true(target.has_openable_target())
}

///|
/// A bare table cell falls back to the table commands, and the block label
/// tells the caller a table is selected.
test "target_at reports table tools inside a table cell" {
  let session = MarkdownDocumentSession::new(
    "| a | b |\n| --- | --- |\n| 1 | 2 |",
  )
  let target = session.target_at({ caret: 2, selection: None, })
  assert_true(target.kind is TableTools)
  assert_true(target.block_kind is Table)
  assert_eq(target.block_label, "Table")
  assert_false(target.has_openable_target())
}

///|
/// A link inside a cell still opens: the table fallback is lower precedence
/// than the link probe, which is why the table menu must not gate on
/// `kind is TableTools`.
test "target_at prefers a link inside a table cell over the table fallback" {
  let session = MarkdownDocumentSession::new(
    "| [x](https://e) | b |\n| --- | --- |\n| 1 | 2 |",
  )
  let target = session.target_at({ caret: 3, selection: None, })
  assert_true(target.kind is LinkTarget)
  assert_eq(target.link_target, Some("https://e"))
  assert_true(target.block_kind is Table)
  assert_eq(target.block_label, "Table")
}

///|
/// A selection rather than a bare caret uses its start as the anchor, so
/// selecting a link's label reports the link.
test "target_at anchors a ranged selection at its start" {
  let session = MarkdownDocumentSession::new("see [label](https://example.com)")
  // A ranged probe matches when the selection is the link's own label.
  let target = session.target_at({
    caret: 10,
    selection: Some(@core.TextRange::new(start=5, end=10)),
  })
  assert_true(target.kind is LinkTarget)
  assert_eq(target.link_target, Some("https://example.com"))
}

///|
/// Build a target with only the kind set, so the predicate can be checked for
/// every variant without going through a document.
fn target_of_kind(kind : MarkdownEditorTargetKind) -> MarkdownEditorTarget {
  {
    kind,
    block_kind: Paragraph,
    block_label: "Paragraph",
    link_target: None,
    image_target: None,
    footnote_text: None,
    html_block_text: None,
  }
}

///|
/// `has_openable_target` is exactly the set of kinds that carry something to
/// open; it must stay false for prose and table tools.
test "has_openable_target covers the openable kinds only" {
  assert_false(target_of_kind(PlainSelection).has_openable_target())
  assert_false(target_of_kind(TableTools).has_openable_target())
  assert_true(target_of_kind(LinkTarget).has_openable_target())
  assert_true(target_of_kind(ImageTarget).has_openable_target())
  assert_true(target_of_kind(FootnoteTarget).has_openable_target())
  assert_true(target_of_kind(HtmlBlockTarget).has_openable_target())
}
