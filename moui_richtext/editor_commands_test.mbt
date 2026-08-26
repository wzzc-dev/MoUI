///|
test "Bold command wraps selected plain text" {
  // source = "text", selection covers [0, 4)
  let selection : MarkdownEditorSelection = {
    caret: 4,
    selection: Some(@core.TextRange::new(start=0, end=4)),
  }
  let result = markdown_editor_apply_command_at("text", Bold, Some(selection))
  inspect(result.source, content="**text**")
  // After wrapping, the selection should cover the inner text.
  guard result.selection is Some(range) else {
    fail("expected a selection after Bold wrap")
  }
  inspect(range.start, content="2")
  inspect(range.end, content="6")
}

///|
test "Bold command unwraps selected bold text (symmetry)" {
  // source = "**text**", selection covers the inner "text" at [2, 6)
  let selection : MarkdownEditorSelection = {
    caret: 6,
    selection: Some(@core.TextRange::new(start=2, end=6)),
  }
  let result = markdown_editor_apply_command_at(
    "**text**",
    Bold,
    Some(selection),
  )
  inspect(result.source, content="text")
  guard result.selection is Some(range) else {
    fail("expected a selection after Bold unwrap")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="4")
}

///|
test "Italic command wraps and unwraps symmetrically" {
  let wrap_selection : MarkdownEditorSelection = {
    caret: 4,
    selection: Some(@core.TextRange::new(start=0, end=4)),
  }
  let wrapped = markdown_editor_apply_command_at(
    "text",
    Italic,
    Some(wrap_selection),
  )
  inspect(wrapped.source, content="*text*")
  // Now unwrap by selecting the inner text [1, 5) of "*text*"
  let unwrap_selection : MarkdownEditorSelection = {
    caret: 5,
    selection: Some(@core.TextRange::new(start=1, end=5)),
  }
  let unwrapped = markdown_editor_apply_command_at(
    "*text*",
    Italic,
    Some(unwrap_selection),
  )
  inspect(unwrapped.source, content="text")
}

///|
test "Code command wraps and unwraps symmetrically" {
  let wrap_selection : MarkdownEditorSelection = {
    caret: 4,
    selection: Some(@core.TextRange::new(start=0, end=4)),
  }
  let wrapped = markdown_editor_apply_command_at(
    "text",
    Code,
    Some(wrap_selection),
  )
  inspect(wrapped.source, content="`text`")
  // Unwrap by selecting the inner text [1, 5) of "`text`"
  let unwrap_selection : MarkdownEditorSelection = {
    caret: 5,
    selection: Some(@core.TextRange::new(start=1, end=5)),
  }
  let unwrapped = markdown_editor_apply_command_at(
    "`text`",
    Code,
    Some(unwrap_selection),
  )
  inspect(unwrapped.source, content="text")
}

///|
test "Strikethrough command wraps and unwraps symmetrically" {
  let wrap_selection : MarkdownEditorSelection = {
    caret: 4,
    selection: Some(@core.TextRange::new(start=0, end=4)),
  }
  let wrapped = markdown_editor_apply_command_at(
    "text",
    Strikethrough,
    Some(wrap_selection),
  )
  inspect(wrapped.source, content="~~text~~")
  // Unwrap by selecting the inner text [2, 6) of "~~text~~"
  let unwrap_selection : MarkdownEditorSelection = {
    caret: 6,
    selection: Some(@core.TextRange::new(start=2, end=6)),
  }
  let unwrapped = markdown_editor_apply_command_at(
    "~~text~~",
    Strikethrough,
    Some(unwrap_selection),
  )
  inspect(unwrapped.source, content="text")
}

///|
test "Link and image commands preserve unicode scalar selections" {
  let link_selection : MarkdownEditorSelection = {
    caret: 9,
    selection: Some(@core.TextRange::new(start=5, end=9)),
  }
  let linked = markdown_editor_apply_command_at(
    "前缀 🤣 MoUI tail",
    Link,
    Some(link_selection),
  )
  inspect(linked.source, content="前缀 🤣 [MoUI](https://example.com) tail")
  guard linked.selection is Some(linked_selection) else {
    fail("expected linked text selection")
  }
  inspect(linked_selection.start, content="6")
  inspect(linked_selection.end, content="10")
  let unlinked = markdown_editor_apply_command_at(
    linked.source,
    Link,
    Some({ caret: 10, selection: Some(linked_selection) }),
  )
  inspect(unlinked.source, content="前缀 🤣 MoUI tail")
  guard unlinked.selection is Some(unlinked_selection) else {
    fail("expected unlinked text selection")
  }
  inspect(unlinked_selection.start, content="5")
  inspect(unlinked_selection.end, content="9")

  let image = markdown_editor_apply_command_at(
    "前缀 🤣 logo tail",
    Image,
    Some(link_selection),
  )
  inspect(image.source, content="前缀 🤣 ![logo](image.png) tail")
  guard image.selection is Some(image_selection) else {
    fail("expected image alt selection")
  }
  inspect(image_selection.start, content="7")
  inspect(image_selection.end, content="11")
  let unwrapped_image = markdown_editor_apply_command_at(
    image.source,
    Image,
    Some({ caret: 11, selection: Some(image_selection) }),
  )
  inspect(unwrapped_image.source, content="前缀 🤣 logo tail")
}

