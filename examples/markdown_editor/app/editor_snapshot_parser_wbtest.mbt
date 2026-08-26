///|
test "markdown parser recognizes supported block and inline subset" {
  let blocks = parse_markdown(
    "# Title\n## Section\n### Detail\n#### Fine\n##### Small\n###### Caption\nText with **bold** and *italic* and `code` and [link](https://wzzc-dev.github.io/MoUI) and ![alt](image.png) and ~~old~~\n- bullet\n- [ ] todo\n- [x] done\n1. one\n> quote\n---\n```\ncode\n```",
  )
  inspect(blocks.length(), content="14")
  guard blocks[0].kind is Heading(1) else { fail("expected h1") }
  guard blocks[1].kind is Heading(2) else { fail("expected h2") }
  guard blocks[2].kind is Heading(3) else { fail("expected h3") }
  guard blocks[3].kind is Heading(4) else { fail("expected h4") }
  guard blocks[4].kind is Heading(5) else { fail("expected h5") }
  guard blocks[5].kind is Heading(6) else { fail("expected h6") }
  guard blocks[6].kind is Paragraph else { fail("expected paragraph") }
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Bold),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Italic),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Code),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Link),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Image),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Strikethrough),
  )
  guard blocks[7].kind is UnorderedListItem else {
    fail("expected unordered list")
  }
  guard blocks[8].kind is TaskListItem(false) else {
    fail("expected open task")
  }
  guard blocks[9].kind is TaskListItem(true) else {
    fail("expected checked task")
  }
  guard blocks[10].kind is OrderedListItem(1) else {
    fail("expected ordered list")
  }
  guard blocks[11].kind is Blockquote else { fail("expected quote") }
  guard blocks[12].kind is HorizontalRule else { fail("expected rule") }
  guard blocks[13].kind is CodeBlock else { fail("expected code block") }
}

///|
test "markdown parser recognizes tables as table blocks" {
  let blocks = parse_markdown("| Name | Done |\n| --- | --- |\n| Core | yes |")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: Table, text: "Name  |  Done\nCore  |  yes", .. } else {
    fail("expected table block")
  }
}

///|
test "markdown parser preserves malformed inline syntax as plain text" {
  let blocks = parse_markdown("Text with **open and `dangling")
  inspect(blocks.length(), content="1")
  guard blocks[0].kind is Paragraph else {
    fail("expected malformed inline paragraph")
  }
  inspect(blocks[0].inlines.length(), content="1")
  guard blocks[0].inlines[0] is { kind: MarkdownInlineKind::Plain, text, .. } else {
    fail("expected plain malformed inline text")
  }
  inspect(text, content="Text with **open and `dangling")
}

///|
test "markdown parser handles blank lines and unterminated code blocks" {
  let blocks = parse_markdown("\n\n```moonbit\nlet x = 1")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: CodeBlock, code_language: Some("moonbit"), .. } else {
    fail("expected trailing code block")
  }
  inspect(blocks[0].text, content="let x = 1")
}

///|
test "markdown parser recognizes star bullets and ordered list numbers" {
  let blocks = parse_markdown("* star\n+ plus\n42. answer")
  inspect(blocks.length(), content="3")
  guard blocks[0].kind is UnorderedListItem else {
    fail("expected star bullet")
  }
  guard blocks[1].kind is UnorderedListItem else {
    fail("expected plus bullet")
  }
  inspect(blocks[1].text, content="plus")
  guard blocks[2].kind is OrderedListItem(42) else {
    fail("expected ordered list number")
  }
  inspect(blocks[2].text, content="answer")
}

///|
test "markdown inline parser emits separated plain and styled spans" {
  let spans = parse_markdown_inlines("a **b** c `d` *e* __f__ _g_")
  inspect(spans.length(), content="10")
  guard spans[0] is { kind: MarkdownInlineKind::Plain, text: "a ", .. } else {
    fail("expected leading plain span")
  }
  guard spans[1] is { kind: MarkdownInlineKind::Bold, text: "b", .. } else {
    fail("expected bold span")
  }
  guard spans[3] is { kind: MarkdownInlineKind::Code, text: "d", .. } else {
    fail("expected code span")
  }
  guard spans[5] is { kind: MarkdownInlineKind::Italic, text: "e", .. } else {
    fail("expected italic span")
  }
  guard spans[7] is { kind: MarkdownInlineKind::Bold, text: "f", .. } else {
    fail("expected underscore bold span")
  }
  guard spans[9] is { kind: MarkdownInlineKind::Italic, text: "g", .. } else {
    fail("expected underscore italic span")
  }
}

