///|
test "markdown editor core applies typed commands" {
  inspect(markdown_editor_apply_command("", Heading(2)), content="## Section")
  inspect(
    markdown_editor_apply_command("", Heading(6)),
    content="###### Caption",
  )
  inspect(markdown_editor_apply_command("", HorizontalRule), content="---")
  inspect(
    markdown_editor_apply_command("Base", Bold),
    content="Base\n\n**bold text**",
  )
}

///|
test "markdown editor inline command wraps selected source range" {
  let result = markdown_editor_apply_command_at(
    "# Title",
    Bold,
    Some({ caret: 7, selection: Some(@core.TextRange::new(start=2, end=7)) }),
  )
  inspect(result.source, content="# **Title**")
  inspect(result.caret, content="9")
  guard result.selection is Some(selection) else {
    fail("expected updated selection")
  }
  inspect(selection.start, content="4")
  inspect(selection.end, content="9")
}

///|
test "markdown editor typed inline marker wraps selected source range" {
  let bold = markdown_editor_transform_input(
    "Text bold tail",
    9,
    Some(@core.TextRange::new(start=5, end=9)),
    "**",
  ).unwrap()
  inspect(bold.text, content="Text **bold** tail")
  inspect(bold.caret, content="11")
  guard bold.selection is Some(bold_selection) else {
    fail("expected bold selection")
  }
  inspect(bold_selection.start, content="7")
  inspect(bold_selection.end, content="11")
  let code = markdown_editor_transform_input(
    "Use code now",
    8,
    Some(@core.TextRange::new(start=4, end=8)),
    "`",
  ).unwrap()
  inspect(code.text, content="Use `code` now")
  let strike = markdown_editor_transform_input(
    "old text",
    3,
    Some(@core.TextRange::new(start=0, end=3)),
    "~~",
  ).unwrap()
  inspect(strike.text, content="~~old~~ text")
}

///|
test "markdown editor typed inline marker unwraps selected formatted range" {
  let result = markdown_editor_transform_input(
    "Text **bold** tail",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "**",
  ).unwrap()
  inspect(result.text, content="Text bold tail")
  inspect(result.caret, content="9")
  guard result.selection is Some(selection) else {
    fail("expected unwrapped selection")
  }
  inspect(selection.start, content="5")
  inspect(selection.end, content="9")
}

///|
test "markdown editor paste url wraps or updates selected link text" {
  let wrapped = markdown_editor_transform_input(
    "Visit MoUI today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "https://moui.dev",
  ).unwrap()
  inspect(wrapped.text, content="Visit [MoUI](https://moui.dev) today")
  inspect(wrapped.caret, content="11")
  guard wrapped.selection is Some(wrapped_selection) else {
    fail("expected wrapped link selection")
  }
  inspect(wrapped_selection.start, content="7")
  inspect(wrapped_selection.end, content="11")
  let updated = markdown_editor_transform_input(
    wrapped.text,
    11,
    Some(wrapped_selection),
    "https://docs.moui.dev",
  ).unwrap()
  inspect(updated.text, content="Visit [MoUI](https://docs.moui.dev) today")
  guard updated.selection is Some(updated_selection) else {
    fail("expected updated link selection")
  }
  inspect(updated_selection.start, content="7")
  inspect(updated_selection.end, content="11")
  inspect(
    markdown_editor_transform_input(
      "Visit MoUI today",
      10,
      Some(@core.TextRange::new(start=6, end=10)),
      "https://moui.dev/docs page",
    )
    is None,
    content="true",
  )
}

