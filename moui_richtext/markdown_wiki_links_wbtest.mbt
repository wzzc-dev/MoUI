///|
/// Expand a single plain run the way a materialized block does, so a test names
/// only the run it cares about.
fn wiki_expand(text : String) -> Array[MarkdownInline]? {
  markdown_apply_wiki_links([markdown_inline(text, Plain)])
}

///|
/// `[[target]]` becomes one wiki `Link`; the text around it survives as plain
/// runs, which is what keeps the rendered paragraph unchanged elsewhere.
test "markdown_apply_wiki_links splits a bare wiki link out of a plain run" {
  match wiki_expand("see [[Note]] now") {
    Some(inlines) =>
      assert_eq(markdown_editor_inline_source(inlines), "see [[Note]] now")
    None => abort("a wiki link must change the run")
  }
}

///|
/// A link inline carries the raw target and the label separately, so the
/// viewer can paint the alias while the click still routes the target.
test "markdown_apply_wiki_links keeps target and alias apart" {
  match wiki_expand("[[Note|See note]]") {
    Some(inlines) => {
      assert_eq(inlines.length(), 1)
      let inline = inlines[0]
      assert_true(inline.kind is Link)
      assert_true(inline.wiki)
      assert_eq(markdown_editor_inline_target(inline), "Note")
      assert_eq(inline.text, "See note")
    }
    None => abort("an aliased wiki link must change the run")
  }
}

///|
/// `![[file]]` is an embed, not a link: the run stays literal so an editor
/// does not turn a transclusion into a clickable page.
test "markdown_apply_wiki_links ignores embeds" {
  match wiki_expand("![[Note]]") {
    None => ()
    Some(_) => abort("an embed must stay plain text")
  }
}

///|
/// A double bracket that spans a newline is not a wiki link, and neither is an
/// unclosed one — both must render exactly as typed.
test "markdown_apply_wiki_links rejects unclosed and multi-line runs" {
  match wiki_expand("[[Note\nnext]]") {
    None => ()
    Some(_) => abort("a multi-line run must stay plain text")
  }
  match wiki_expand("[[Note") {
    None => ()
    Some(_) => abort("an unclosed run must stay plain text")
  }
}

///|
/// An empty target is not a link. An empty alias is not an error either: it
/// falls back to the target as its own label.
test "markdown_apply_wiki_links falls back on empty parts" {
  match wiki_expand("[[]]") {
    None => ()
    Some(_) => abort("an empty target must stay plain text")
  }
  match wiki_expand("[[ | Note ]]") {
    None => ()
    Some(_) => abort("a blank target must stay plain text")
  }
  match wiki_expand("[[Note|]]") {
    Some(inlines) =>
      assert_eq(markdown_editor_inline_source(inlines), "[[Note]]")
    None => abort("an empty alias must fall back to the target")
  }
}

///|
/// Blanks around the separator are trimmed, so `[[ Note | See note ]]` yields
/// the same pair as the compact form.
test "markdown_apply_wiki_links trims blanks around the separator" {
  match wiki_expand("[[ Note | See note ]]") {
    Some(inlines) =>
      assert_eq(markdown_editor_inline_source(inlines), "[[Note|See note]]")
    None => abort("a padded wiki link must still be a link")
  }
}

///|
/// Several links in one run all expand, in source order.
test "markdown_apply_wiki_links expands every run in order" {
  match wiki_expand("[[A]] then [[B|bee]]") {
    Some(inlines) =>
      assert_eq(markdown_editor_inline_source(inlines), "[[A]] then [[B|bee]]")
    None => abort("two wiki links must both expand")
  }
}

///|
/// A run without any double bracket returns `None`, so the session can keep the
/// array it already holds instead of allocating a copy.
test "markdown_apply_wiki_links leaves ordinary text alone" {
  match wiki_expand("plain [label](https://example.com) text") {
    None => ()
    Some(_) => abort("an ordinary link must not be touched")
  }
}

///|
/// A `Link` run that is not a wiki link passes through untouched.
test "markdown_apply_wiki_links passes non-plain inlines through" {
  let link = markdown_inline("label", Link, target=Some("https://example.com"))
  let inlines : Array[MarkdownInline] = [link]
  match markdown_apply_wiki_links(inlines) {
    None => ()
    Some(_) => abort("a link-only run must be unchanged")
  }
}