///|
test "markdown inline parser preserves link image and strike metadata" {
  let spans = parse_markdown_inlines(
    "[MoUI](https://wzzc-dev.github.io/MoUI) ![logo](logo.png) ~~old~~ <https://wzzc-dev.github.io/MoUI>",
  )
  guard spans[0]
    is {
      kind: MarkdownInlineKind::Link,
      text: "MoUI",
      target: Some("https://wzzc-dev.github.io/MoUI"),
    } else {
    fail("expected link target")
  }
  guard spans[2]
    is {
      kind: MarkdownInlineKind::Image,
      text: "logo",
      target: Some("logo.png"),
    } else {
    fail("expected image target")
  }
  guard spans[4] is { kind: MarkdownInlineKind::Strikethrough, text: "old", .. } else {
    fail("expected strikethrough")
  }
  guard spans[6]
    is {
      kind: MarkdownInlineKind::Autolink,
      text: "https://wzzc-dev.github.io/MoUI",
      target: Some("https://wzzc-dev.github.io/MoUI"),
    } else {
    fail("expected autolink target")
  }
}

///|
test "markdown parser preserves footnote metadata" {
  let blocks = parse_markdown("Text[^note]\n\n[^note]: Body text")
  inspect(blocks.length(), content="2")
  guard blocks[0].inlines[1]
    is { kind: MarkdownInlineKind::FootnoteReference, text: "note", .. } else {
    fail("expected footnote reference")
  }
  guard blocks[1]
    is {
      kind: FootnoteDefinition("note"),
      text: "Body text",
      inlines: [{ text: "Body text", .. }],
      ..,
    } else {
    fail("expected footnote definition block")
  }
}

///|
test "markdown parser normalizes reference label whitespace" {
  let blocks = parse_markdown(
    "[MoUI][My   Site]\n\n[my site]: https://wzzc-dev.github.io/MoUI",
  )
  guard blocks[0].inlines[0]
    is {
      kind: MarkdownInlineKind::Link,
      text: "MoUI",
      target: Some("https://wzzc-dev.github.io/MoUI"),
    } else {
    fail("expected collapsed whitespace reference label to resolve")
  }
}

///|
test "markdown parser preserves html block metadata" {
  let blocks = parse_markdown("<div>Block</div>")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: HtmlBlock, text: "<div>Block</div>", .. } else {
    fail("expected html block")
  }
}

///|
test "markdown parser keeps multiline html blocks together" {
  let blocks = parse_markdown("<section>\nLine **raw**\n</section>\n\nTail")
  inspect(blocks.length(), content="2")
  guard blocks[0]
    is { kind: HtmlBlock, text: "<section>\nLine **raw**\n</section>", .. } else {
    fail("expected multiline html block")
  }
  guard blocks[1] is { kind: Paragraph, text: "Tail", .. } else {
    fail("expected paragraph after html block")
  }
}

///|
test "markdown parser preserves inline html tag metadata" {
  let spans = parse_markdown_inlines("Use <kbd>Esc</kbd> now")
  inspect(spans.length(), content="5")
  inspect(spans[0].text, content="Use ")
  inspect(markdown_editor_test_inline_kind_name(spans[1].kind), content="html")
  inspect(spans[1].text, content="<kbd>")
  inspect(spans[2].text, content="Esc")
  inspect(spans[3].text, content="</kbd>")
  inspect(spans[4].text, content=" now")
  guard spans[1].kind is MarkdownInlineKind::HtmlInline else {
    fail("expected opening html tag span")
  }
  guard spans[3].kind is MarkdownInlineKind::HtmlInline else {
    fail("expected closing html tag span")
  }
}

///|
test "markdown parser does not split inline html inside code or links" {
  let code = parse_markdown_inlines("Use `<kbd>` code")
  guard code[1] is { kind: MarkdownInlineKind::Code, text: "<kbd>", .. } else {
    fail("expected code span to keep html-looking source")
  }
  let link = parse_markdown_inlines("[<kbd>](https://example.com)")
  guard link[0]
    is {
      kind: MarkdownInlineKind::Link,
      text: "kbd",
      target: Some("https://example.com"),
    } else {
    fail("expected html-looking link text to stay a link")
  }
  let autolink = parse_markdown_inlines("Visit <https://example.com>")
  guard autolink[1]
    is {
      kind: MarkdownInlineKind::Autolink,
      text: "https://example.com",
      target: Some("https://example.com"),
    } else {
    fail("expected autolink to stay autolink")
  }
  let email = parse_markdown_inlines("Mail <hello@example.dev>")
  guard email[1]
    is {
      kind: MarkdownInlineKind::Autolink,
      text: "hello@example.dev",
      target: Some("hello@example.dev"),
    } else {
    fail("expected email autolink to stay autolink")
  }
}

