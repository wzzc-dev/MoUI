///|
/// The hand-rolled content-identity key must stay injective on exactly
/// the fields `MarkdownBlock` derives `ToJson` for: two blocks share a
/// key iff they are structurally equal. These cases pin the adversarial
/// boundaries (embedded length markers, shifted field boundaries, empty
/// optionals) that a length-prefixed encoding could otherwise collapse.
///|
fn key_sample_block(
  kind~ : MarkdownBlockKind = Paragraph,
  text~ : String = "",
  inlines~ : Array[MarkdownInline] = [],
  alignments~ : Array[@core.TextAlign?] = [],
  code_language~ : String? = None,
) -> MarkdownBlock {
  { kind, text, inlines, table_alignments: alignments, code_language }
}

///|
fn key_inline(
  text~ : String,
  kind~ : MarkdownInlineKind = Plain,
  target~ : String? = None,
) -> MarkdownInline {
  { text, kind, target }
}

///|
test "markdown_editor_block_key is injective on block content" {
  let samples : Array[MarkdownBlock] = [
    key_sample_block(),
    key_sample_block(text="hello"),
    key_sample_block(text=""),
    key_sample_block(kind=Heading(1), text="title"),
    key_sample_block(kind=Heading(2), text="title"),
    key_sample_block(kind=TaskListItem(true), text="x"),
    key_sample_block(kind=TaskListItem(false), text="x"),
    key_sample_block(kind=OrderedListItem(1), text="x"),
    key_sample_block(kind=OrderedListItem(2), text="x"),
    key_sample_block(kind=FootnoteDefinition("a"), text="x"),
    key_sample_block(kind=FootnoteDefinition("b"), text="x"),
    key_sample_block(kind=UnorderedListItem),
    key_sample_block(kind=Blockquote),
    key_sample_block(kind=CodeBlock),
    key_sample_block(kind=HorizontalRule),
    key_sample_block(kind=Table),
    key_sample_block(kind=HtmlBlock),
    key_sample_block(kind=FrontMatter),
    key_sample_block(text="s1:x"),
    key_sample_block(text="s2:x"),
    key_sample_block(text="a", code_language=Some("b")),
    key_sample_block(text="a;b", code_language=None),
    key_sample_block(text="a", code_language=None),
    key_sample_block(text="", code_language=Some("ab")),
    key_sample_block(text="ab", code_language=Some("")),
    key_sample_block(
      inlines=[key_inline(text="a"), key_inline(text="b", kind=Bold)],
    ),
    key_sample_block(inlines=[key_inline(text="ab")]),
    key_sample_block(
      inlines=[key_inline(text="a", target=Some("b")), key_inline(text="c")],
    ),
    key_sample_block(
      inlines=[key_inline(text="a"), key_inline(text="b", target=Some("c"))],
    ),
    key_sample_block(
      inlines=[
        key_inline(text="a", target=Some("b")), key_inline(text="c"),
      ],
      code_language=Some(""),
    ),
    key_sample_block(
      inlines=[key_inline(text="plain")],
      alignments=[Some(@core.TextStart)],
    ),
    key_sample_block(
      inlines=[key_inline(text="plain")],
      alignments=[Some(@core.TextCenter)],
    ),
    key_sample_block(
      inlines=[key_inline(text="plain")],
      alignments=[Some(@core.TextEnd)],
    ),
    key_sample_block(
      inlines=[key_inline(text="plain")],
      alignments=[None],
    ),
    key_sample_block(inlines=[key_inline(text="plain")]),
  ]
  for left_index, left in samples {
    let left_key = markdown_editor_block_key(left)
    for right_index, right in samples {
      let same_key = left_key == markdown_editor_block_key(right)
      if same_key != (left == right) {
        fail(
          "block \{left_index} vs \{right_index}: key equality must match structural equality",
        )
      }
    }
  }
}