///|
test "SetLinkTarget preserves unicode scalar target ranges" {
  let updated = markdown_editor_apply_command_at(
    "前缀 🤣 [MoUI](old.example) tail",
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 10, selection: Some(@core.TextRange::new(start=6, end=10)) }),
  )
  inspect(updated.source, content="前缀 🤣 [MoUI](https://wzzc-dev.github.io/MoUI) tail")
  guard updated.selection is Some(selection) else {
    fail("expected link text selection")
  }
  inspect(selection.start, content="6")
  inspect(selection.end, content="10")
}

///|
test "Heading(1) command transforms a paragraph line" {
  // source = "Body", caret at position 2 (middle of the line)
  let selection : MarkdownEditorSelection = { caret: 2, selection: None }
  let result = markdown_editor_apply_command_at(
    "Body",
    Heading(1),
    Some(selection),
  )
  assert_true(result.source.contains("# "))
  assert_true(result.source.contains("Body"))
}

///|
test "BulletList command transforms a paragraph line" {
  let selection : MarkdownEditorSelection = { caret: 2, selection: None }
  let result = markdown_editor_apply_command_at(
    "Body",
    BulletList,
    Some(selection),
  )
  assert_true(result.source.contains("- "))
  assert_true(result.source.contains("Body"))
}

///|
test "TaskList command transforms a paragraph line" {
  let selection : MarkdownEditorSelection = { caret: 2, selection: None }
  let result = markdown_editor_apply_command_at(
    "Body",
    TaskList,
    Some(selection),
  )
  assert_true(result.source.contains("- [ ]"))
}

///|
test "OrderedList command transforms a paragraph line" {
  let selection : MarkdownEditorSelection = { caret: 2, selection: None }
  let result = markdown_editor_apply_command_at(
    "Body",
    OrderedList,
    Some(selection),
  )
  assert_true(result.source.contains("1. "))
}

///|
test "Quote command transforms a paragraph line" {
  let selection : MarkdownEditorSelection = { caret: 2, selection: None }
  let result = markdown_editor_apply_command_at("Body", Quote, Some(selection))
  assert_true(result.source.contains("> "))
  assert_true(result.source.contains("Body"))
}

///|
test "Paragraph command strips a heading marker back to paragraph" {
  // source = "# Body", caret in the middle of the line
  let selection : MarkdownEditorSelection = { caret: 4, selection: None }
  let result = markdown_editor_apply_command_at(
    "# Body",
    Paragraph,
    Some(selection),
  )
  // The heading marker should be removed.
  assert_false(result.source.contains("#"))
  assert_true(result.source.contains("Body"))
}

///|
test "HorizontalRule command replaces the current line" {
  let selection : MarkdownEditorSelection = { caret: 2, selection: None }
  let result = markdown_editor_apply_command_at(
    "Body",
    HorizontalRule,
    Some(selection),
  )
  inspect(result.source, content="---")
}

///|
test "markdown_editor_inline_marker returns marker strings" {
  inspect(markdown_editor_inline_marker(Bold), content="**")
  inspect(markdown_editor_inline_marker(Italic), content="*")
  inspect(markdown_editor_inline_marker(Code), content="`")
  inspect(markdown_editor_inline_marker(Strikethrough), content="~~")
  // Non-inline commands return an empty marker.
  inspect(markdown_editor_inline_marker(Paragraph), content="")
}

///|
test "markdown_editor_range_has_inline_marker detects existing markers" {
  // "**text**" with range [2, 6) has bold marker.
  assert_true(
    markdown_editor_range_has_inline_marker(
      "**text**",
      @core.TextRange::new(start=2, end=6),
      "**",
    ),
  )
  // "text" with range [0, 4) does not have bold marker.
  assert_false(
    markdown_editor_range_has_inline_marker(
      "text",
      @core.TextRange::new(start=0, end=4),
      "**",
    ),
  )
}

///|
test "markdown_editor_inline_marker_pair_at_caret finds surrounding markers" {
  // source = "**bold**", caret at 4 (inside "bold")
  let range = markdown_editor_inline_marker_pair_at_caret("**bold**", 4, "**")
  guard range is Some(r) else { fail("expected marker pair") }
  inspect(r.start, content="2")
  inspect(r.end, content="6")
}

///|
test "Command result caret is within source bounds" {
  let selection : MarkdownEditorSelection = {
    caret: 4,
    selection: Some(@core.TextRange::new(start=0, end=4)),
  }
  let result = markdown_editor_apply_command_at("text", Bold, Some(selection))
  let source_length = markdown_editor_text_length(result.source)
  assert_true(result.caret >= 0)
  assert_true(result.caret <= source_length)
}