///|
fn markdown_editor_test_inline_kind_name(kind : MarkdownInlineKind) -> String {
  match kind {
    HtmlInline => "html"
    Plain => "plain"
    _ => "other"
  }
}

///|
test "markdown formatter produces rich text blocks and styled runs" {
  let document = markdown_to_rich_text(
    "# Title\n- item\n- [x] done\n> quote\n```moonbit\ncode\n```\n---",
  )
  inspect(document.blocks.length(), content="6")
  inspect(document.blocks[0].runs[0].text, content="Title")
  inspect(document.blocks[0].runs[0].font.unwrap().weight, content="700")
  inspect(document.blocks[1].prefix, content="• ")
  inspect(document.blocks[2].prefix, content="☑ ")
  assert_true(document.blocks[3].border_left is Some(_))
  assert_true(document.blocks[4].background is Some(_))
  inspect(document.blocks[4].runs[0].text, content="moonbit")
  inspect(document.blocks[4].runs[1].text, content="\n")
  inspect(document.blocks[4].runs[2].text, content="code")
  assert_true(document.blocks[5].rule)
}

///|
test "markdown formatter gives quotes and code blocks vertical breathing room" {
  let document = markdown_to_rich_text(
    "> quote\n\n```moonbit\nlet x = 1\nlet y = 2\n```",
  )
  guard document.blocks[0] is { border_left: Some(_), inset: quote_inset, .. } else {
    fail("expected quoted block")
  }
  guard document.blocks[1] is { background: Some(_), inset: code_inset, .. } else {
    fail("expected code block")
  }
  assert_true(quote_inset.top > 0.0)
  assert_true(quote_inset.bottom >= 12.0)
  assert_true(code_inset.top >= 8.0)
  assert_true(code_inset.bottom >= 8.0)
  assert_true(
    @moui_richtext.rich_text_document_height(document, @core.FontSpec::new()) >
    100.0,
  )
}

///|
test "markdown formatter renders footnotes as structured rich text" {
  let document = markdown_to_rich_text("Text[^a]\n\n[^a]: Footnote")
  inspect(document.blocks.length(), content="2")
  guard document.blocks[0].runs[1]
    is { text: "[^a]", visual_text: Some("a"), background: Some(_), .. } else {
    fail("expected styled footnote reference")
  }
  guard document.blocks[1]
    is {
      border_left: Some(_),
      runs: [{ visual_text: Some("a"), .. }, { text: "Footnote", .. }],
      ..,
    } else {
    fail("expected styled footnote definition")
  }
}

///|
test "markdown formatter renders html blocks as structured rich text" {
  let document = markdown_to_rich_text("<div>Block</div>")
  inspect(document.blocks.length(), content="1")
  guard document.blocks[0]
    is {
      background: Some(_),
      runs: [{ text: "<div>Block</div>", font: Some({ families, .. }), .. }],
      ..,
    } else {
    fail("expected styled html block")
  }
  inspect(families.families.length() > 0, content="true")
}

///|
test "markdown formatter renders yaml front matter as metadata block" {
  let document = markdown_to_rich_text("---\ntitle: Draft\n---\n\n# Body")
  inspect(document.blocks.length(), content="2")
  guard document.blocks[0]
    is {
      background: Some(_),
      runs: [{ text: "title: Draft", font: Some({ families, .. }), .. }],
      ..,
    } else {
    fail("expected styled front matter block")
  }
  inspect(families.families.length() > 0, content="true")
  inspect(document.blocks[1].runs[0].text, content="Body")
}

///|
test "markdown formatter renders inline html tags as styled runs" {
  let blocks = parse_markdown("Use <kbd>Esc</kbd> now")
  inspect(blocks[0].inlines[1].text, content="<kbd>")
  let document = markdown_to_rich_text("Use <kbd>Esc</kbd> now")
  inspect(document.blocks.length(), content="1")
  inspect(document.blocks[0].runs.length(), content="5")
  inspect(document.blocks[0].runs[1].text, content="<kbd>")
  inspect(document.blocks[0].runs[1].background is Some(_), content="true")
  inspect(document.blocks[0].runs[1].font is Some(_), content="true")
  guard document.blocks[0].runs[1]
    is { text: "<kbd>", background: Some(_), font: Some({ size, .. }), .. } else {
    fail("expected styled opening html run")
  }
  guard document.blocks[0].runs[3]
    is { text: "</kbd>", background: Some(_), .. } else {
    fail("expected styled closing html run")
  }
  assert_true(size < @core.FontSpec::new().size)
}