///|
test "markdown editor paste markdown link reuses target for selected text" {
  let relative = markdown_editor_transform_input(
    "Visit Docs today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "[Other](docs/guide.md)",
  ).unwrap()
  inspect(relative.text, content="Visit [Docs](docs/guide.md) today")
  inspect(relative.caret, content="11")
  guard relative.selection is Some(relative_selection) else {
    fail("expected wrapped link selection")
  }
  inspect(relative_selection.start, content="7")
  inspect(relative_selection.end, content="11")

  let titled = markdown_editor_transform_input(
    "Visit Docs today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "[Other](https://moui.dev/docs \"Docs\")",
  ).unwrap()
  inspect(titled.text, content="Visit [Docs](https://moui.dev/docs) today")

  let angled = markdown_editor_transform_input(
    "Visit Docs today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "[Other](<docs/guide.md> \"Docs\")",
  ).unwrap()
  inspect(angled.text, content="Visit [Docs](docs/guide.md) today")

  let full_reference = markdown_editor_transform_input(
    "Visit Docs today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "[Other][site]",
  ).unwrap()
  inspect(full_reference.text, content="Visit [Docs][site] today")
  guard full_reference.selection is Some(full_reference_selection) else {
    fail("expected reference link text selection")
  }
  inspect(full_reference_selection.start, content="7")
  inspect(full_reference_selection.end, content="11")

  let shortcut_reference = markdown_editor_transform_input(
    "Visit Docs today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "[Other]",
  ).unwrap()
  inspect(shortcut_reference.text, content="Visit [Docs][Other] today")

  let definition = markdown_editor_transform_input(
    "Visit Docs today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "[site]: https://moui.dev/docs",
  ).unwrap()
  inspect(
    definition.text,
    content="Visit [Docs][site] today\n\n[site]: https://moui.dev/docs",
  )
  guard definition.selection is Some(definition_selection) else {
    fail("expected pasted definition link text selection")
  }
  inspect(definition_selection.start, content="7")
  inspect(definition_selection.end, content="11")

  let existing = markdown_editor_transform_input(
    "Visit [Docs](old.md) today",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "[Other][site]",
  ).unwrap()
  inspect(existing.text, content="Visit [Docs][site] today")
}

///|
test "markdown editor paste link target updates current link context" {
  let updated = markdown_editor_transform_input(
    "Visit [MoUI](https://old.example) today",
    9,
    None,
    "https://moui.dev",
  ).unwrap()
  inspect(updated.text, content="Visit [MoUI](https://moui.dev) today")
  inspect(updated.caret, content="11")
  guard updated.selection is Some(selection) else {
    fail("expected linked text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")

  let markdown = markdown_editor_transform_input(
    "Visit [MoUI](https://old.example) today",
    9,
    None,
    "[Docs](docs/guide.md)",
  ).unwrap()
  inspect(markdown.text, content="Visit [MoUI](docs/guide.md) today")

  let reference = markdown_editor_transform_input(
    "Visit [MoUI](https://old.example) today",
    9,
    None,
    "[Docs][site]",
  ).unwrap()
  inspect(reference.text, content="Visit [MoUI][site] today")
  guard reference.selection is Some(reference_selection) else {
    fail("expected reference-style linked text selection")
  }
  inspect(reference_selection.start, content="7")
  inspect(reference_selection.end, content="11")

  let shortcut = markdown_editor_transform_input(
    "Visit [MoUI](https://old.example) today",
    9,
    None,
    "[Docs]",
  ).unwrap()
  inspect(shortcut.text, content="Visit [MoUI][Docs] today")

  let definition = markdown_editor_transform_input(
    "Visit [MoUI](https://old.example) today",
    9,
    None,
    "[site]: https://moui.dev",
  ).unwrap()
  inspect(
    definition.text,
    content="Visit [MoUI][site] today\n\n[site]: https://moui.dev",
  )
  guard definition.selection is Some(definition_selection) else {
    fail("expected pasted definition current link selection")
  }
  inspect(definition_selection.start, content="7")
  inspect(definition_selection.end, content="11")
}

///|
test "markdown editor paste image source wraps or updates selected alt text" {
  let wrapped = markdown_editor_transform_input(
    "Insert logo here",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "assets/logo.png",
  ).unwrap()
  inspect(wrapped.text, content="Insert ![logo](assets/logo.png) here")
  inspect(wrapped.caret, content="13")
  guard wrapped.selection is Some(wrapped_selection) else {
    fail("expected wrapped image selection")
  }
  inspect(wrapped_selection.start, content="9")
  inspect(wrapped_selection.end, content="13")
  let updated = markdown_editor_transform_input(
    wrapped.text,
    13,
    Some(wrapped_selection),
    "https://cdn.example/logo.webp",
  ).unwrap()
  inspect(
    updated.text,
    content="Insert ![logo](https://cdn.example/logo.webp) here",
  )
  guard updated.selection is Some(updated_selection) else {
    fail("expected updated image selection")
  }
  inspect(updated_selection.start, content="9")
  inspect(updated_selection.end, content="13")
}

///|
test "markdown editor paste markdown image reuses target for selected alt text" {
  let wrapped = markdown_editor_transform_input(
    "Insert logo here",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "![old](assets/logo.png)",
  ).unwrap()
  inspect(wrapped.text, content="Insert ![logo](assets/logo.png) here")
  inspect(wrapped.caret, content="13")
  guard wrapped.selection is Some(wrapped_selection) else {
    fail("expected image alt selection")
  }
  inspect(wrapped_selection.start, content="9")
  inspect(wrapped_selection.end, content="13")
  inspect(
    markdown_editor_transform_input(
      "Insert logo here",
      11,
      Some(@core.TextRange::new(start=7, end=11)),
      "![old](docs/readme.md)",
    )
    is None,
    content="true",
  )

  let reference = markdown_editor_transform_input(
    "Insert logo here",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "![old][asset]",
  ).unwrap()
  inspect(reference.text, content="Insert ![logo][asset] here")
  guard reference.selection is Some(reference_selection) else {
    fail("expected reference image alt selection")
  }
  inspect(reference_selection.start, content="9")
  inspect(reference_selection.end, content="13")

  let shortcut = markdown_editor_transform_input(
    "Insert logo here",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "![old]",
  ).unwrap()
  inspect(shortcut.text, content="Insert ![logo][old] here")

  let existing = markdown_editor_transform_input(
    "Insert ![logo](old.png) here",
    13,
    Some(@core.TextRange::new(start=9, end=13)),
    "![old][asset]",
  ).unwrap()
  inspect(existing.text, content="Insert ![logo][asset] here")
}

///|
test "markdown editor paste image target updates current image context" {
  let updated = markdown_editor_transform_input(
    "Insert ![logo](old.png) here",
    11,
    None,
    "assets/logo.png",
  ).unwrap()
  inspect(updated.text, content="Insert ![logo](assets/logo.png) here")
  inspect(updated.caret, content="13")
  guard updated.selection is Some(selection) else {
    fail("expected image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")

  let markdown = markdown_editor_transform_input(
    "Insert ![logo](old.png) here",
    11,
    None,
    "![old](https://cdn.example/logo.webp)",
  ).unwrap()
  inspect(
    markdown.text,
    content="Insert ![logo](https://cdn.example/logo.webp) here",
  )

  let reference = markdown_editor_transform_input(
    "Insert ![logo](old.png) here",
    11,
    None,
    "![old][asset]",
  ).unwrap()
  inspect(reference.text, content="Insert ![logo][asset] here")
  guard reference.selection is Some(reference_selection) else {
    fail("expected reference-style image alt selection")
  }
  inspect(reference_selection.start, content="9")
  inspect(reference_selection.end, content="13")

  let shortcut = markdown_editor_transform_input(
    "Insert ![logo](old.png) here",
    11,
    None,
    "![old]",
  ).unwrap()
  inspect(shortcut.text, content="Insert ![logo][old] here")
}