///|
/// A disabled option hands the block back as-is; only the opt-in path rewrites
/// inlines. This is what keeps the feature off for every existing caller.
test "markdown_editor_block_with_wiki_links is inert when disabled" {
  let inlines : Array[MarkdownInline] = [markdown_inline("[[Note]]", Plain)]
  let editor_block : MarkdownEditorBlock = {
    block: {
      kind: Paragraph,
      text: "[[Note]]",
      inlines,
      table_alignments: [],
      code_language: None,
    },
    source_range: { start: 0, end: 8, },
    content_range: { start: 0, end: 8, },
  }
  let disabled = markdown_editor_block_with_wiki_links(editor_block, None)
  assert_true(disabled.block.inlines[0].kind is Plain)
  let enabled = markdown_editor_block_with_wiki_links(
    editor_block,
    Some(MarkdownWikiLinkOptions::new("")),
  )
  assert_eq(enabled.block.inlines.length(), 1)
  assert_true(enabled.block.inlines[0].kind is Link)
  assert_true(enabled.block.inlines[0].wiki)
}

///|
/// The caret probe resolves the target with the host scheme, so a click always
/// leaves the library as one URL shape.
test "markdown_editor_wiki_target_at resolves with the host scheme" {
  let options = Some(MarkdownWikiLinkOptions::new("wiki:"))
  assert_eq(
    markdown_editor_wiki_target_at("see [[Note]] now", 6, options),
    Some("wiki:Note"),
  )
  // The whole run counts, both ends included.
  assert_eq(
    markdown_editor_wiki_target_at("[[Note]]", 8, options),
    Some("wiki:Note"),
  )
}

///|
/// Outside the run there is no target, and a disabled option never resolves.
test "markdown_editor_wiki_target_at misses outside the run" {
  let options = Some(MarkdownWikiLinkOptions::new("wiki:"))
  assert_eq(markdown_editor_wiki_target_at("[[Note]]", 9, options), None)
  assert_eq(markdown_editor_wiki_target_at("plain text", 3, options), None)
  assert_eq(markdown_editor_wiki_target_at("[[Note]]", 4, None), None)
}

///|
/// An empty scheme opts into the syntax without inventing a routing prefix.
test "markdown_editor_wiki_target_at keeps raw targets for an empty scheme" {
  assert_eq(
    markdown_editor_wiki_target_at(
      "[[Note]]",
      2,
      Some(MarkdownWikiLinkOptions::new("")),
    ),
    Some("Note"),
  )
}

///|
/// The probe only sees double brackets: an embed stays unopenable even when the
/// feature is on.
test "markdown_editor_wiki_target_at ignores embeds" {
  assert_eq(
    markdown_editor_wiki_target_at(
      "![[Note]]",
      4,
      Some(MarkdownWikiLinkOptions::new("wiki:")),
    ),
    None,
  )
}

///|
/// Rebuilding source from a wiki link writes the double bracket back, not the
/// ordinary `[label](target)` form — the round trip is what lets the session
/// reparse its own output without the link degrading.
test "markdown_editor_inline_source rebuilds wiki links" {
  let bare : Array[MarkdownInline] = [
    markdown_inline("Note", Link, target=Some("Note"), wiki=true),
  ]
  assert_eq(markdown_editor_inline_source(bare), "[[Note]]")
  let aliased : Array[MarkdownInline] = [
    markdown_inline("See note", Link, target=Some("Note"), wiki=true),
  ]
  assert_eq(markdown_editor_inline_source(aliased), "[[Note|See note]]")
  let ordinary : Array[MarkdownInline] = [
    markdown_inline("label", Link, target=Some("https://example.com")),
  ]
  assert_eq(
    markdown_editor_inline_source(ordinary),
    "[label](https://example.com)",
  )
}

///|
/// `wiki` is part of the serialized inline, so a host caching inline JSON sees
/// the distinction instead of losing it on the way out.
test "MarkdownInline serializes the wiki flag" {
  let json = markdown_inline("Note", Link, target=Some("Note"), wiki=true)
    .to_json()
    .stringify()
  assert_true(json.contains("\"wiki\":true"))
  let plain_json = markdown_inline("Note", Plain).to_json().stringify()
  assert_true(plain_json.contains("\"wiki\":false"))
}
