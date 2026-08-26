///|
test "markdown editor paste url wraps or updates selected link text" {
  let wrapped = markdown_editor_transform_input(
    "Visit MoUI today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "https://wzzc-dev.github.io/MoUI",
  ).unwrap()
  inspect(wrapped.text, content="Visit [MoUI](https://wzzc-dev.github.io/MoUI) today")
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
    "https://docs.https://wzzc-dev.github.io/MoUI",
  ).unwrap()
  inspect(updated.text, content="Visit [MoUI](https://docs.https://wzzc-dev.github.io/MoUI) today")
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
      "https://wzzc-dev.github.io/MoUI/docs page",
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
    "[Other](https://wzzc-dev.github.io/MoUI/docs \"Docs\")",
  ).unwrap()
  inspect(titled.text, content="Visit [Docs](https://wzzc-dev.github.io/MoUI/docs) today")

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

  let unicode_reference = markdown_editor_transform_input(
    "前缀 🤣 Docs today",
    9,
    Some(@core.TextRange::new(start=5, end=9)),
    "[Other][site]",
  ).unwrap()
  inspect(unicode_reference.text, content="前缀 🤣 [Docs][site] today")
  guard unicode_reference.selection is Some(unicode_reference_selection) else {
    fail("expected unicode reference link text selection")
  }
  inspect(unicode_reference_selection.start, content="6")
  inspect(unicode_reference_selection.end, content="10")

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
    "[site]: https://wzzc-dev.github.io/MoUI/docs",
  ).unwrap()
  inspect(
    definition.text,
    content="Visit [Docs][site] today\n\n[site]: https://wzzc-dev.github.io/MoUI/docs",
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
    "https://wzzc-dev.github.io/MoUI",
  ).unwrap()
  inspect(updated.text, content="Visit [MoUI](https://wzzc-dev.github.io/MoUI) today")
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
    "[site]: https://wzzc-dev.github.io/MoUI",
  ).unwrap()
  inspect(
    definition.text,
    content="Visit [MoUI][site] today\n\n[site]: https://wzzc-dev.github.io/MoUI",
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

//|

///|
test "markdown editor insert text at cursor replaces selection" {
  let app = MarkdownEditorApp::new()
  app.edit_document("Hello World")
  app.selection = {
    caret: 6,
    selection: Some(@core.TextRange::new(start=6, end=11)),
  }
  app.insert_text_at_cursor("MoonBit")
  inspect(app.document(), content="Hello MoonBit")
  inspect(app.selection_caret(), content="13")
}

//|

///|
test "markdown editor insert text at cursor inserts at caret" {
  let app = MarkdownEditorApp::new()
  app.edit_document("Hello World")
  app.selection = { caret: 6, selection: None }
  app.insert_text_at_cursor(" MoonBit")
  inspect(app.document(), content="Hello  MoonBitWorld")
}

//|

///|
test "markdown editor insert media from path inserts image markdown" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("Start ", path="")
  app.selection = { caret: 6, selection: None }
  app.insert_media_from_path("/images/photo.png")
  inspect(app.document(), content="Start ![photo](/images/photo.png)")
}

//|

///|
test "markdown editor image alt from filename strips extension" {
  inspect(
    markdown_editor_image_alt_from_filename("my-photo.png"),
    content="my photo",
  )
  inspect(markdown_editor_image_alt_from_filename("logo.svg"), content="logo")
  inspect(
    markdown_editor_image_alt_from_filename("README.md"),
    content="README",
  )
  inspect(markdown_editor_image_alt_from_filename("README"), content="README")
  inspect(markdown_editor_image_alt_from_filename(""), content="")
}
