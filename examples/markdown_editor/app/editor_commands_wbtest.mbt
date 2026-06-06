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

///|
test "markdown editor paste and typed space complete autolinks" {
  let pasted = markdown_editor_transform_input(
    "Visit ",
    6,
    None,
    "https://moui.dev",
  ).unwrap()
  inspect(pasted.text, content="Visit <https://moui.dev>")
  inspect(pasted.caret, content="24")
  let punctuated_paste = markdown_editor_transform_input(
    "Visit ",
    6,
    None,
    "https://moui.dev,",
  ).unwrap()
  inspect(punctuated_paste.text, content="Visit <https://moui.dev>,")
  inspect(punctuated_paste.caret, content="25")
  let wrapped_paste = markdown_editor_transform_input(
    "Visit ",
    6,
    None,
    "(https://moui.dev),",
  ).unwrap()
  inspect(wrapped_paste.text, content="Visit (<https://moui.dev>),")
  inspect(wrapped_paste.caret, content="27")
  let typed = markdown_editor_transform_input(
    "Visit https://moui.dev",
    22,
    None,
    " ",
  ).unwrap()
  inspect(typed.text, content="Visit <https://moui.dev> ")
  inspect(typed.caret, content="25")
  let punctuated_typed = markdown_editor_transform_input(
    "Visit https://moui.dev,",
    23,
    None,
    " ",
  ).unwrap()
  inspect(punctuated_typed.text, content="Visit <https://moui.dev>, ")
  inspect(punctuated_typed.caret, content="26")
  let wrapped_typed = markdown_editor_transform_input(
    "Visit (https://moui.dev),",
    25,
    None,
    " ",
  ).unwrap()
  inspect(wrapped_typed.text, content="Visit (<https://moui.dev>), ")
  inspect(wrapped_typed.caret, content="28")
  inspect(
    markdown_editor_transform_input("Visit <https://moui.dev>", 23, None, " ")
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("```\nhttps://moui.dev\n```", 20, None, " ")
    is None,
    content="true",
  )
}

///|
test "markdown editor paste and typed space complete email autolinks" {
  let pasted = markdown_editor_transform_input(
    "Mail ",
    5,
    None,
    "hello+moui@example.dev",
  ).unwrap()
  inspect(pasted.text, content="Mail <hello+moui@example.dev>")
  inspect(pasted.caret, content="29")
  let punctuated_paste = markdown_editor_transform_input(
    "Mail ",
    5,
    None,
    "hello@example.dev.",
  ).unwrap()
  inspect(punctuated_paste.text, content="Mail <hello@example.dev>.")
  inspect(punctuated_paste.caret, content="25")
  let wrapped_paste = markdown_editor_transform_input(
    "Mail ",
    5,
    None,
    "[hello@example.dev];",
  ).unwrap()
  inspect(wrapped_paste.text, content="Mail [<hello@example.dev>];")
  inspect(wrapped_paste.caret, content="27")
  let typed = markdown_editor_transform_input(
    "Mail hello@example.dev",
    22,
    None,
    " ",
  ).unwrap()
  inspect(typed.text, content="Mail <hello@example.dev> ")
  inspect(typed.caret, content="25")
  let punctuated_typed = markdown_editor_transform_input(
    "Mail hello@example.dev!",
    23,
    None,
    " ",
  ).unwrap()
  inspect(punctuated_typed.text, content="Mail <hello@example.dev>! ")
  inspect(punctuated_typed.caret, content="26")
  let wrapped_typed = markdown_editor_transform_input(
    "Mail [hello@example.dev];",
    25,
    None,
    " ",
  ).unwrap()
  inspect(wrapped_typed.text, content="Mail [<hello@example.dev>]; ")
  inspect(wrapped_typed.caret, content="28")
  inspect(
    markdown_editor_transform_input("Mail <hello@example.dev>", 23, None, " ")
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("Mail hello@example", 18, None, " ") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input(
      "```\nhello@example.dev\n```",
      21,
      None,
      " ",
    )
    is None,
    content="true",
  )
}

///|
test "markdown editor inline command unwraps matching marker pair" {
  let bold = markdown_editor_apply_command_at(
    "Text **bold** tail",
    Bold,
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(bold.source, content="Text bold tail")
  inspect(bold.caret, content="9")
  guard bold.selection is Some(bold_selection) else {
    fail("expected unwrapped bold selection")
  }
  inspect(bold_selection.start, content="5")
  inspect(bold_selection.end, content="9")
  let code = markdown_editor_apply_command_at(
    "Use `code` now",
    Code,
    Some({ caret: 9, selection: Some(@core.TextRange::new(start=5, end=9)) }),
  )
  inspect(code.source, content="Use code now")
  inspect(code.caret, content="8")
  let strike = markdown_editor_apply_command_at(
    "~~old~~ text",
    Strikethrough,
    Some({ caret: 5, selection: Some(@core.TextRange::new(start=2, end=5)) }),
  )
  inspect(strike.source, content="old text")
}

///|
test "markdown editor inline command unwraps current formatted span" {
  let bold = markdown_editor_apply_command_at(
    "Text **bold** tail",
    Bold,
    Some({ caret: 9, selection: None }),
  )
  inspect(bold.source, content="Text bold tail")
  inspect(bold.caret, content="9")
  guard bold.selection is Some(bold_selection) else {
    fail("expected unwrapped bold selection")
  }
  inspect(bold_selection.start, content="5")
  inspect(bold_selection.end, content="9")

  let italic = markdown_editor_apply_command_at(
    "Use *em* now",
    Italic,
    Some({ caret: 6, selection: None }),
  )
  inspect(italic.source, content="Use em now")
  guard italic.selection is Some(italic_selection) else {
    fail("expected unwrapped italic selection")
  }
  inspect(italic_selection.start, content="4")
  inspect(italic_selection.end, content="6")

  let code = markdown_editor_apply_command_at(
    "Use `code` now",
    Code,
    Some({ caret: 7, selection: None }),
  )
  inspect(code.source, content="Use code now")

  let strike = markdown_editor_apply_command_at(
    "Keep ~~old~~ text",
    Strikethrough,
    Some({ caret: 9, selection: None }),
  )
  inspect(strike.source, content="Keep old text")
}

///|
test "markdown editor link command wraps and unwraps selected text" {
  let linked = markdown_editor_apply_command_at(
    "Visit MoUI today",
    Link,
    Some({ caret: 10, selection: Some(@core.TextRange::new(start=6, end=10)) }),
  )
  inspect(linked.source, content="Visit [MoUI](https://example.com) today")
  guard linked.selection is Some(selection) else {
    fail("expected linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
  let unlinked = markdown_editor_apply_command_at(
    linked.source,
    Link,
    Some({ caret: 11, selection: Some(selection) }),
  )
  inspect(unlinked.source, content="Visit MoUI today")
  guard unlinked.selection is Some(unlinked_selection) else {
    fail("expected unlinked selection")
  }
  inspect(unlinked_selection.start, content="6")
  inspect(unlinked_selection.end, content="10")
}

///|
test "markdown editor link command unwraps link at caret" {
  let inline = markdown_editor_apply_command_at(
    "Visit [MoUI](https://example.com) today",
    Link,
    Some({ caret: 9, selection: None }),
  )
  inspect(inline.source, content="Visit MoUI today")
  guard inline.selection is Some(inline_selection) else {
    fail("expected unlinked inline selection")
  }
  inspect(inline_selection.start, content="6")
  inspect(inline_selection.end, content="10")

  let reference = markdown_editor_apply_command_at(
    "Visit [MoUI][site] today\n\n[site]: https://example.com",
    Link,
    Some({ caret: 9, selection: None }),
  )
  inspect(
    reference.source,
    content="Visit MoUI today\n\n[site]: https://example.com",
  )

  let autolink = markdown_editor_apply_command_at(
    "Mail <hello@example.dev>",
    Link,
    Some({ caret: 12, selection: None }),
  )
  inspect(autolink.source, content="Mail hello@example.dev")
}

///|
test "markdown editor image command wraps and unwraps selected alt text" {
  let inserted = markdown_editor_apply_command_at(
    "Insert logo here",
    Image,
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(inserted.source, content="Insert ![logo](image.png) here")
  guard inserted.selection is Some(selection) else {
    fail("expected image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
  let unwrapped = markdown_editor_apply_command_at(
    inserted.source,
    Image,
    Some({ caret: 13, selection: Some(selection) }),
  )
  inspect(unwrapped.source, content="Insert logo here")
  guard unwrapped.selection is Some(unwrapped_selection) else {
    fail("expected unwrapped image alt selection")
  }
  inspect(unwrapped_selection.start, content="7")
  inspect(unwrapped_selection.end, content="11")
}

///|
test "markdown editor image command unwraps image at caret" {
  let inline = markdown_editor_apply_command_at(
    "Insert ![logo](image.png) here",
    Image,
    Some({ caret: 10, selection: None }),
  )
  inspect(inline.source, content="Insert logo here")
  guard inline.selection is Some(inline_selection) else {
    fail("expected unwrapped image selection")
  }
  inspect(inline_selection.start, content="7")
  inspect(inline_selection.end, content="11")

  let reference = markdown_editor_apply_command_at(
    "Insert ![logo][img] here\n\n[img]: image.png",
    Image,
    Some({ caret: 10, selection: None }),
  )
  inspect(reference.source, content="Insert logo here\n\n[img]: image.png")
}

///|
test "markdown editor link target command updates and wraps selected text" {
  let updated = markdown_editor_apply_command_at(
    "Visit [MoUI](https://example.com) today",
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(updated.source, content="Visit [MoUI](https://moui.dev) today")
  guard updated.selection is Some(selection) else {
    fail("expected updated link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
  let wrapped = markdown_editor_apply_command_at(
    "Visit MoUI today",
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 10, selection: Some(@core.TextRange::new(start=6, end=10)) }),
  )
  inspect(wrapped.source, content="Visit [MoUI](https://moui.dev) today")
}

///|
test "markdown editor link target command updates target at caret" {
  let inline = markdown_editor_apply_command_at(
    "Visit [MoUI](https://old.example) today",
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 9, selection: None }),
  )
  inspect(inline.source, content="Visit [MoUI](https://moui.dev) today")
  guard inline.selection is Some(inline_selection) else {
    fail("expected inline link text selection")
  }
  inspect(inline_selection.start, content="7")
  inspect(inline_selection.end, content="11")

  let reference = markdown_editor_apply_command_at(
    "Visit [MoUI][site] today\n\n[site]: https://old.example",
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 9, selection: None }),
  )
  inspect(
    reference.source,
    content="Visit [MoUI][site] today\n\n[site]: https://moui.dev",
  )

  let autolink = markdown_editor_apply_command_at(
    "Mail <hello@example.dev>",
    SetLinkTarget("team@example.dev"),
    Some({ caret: 12, selection: None }),
  )
  inspect(autolink.source, content="Mail <team@example.dev>")
}

///|
test "markdown editor image target command updates target at caret" {
  let inline = markdown_editor_apply_command_at(
    "Insert ![logo](old.png) here",
    SetImageTarget("assets/logo.png"),
    Some({ caret: 10, selection: None }),
  )
  inspect(inline.source, content="Insert ![logo](assets/logo.png) here")
  guard inline.selection is Some(inline_selection) else {
    fail("expected image alt selection")
  }
  inspect(inline_selection.start, content="9")
  inspect(inline_selection.end, content="13")

  let reference = markdown_editor_apply_command_at(
    "Insert ![logo][img] here\n\n[img]: old.png",
    SetImageTarget("assets/logo.png"),
    Some({ caret: 10, selection: None }),
  )
  inspect(
    reference.source,
    content="Insert ![logo][img] here\n\n[img]: assets/logo.png",
  )
}

///|
test "markdown editor link target command updates selected autolink" {
  let source = "Mail <hello@example.dev> or visit <https://old.example>"
  guard markdown_editor_selected_link_target(source, {
      caret: 24,
      selection: Some(@core.TextRange::new(start=6, end=23)),
    })
    is Some("hello@example.dev") else {
    fail("expected selected email autolink target")
  }
  let updated_email = markdown_editor_apply_command_at(
    source,
    SetLinkTarget("team@example.dev"),
    Some({ caret: 23, selection: Some(@core.TextRange::new(start=6, end=23)) }),
  )
  inspect(
    updated_email.source,
    content="Mail <team@example.dev> or visit <https://old.example>",
  )
  guard updated_email.selection is Some(email_selection) else {
    fail("expected updated email autolink selection")
  }
  inspect(email_selection.start, content="6")
  inspect(email_selection.end, content="23")

  guard markdown_editor_selected_link_target(source, {
      caret: 54,
      selection: Some(@core.TextRange::new(start=35, end=54)),
    })
    is Some("https://old.example") else {
    fail("expected selected URL autolink target")
  }
  let updated_url = markdown_editor_apply_command_at(
    source,
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 54, selection: Some(@core.TextRange::new(start=35, end=54)) }),
  )
  inspect(
    updated_url.source,
    content="Mail <hello@example.dev> or visit <https://moui.dev>",
  )
}

///|
test "markdown editor link target command updates reference definition" {
  let source = "Visit [MoUI][site] today\n\n[site]: https://example.com"
  guard markdown_editor_selected_link_target(source, {
      caret: 11,
      selection: Some(@core.TextRange::new(start=7, end=11)),
    })
    is Some("https://example.com") else {
    fail("expected selected reference link target")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI][site] today\n\n[site]: https://moui.dev",
  )
  guard updated.selection is Some(selection) else {
    fail("expected reference link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor link target command creates missing reference definition" {
  let source = "Visit [MoUI][site] today"
  let updated = markdown_editor_apply_command_at(
    source,
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI][site] today\n\n[site]: https://moui.dev",
  )
  guard updated.selection is Some(selection) else {
    fail("expected reference link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor link target command updates shortcut reference definition" {
  let source = "Visit [MoUI] today\n\n[MoUI]: https://example.com"
  guard markdown_editor_selected_link_target(source, {
      caret: 11,
      selection: Some(@core.TextRange::new(start=7, end=11)),
    })
    is Some("https://example.com") else {
    fail("expected selected shortcut reference target")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI] today\n\n[MoUI]: https://moui.dev",
  )
  guard updated.selection is Some(selection) else {
    fail("expected shortcut reference link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor link target command creates shortcut reference definition" {
  let source = "Visit [MoUI] today"
  let updated = markdown_editor_apply_command_at(
    source,
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI] today\n\n[MoUI]: https://moui.dev",
  )
  guard updated.selection is Some(selection) else {
    fail("expected shortcut reference link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor reads selected link and image targets" {
  let source = "Visit [MoUI](https://moui.dev) and ![logo](assets/logo.png)"
  guard markdown_editor_selected_link_target(source, {
      caret: 11,
      selection: Some(@core.TextRange::new(start=7, end=11)),
    })
    is Some("https://moui.dev") else {
    fail("expected selected link target")
  }
  guard markdown_editor_selected_image_target(source, {
      caret: 41,
      selection: Some(@core.TextRange::new(start=37, end=41)),
    })
    is Some("assets/logo.png") else {
    fail("expected selected image target")
  }
  inspect(
    markdown_editor_selected_link_target(source, {
      caret: 5,
      selection: Some(@core.TextRange::new(start=0, end=5)),
    })
    is None,
    content="true",
  )
}

///|
test "markdown editor code language command updates fenced block" {
  let source = "Intro\n```moonbit\nlet x = 1\n```\nTail"
  let snapshot = MarkdownEditorSnapshot::parse(source)
  guard snapshot.blocks[1].block.code_language is Some("moonbit") else {
    fail("expected parsed code language")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetCodeLanguage("rust"),
    Some({ caret: 20, selection: None }),
  )
  inspect(updated.source, content="Intro\n```rust\nlet x = 1\n```\nTail")
  inspect(updated.caret, content="17")
  let cleared = markdown_editor_apply_command_at(
    updated.source,
    SetCodeLanguage(""),
    Some({ caret: 17, selection: None }),
  )
  inspect(cleared.source, content="Intro\n```\nlet x = 1\n```\nTail")
  inspect(cleared.caret, content="13")
}

///|
test "markdown editor footnote text command updates definition" {
  let source = "Note[^a]\n\n[^a]: Old text"
  guard markdown_editor_selected_footnote_text(source, {
      caret: 7,
      selection: Some(@core.TextRange::new(start=6, end=7)),
    })
    is Some("Old text") else {
    fail("expected selected footnote text")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetFootnoteText("New text"),
    Some({ caret: 7, selection: Some(@core.TextRange::new(start=6, end=7)) }),
  )
  inspect(updated.source, content="Note[^a]\n\n[^a]: New text")
}

///|
test "markdown editor footnote text command creates missing definition" {
  let source = "Note[^a]"
  let updated = markdown_editor_apply_command_at(
    source,
    SetFootnoteText("New text"),
    Some({ caret: 7, selection: Some(@core.TextRange::new(start=6, end=7)) }),
  )
  inspect(updated.source, content="Note[^a]\n\n[^a]: New text")
}

///|
test "markdown editor paste footnote definition creates or updates footnotes" {
  let wrapped = markdown_editor_transform_input(
    "Text note here",
    9,
    Some(@core.TextRange::new(start=5, end=9)),
    "[^a]: Footnote body",
  ).unwrap()
  inspect(wrapped.text, content="Text note[^a] here\n\n[^a]: Footnote body")
  inspect(wrapped.caret, content="9")
  guard wrapped.selection is Some(wrapped_selection) else {
    fail("expected selected footnote source text")
  }
  inspect(wrapped_selection.start, content="5")
  inspect(wrapped_selection.end, content="9")

  let updated = markdown_editor_transform_input(
    "Text[^a]\n\n[^a]: Old body",
    6,
    None,
    "[^b]: New body",
  ).unwrap()
  inspect(updated.text, content="Text[^a]\n\n[^a]: New body")
  inspect(updated.caret, content="6")
}

///|
test "markdown editor html block command updates current block" {
  let source = "Intro\n<div>Old</div>\nTail"
  guard markdown_editor_selected_html_block_text(source, {
      caret: 9,
      selection: None,
    })
    is Some("<div>Old</div>") else {
    fail("expected selected html block text")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetHtmlBlockText("<section>New</section>"),
    Some({ caret: 9, selection: None }),
  )
  inspect(updated.source, content="Intro\n<section>New</section>\nTail")
}

///|
test "markdown editor image target command updates and wraps selected alt text" {
  let updated = markdown_editor_apply_command_at(
    "Insert ![logo](image.png) here",
    SetImageTarget("assets/logo.png"),
    Some({ caret: 13, selection: Some(@core.TextRange::new(start=9, end=13)) }),
  )
  inspect(updated.source, content="Insert ![logo](assets/logo.png) here")
  guard updated.selection is Some(selection) else {
    fail("expected updated image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
  let wrapped = markdown_editor_apply_command_at(
    "Insert logo here",
    SetImageTarget("assets/logo.png"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(wrapped.source, content="Insert ![logo](assets/logo.png) here")
}

///|
test "markdown editor image target command updates reference definition" {
  let source = "Insert ![logo][mark] here\n\n[mark]: old.png"
  guard markdown_editor_selected_image_target(source, {
      caret: 13,
      selection: Some(@core.TextRange::new(start=9, end=13)),
    })
    is Some("old.png") else {
    fail("expected selected reference image target")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetImageTarget("assets/logo.png"),
    Some({ caret: 13, selection: Some(@core.TextRange::new(start=9, end=13)) }),
  )
  inspect(
    updated.source,
    content="Insert ![logo][mark] here\n\n[mark]: assets/logo.png",
  )
  guard updated.selection is Some(selection) else {
    fail("expected reference image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
}

///|
test "markdown editor image target command creates missing reference definition" {
  let source = "Insert ![logo][mark] here"
  let updated = markdown_editor_apply_command_at(
    source,
    SetImageTarget("assets/logo.png"),
    Some({ caret: 13, selection: Some(@core.TextRange::new(start=9, end=13)) }),
  )
  inspect(
    updated.source,
    content="Insert ![logo][mark] here\n\n[mark]: assets/logo.png",
  )
  guard updated.selection is Some(selection) else {
    fail("expected reference image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
}

///|
test "markdown editor image command seeds an image snippet" {
  inspect(
    markdown_editor_apply_command("", Image),
    content="![image alt](image.png)",
  )
}

///|
test "markdown editor task checkbox toggles by content offset" {
  let open = markdown_editor_toggle_task_at("- [ ] todo", 6).unwrap()
  inspect(open.source, content="- [x] todo")
  inspect(open.caret, content="6")
  let checked = markdown_editor_toggle_task_at("Intro\n- [x] done", 12).unwrap()
  inspect(checked.source, content="Intro\n- [ ] done")
  let nested = markdown_editor_toggle_task_at("  - [ ] nested", 8).unwrap()
  inspect(nested.source, content="  - [x] nested")
  inspect(nested.caret, content="8")
  inspect(markdown_editor_toggle_task_at("- item", 2) is None, content="true")
}

///|
test "markdown editor current task checkbox toggles from caret" {
  let open = markdown_editor_toggle_current_task("Intro\n- [ ] todo\nTail", {
    caret: 12,
    selection: None,
  }).unwrap()
  inspect(open.source, content="Intro\n- [x] todo\nTail")
  inspect(open.caret, content="12")
  let checked = markdown_editor_toggle_current_task("Intro\n  - [x] nested", {
    caret: 17,
    selection: None,
  }).unwrap()
  inspect(checked.source, content="Intro\n  - [ ] nested")
  inspect(checked.caret, content="14")
  inspect(
    markdown_editor_toggle_current_task("Intro\n- item", {
      caret: 9,
      selection: None,
    })
    is None,
    content="true",
  )
}

///|
test "markdown editor app toggles task checkbox by prefix offset" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  app.toggle_task_at(6)
  inspect(app.document(), content="- [x] todo")
  app.toggle_task_at(6)
  inspect(app.document(), content="- [ ] todo")
}

///|
test "markdown editor app toggles current task checkbox with undo" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  app.set_selection(9, None)
  app.apply_action("toggle-task")
  inspect(app.document(), content="- [x] todo")
  assert_true(app.undo())
  inspect(app.document(), content="- [ ] todo")
  assert_true(app.redo())
  inspect(app.document(), content="- [x] todo")
}

///|
test "markdown editor block command transforms current line" {
  let result = markdown_editor_apply_command_at(
    "Intro\nTitle\nBody",
    Heading(2),
    Some({ caret: 8, selection: None }),
  )
  inspect(result.source, content="Intro\n## Title\nBody")
  inspect(result.caret, content="11")
  let h6 = markdown_editor_apply_command_at(
    "Intro\nFine print\nBody",
    Heading(6),
    Some({ caret: 8, selection: None }),
  )
  inspect(h6.source, content="Intro\n###### Fine print\nBody")
  inspect(h6.caret, content="15")
  let rule = markdown_editor_apply_command_at(
    "Intro\n---\nBody",
    HorizontalRule,
    Some({ caret: 7, selection: None }),
  )
  inspect(rule.source, content="Intro\n---\nBody")
  inspect(rule.caret, content="9")
}

///|
test "markdown editor block command replaces existing marker" {
  let result = markdown_editor_apply_command_at(
    "# Title",
    TaskList,
    Some({ caret: 4, selection: None }),
  )
  inspect(result.source, content="- [ ] Title")
  inspect(result.caret, content="8")
}

///|
test "markdown editor current line block commands preserve quote context" {
  let bullet = markdown_editor_apply_command_at(
    "> First",
    BulletList,
    Some({ caret: 4, selection: None }),
  )
  inspect(bullet.source, content="> - First")
  inspect(bullet.caret, content="6")

  let task = markdown_editor_apply_command_at(
    "> First",
    TaskList,
    Some({ caret: 7, selection: None }),
  )
  inspect(task.source, content="> - [ ] First")
  inspect(task.caret, content="13")

  let ordered = markdown_editor_apply_command_at(
    "> First",
    OrderedList,
    Some({ caret: 7, selection: None }),
  )
  inspect(ordered.source, content="> 1. First")
  inspect(ordered.caret, content="10")

  let nested = markdown_editor_apply_command_at(
    "> > First",
    BulletList,
    Some({ caret: 9, selection: None }),
  )
  inspect(nested.source, content="> > - First")
  inspect(nested.caret, content="11")

  let toggled = markdown_editor_apply_command_at(
    "> - First",
    BulletList,
    Some({ caret: 9, selection: None }),
  )
  inspect(toggled.source, content="> First")
  inspect(toggled.caret, content="7")

  let replaced = markdown_editor_apply_command_at(
    "> - First",
    OrderedList,
    Some({ caret: 9, selection: None }),
  )
  inspect(replaced.source, content="> 1. First")
  inspect(replaced.caret, content="10")

  let heading = markdown_editor_apply_command_at(
    "> First",
    Heading(2),
    Some({ caret: 7, selection: None }),
  )
  inspect(heading.source, content="> ## First")
  inspect(heading.caret, content="10")

  let heading_toggle = markdown_editor_apply_command_at(
    "> ## First",
    Heading(2),
    Some({ caret: 10, selection: None }),
  )
  inspect(heading_toggle.source, content="> First")
  inspect(heading_toggle.caret, content="7")

  let heading_level = markdown_editor_apply_command_at(
    "> ## First",
    Heading(3),
    Some({ caret: 10, selection: None }),
  )
  inspect(heading_level.source, content="> ### First")
  inspect(heading_level.caret, content="11")

  let nested_heading = markdown_editor_apply_command_at(
    "> > First",
    Heading(1),
    Some({ caret: 9, selection: None }),
  )
  inspect(nested_heading.source, content="> > # First")
  inspect(nested_heading.caret, content="11")
}

///|
test "markdown editor block command toggles same marker off" {
  let heading = markdown_editor_apply_command_at(
    "## Title",
    Heading(2),
    Some({ caret: 4, selection: None }),
  )
  inspect(heading.source, content="Title")
  inspect(heading.caret, content="1")
  let quote = markdown_editor_apply_command_at(
    "> Quote",
    Quote,
    Some({ caret: 4, selection: None }),
  )
  inspect(quote.source, content="Quote")
  inspect(quote.caret, content="2")
}

///|
test "markdown editor paragraph command strips block markers" {
  let heading = markdown_editor_apply_command_at(
    "# Title",
    Paragraph,
    Some({ caret: 4, selection: None }),
  )
  inspect(heading.source, content="Title")
  inspect(heading.caret, content="2")
  let nested = markdown_editor_apply_command_at(
    "  - child",
    Paragraph,
    Some({ caret: 6, selection: None }),
  )
  inspect(nested.source, content="child")
  inspect(nested.caret, content="2")
  let quoted_bullet = markdown_editor_apply_command_at(
    "> - First",
    Paragraph,
    Some({ caret: 9, selection: None }),
  )
  inspect(quoted_bullet.source, content="> First")
  inspect(quoted_bullet.caret, content="7")
  let quoted_ordered = markdown_editor_apply_command_at(
    "> 3. First",
    Paragraph,
    Some({ caret: 10, selection: None }),
  )
  inspect(quoted_ordered.source, content="> First")
  inspect(quoted_ordered.caret, content="7")
  let quoted_heading = markdown_editor_apply_command_at(
    "> # Title",
    Paragraph,
    Some({ caret: 9, selection: None }),
  )
  inspect(quoted_heading.source, content="> Title")
  inspect(quoted_heading.caret, content="7")
  let nested_quoted = markdown_editor_apply_command_at(
    "> > - First",
    Paragraph,
    Some({ caret: 11, selection: None }),
  )
  inspect(nested_quoted.source, content="> > First")
  inspect(nested_quoted.caret, content="9")
  let lines = markdown_editor_apply_command_at(
    "- one\n> two\n3. three",
    Paragraph,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=0, end=20)) }),
  )
  inspect(lines.source, content="one\ntwo\nthree")
  let quoted_lines_source = "Intro\n> - First\n> 9. Second\n> # Third\nTail"
  let quoted_lines_end = markdown_editor_text_length(
    "Intro\n> - First\n> 9. Second\n> # Third",
  )
  let quoted_lines = markdown_editor_apply_command_at(
    quoted_lines_source,
    Paragraph,
    Some({
      caret: quoted_lines_end,
      selection: Some(@core.TextRange::new(start=6, end=quoted_lines_end)),
    }),
  )
  inspect(
    quoted_lines.source,
    content="Intro\n> First\n> Second\n> Third\nTail",
  )
}

///|
test "markdown editor block command transforms setext heading blocks" {
  let paragraph = markdown_editor_apply_command_at(
    "Intro\nTitle\n---\nTail",
    Paragraph,
    Some({ caret: 8, selection: None }),
  )
  inspect(paragraph.source, content="Intro\nTitle\nTail")
  inspect(paragraph.caret, content="8")
  let heading = markdown_editor_apply_command_at(
    "Intro\nTitle\n---\nTail",
    Heading(3),
    Some({ caret: 8, selection: None }),
  )
  inspect(heading.source, content="Intro\n### Title\nTail")
  inspect(heading.caret, content="12")
  let quote = markdown_editor_apply_command_at(
    "Intro\nTitle\n=====\nTail",
    Quote,
    Some({ caret: 8, selection: None }),
  )
  inspect(quote.source, content="Intro\n> Title\nTail")
}

///|
test "markdown editor reports active block label" {
  let source = "# Title\n- item\n> quote\n```\ncode\n```"
  inspect(
    markdown_editor_active_block_label(source, { caret: 3, selection: None }),
    content="Heading 1",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 10, selection: None }),
    content="Bullet list",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 18, selection: None }),
    content="Quote",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 29, selection: None }),
    content="Code block",
  )
  inspect(
    markdown_editor_active_block_label("# Title\nBody", {
      caret: 7,
      selection: None,
    }),
    content="Heading 1",
  )
  inspect(
    markdown_editor_active_block_label("- item\nBody", {
      caret: 6,
      selection: None,
    }),
    content="Bullet list",
  )
}

///|
test "markdown editor app block command uses tracked caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nTitle")
  app.set_selection(8, None)
  app.apply_command_to_selection(Quote)
  inspect(app.document(), content="Intro\n> Title")
}

///|
test "markdown editor block command transforms selected lines" {
  let bullet = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    BulletList,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(bullet.source, content="Intro\n- First\n- Second\nTail")
  guard bullet.selection is Some(bullet_selection) else {
    fail("expected transformed bullet selection")
  }
  inspect(bullet_selection.start, content="6")
  inspect(bullet_selection.end, content="22")
  let ordered = markdown_editor_apply_command_at(
    "Intro\n- First\n- Second\nTail",
    OrderedList,
    Some({ caret: 22, selection: Some(@core.TextRange::new(start=6, end=22)) }),
  )
  inspect(ordered.source, content="Intro\n1. First\n2. Second\nTail")
  let quote = markdown_editor_apply_command_at(
    "Intro\n1. First\n2. Second\nTail",
    Quote,
    Some({ caret: 24, selection: Some(@core.TextRange::new(start=6, end=24)) }),
  )
  inspect(quote.source, content="Intro\n> First\n> Second\nTail")
  let rule = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    HorizontalRule,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(rule.source, content="Intro\n---\nTail")
  guard rule.selection is Some(rule_selection) else {
    fail("expected rule selection")
  }
  inspect(rule_selection.start, content="6")
  inspect(rule_selection.end, content="9")
  let table = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    Table,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(
    table.source,
    content="Intro\n| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |\nTail",
  )
  inspect(table.caret, content="8")
}

///|
test "markdown editor selected list commands preserve blank separator lines" {
  let bullet = markdown_editor_apply_command_at(
    "Intro\nFirst\n\nSecond\nTail",
    BulletList,
    Some({ caret: 19, selection: Some(@core.TextRange::new(start=6, end=19)) }),
  )
  inspect(bullet.source, content="Intro\n- First\n\n- Second\nTail")
  inspect(bullet.caret, content="23")
  guard bullet.selection is Some(bullet_selection) else {
    fail("expected bullet selection")
  }
  inspect(bullet_selection.start, content="6")
  inspect(bullet_selection.end, content="23")

  let task = markdown_editor_apply_command_at(
    "Intro\nFirst\n\nSecond\nTail",
    TaskList,
    Some({ caret: 19, selection: Some(@core.TextRange::new(start=6, end=19)) }),
  )
  inspect(task.source, content="Intro\n- [ ] First\n\n- [ ] Second\nTail")
  inspect(task.caret, content="31")

  let ordered = markdown_editor_apply_command_at(
    "Intro\nFirst\n\nSecond\nTail",
    OrderedList,
    Some({ caret: 19, selection: Some(@core.TextRange::new(start=6, end=19)) }),
  )
  inspect(ordered.source, content="Intro\n1. First\n\n2. Second\nTail")
  inspect(ordered.caret, content="25")

  let quote = markdown_editor_apply_command_at(
    "Intro\nFirst\n\nSecond\nTail",
    Quote,
    Some({ caret: 19, selection: Some(@core.TextRange::new(start=6, end=19)) }),
  )
  inspect(quote.source, content="Intro\n> First\n> \n> Second\nTail")
}

///|
test "markdown editor selected list commands preserve nested indentation" {
  let source = "Intro\nParent\n  Child\n  More\nTail"
  let selection_end = markdown_editor_text_length(
    "Intro\nParent\n  Child\n  More",
  )
  let selected = Some({
    caret: selection_end,
    selection: Some(@core.TextRange::new(start=6, end=selection_end)),
  })
  let bullet = markdown_editor_apply_command_at(source, BulletList, selected)
  inspect(bullet.source, content="Intro\n- Parent\n  - Child\n  - More\nTail")
  let task = markdown_editor_apply_command_at(source, TaskList, selected)
  inspect(
    task.source,
    content="Intro\n- [ ] Parent\n  - [ ] Child\n  - [ ] More\nTail",
  )
  let ordered = markdown_editor_apply_command_at(source, OrderedList, selected)
  inspect(
    ordered.source,
    content="Intro\n1. Parent\n  1. Child\n  2. More\nTail",
  )
  let quote = markdown_editor_apply_command_at(source, Quote, selected)
  inspect(quote.source, content="Intro\n> Parent\n  > Child\n  > More\nTail")

  let marked_source = "Intro\n- Parent\n  - Child\nTail"
  let marked_end = markdown_editor_text_length("Intro\n- Parent\n  - Child")
  let marked = markdown_editor_apply_command_at(
    marked_source,
    TaskList,
    Some({
      caret: marked_end,
      selection: Some(@core.TextRange::new(start=6, end=marked_end)),
    }),
  )
  inspect(marked.source, content="Intro\n- [ ] Parent\n  - [ ] Child\nTail")
}

///|
test "markdown editor selected list commands preserve quote context" {
  let source = "Intro\n> First\n> Second\nTail"
  let selection_end = markdown_editor_text_length("Intro\n> First\n> Second")
  let selected = Some({
    caret: selection_end,
    selection: Some(@core.TextRange::new(start=6, end=selection_end)),
  })
  let bullet = markdown_editor_apply_command_at(source, BulletList, selected)
  inspect(bullet.source, content="Intro\n> - First\n> - Second\nTail")
  guard bullet.selection is Some(bullet_selection) else {
    fail("expected quoted bullet selection")
  }
  inspect(bullet_selection.start, content="6")
  inspect(bullet_selection.end, content="26")

  let task = markdown_editor_apply_command_at(source, TaskList, selected)
  inspect(task.source, content="Intro\n> - [ ] First\n> - [ ] Second\nTail")

  let ordered = markdown_editor_apply_command_at(source, OrderedList, selected)
  inspect(ordered.source, content="Intro\n> 1. First\n> 2. Second\nTail")

  let nested_source = "Intro\n> First\n> > Nested\n> Second\nTail"
  let nested_end = markdown_editor_text_length(
    "Intro\n> First\n> > Nested\n> Second",
  )
  let nested_ordered = markdown_editor_apply_command_at(
    nested_source,
    OrderedList,
    Some({
      caret: nested_end,
      selection: Some(@core.TextRange::new(start=6, end=nested_end)),
    }),
  )
  inspect(
    nested_ordered.source,
    content="Intro\n> 1. First\n> > 1. Nested\n> 2. Second\nTail",
  )

  let marked_source = "Intro\n> - First\n> 9. Second\nTail"
  let marked_end = markdown_editor_text_length("Intro\n> - First\n> 9. Second")
  let marked = markdown_editor_apply_command_at(
    marked_source,
    OrderedList,
    Some({
      caret: marked_end,
      selection: Some(@core.TextRange::new(start=6, end=marked_end)),
    }),
  )
  inspect(marked.source, content="Intro\n> 1. First\n> 2. Second\nTail")

  let blank_source = "Intro\n> First\n> \n> Second\nTail"
  let blank_end = markdown_editor_text_length("Intro\n> First\n> \n> Second")
  let blank = markdown_editor_apply_command_at(
    blank_source,
    BulletList,
    Some({
      caret: blank_end,
      selection: Some(@core.TextRange::new(start=6, end=blank_end)),
    }),
  )
  inspect(blank.source, content="Intro\n> - First\n> \n> - Second\nTail")

  let quote = markdown_editor_apply_command_at(source, Quote, selected)
  inspect(quote.source, content=source)
}

///|
test "markdown editor block commands renumber ordered list context" {
  let converted = markdown_editor_apply_command_at(
    "1. first\nsecond\n9. third",
    OrderedList,
    Some({ caret: 15, selection: Some(@core.TextRange::new(start=9, end=15)) }),
  )
  inspect(converted.source, content="1. first\n2. second\n3. third")
  guard converted.selection is Some(converted_selection) else {
    fail("expected converted ordered line selection")
  }
  inspect(converted_selection.start, content="10")
  inspect(converted_selection.end, content="18")
  let unlisted = markdown_editor_apply_command_at(
    "1. first\n2. second\n3. third",
    Paragraph,
    Some({ caret: 15, selection: Some(@core.TextRange::new(start=9, end=18)) }),
  )
  inspect(unlisted.source, content="1. first\nsecond\n3. third")
}

///|
test "markdown editor app block command uses tracked multi-line selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nFirst\nSecond")
  app.set_selection(18, Some(@core.TextRange::new(start=6, end=18)))
  app.apply_command_to_selection(TaskList)
  inspect(app.document(), content="Intro\n- [ ] First\n- [ ] Second")
}

///|
test "markdown editor app command renumbers ordered list context" {
  let app = MarkdownEditorApp::new()
  app.set_document("1. first\nsecond\n9. third")
  app.set_selection(15, Some(@core.TextRange::new(start=9, end=15)))
  app.apply_command_to_selection(OrderedList)
  inspect(app.document(), content="1. first\n2. second\n3. third")
}

///|
test "markdown editor code block wraps current line and selected lines" {
  let current = markdown_editor_apply_command_at(
    "Intro\nlet x = 1\nTail",
    CodeBlock,
    Some({ caret: 8, selection: None }),
  )
  inspect(current.source, content="Intro\n```\nlet x = 1\n```\nTail")
  inspect(current.caret, content="12")
  let selected = markdown_editor_apply_command_at(
    "Intro\nlet x = 1\nlet y = 2\nTail",
    CodeBlock,
    Some({ caret: 25, selection: Some(@core.TextRange::new(start=6, end=25)) }),
  )
  inspect(
    selected.source,
    content="Intro\n```\nlet x = 1\nlet y = 2\n```\nTail",
  )
  guard selected.selection is Some(selection) else {
    fail("expected selected code content")
  }
  inspect(selection.start, content="10")
  inspect(selection.end, content="29")

  let quoted_current = markdown_editor_apply_command_at(
    "> let x = 1",
    CodeBlock,
    Some({ caret: 4, selection: None }),
  )
  inspect(quoted_current.source, content="> ```\n> let x = 1\n> ```")
  inspect(quoted_current.caret, content="10")

  let quoted_source = "Intro\n> let x = 1\n> let y = 2\nTail"
  let quoted_end = markdown_editor_text_length(
    "Intro\n> let x = 1\n> let y = 2",
  )
  let quoted_selected = markdown_editor_apply_command_at(
    quoted_source,
    CodeBlock,
    Some({
      caret: quoted_end,
      selection: Some(@core.TextRange::new(start=6, end=quoted_end)),
    }),
  )
  inspect(
    quoted_selected.source,
    content="Intro\n> ```\n> let x = 1\n> let y = 2\n> ```\nTail",
  )
  guard quoted_selected.selection is Some(quoted_selection) else {
    fail("expected selected quoted code content")
  }
  inspect(quoted_selection.start, content="12")
  inspect(quoted_selection.end, content="35")
}

///|
test "markdown editor code block unwraps containing fenced block" {
  let result = markdown_editor_apply_command_at(
    "Intro\n```\nlet x = 1\n```\nTail",
    CodeBlock,
    Some({ caret: 12, selection: None }),
  )
  inspect(result.source, content="Intro\nlet x = 1\nTail")
  inspect(result.caret, content="8")
  let tagged = markdown_editor_apply_command_at(
    "Intro\n```moonbit\nlet x = 1\n```\nTail",
    CodeBlock,
    Some({ caret: 20, selection: None }),
  )
  inspect(tagged.source, content="Intro\nlet x = 1\nTail")
  inspect(tagged.caret, content="9")
  let quoted = markdown_editor_apply_command_at(
    "> ```\n> let x = 1\n> ```",
    CodeBlock,
    Some({ caret: 10, selection: None }),
  )
  inspect(quoted.source, content="> let x = 1")
  inspect(quoted.caret, content="4")
  let quoted_selection_source = "Intro\n> ```\n> let x = 1\n> let y = 2\n> ```\nTail"
  let quoted_selection_end = markdown_editor_text_length(
    "Intro\n> ```\n> let x = 1\n> let y = 2",
  )
  let quoted_selected = markdown_editor_apply_command_at(
    quoted_selection_source,
    CodeBlock,
    Some({
      caret: quoted_selection_end,
      selection: Some(@core.TextRange::new(start=12, end=quoted_selection_end)),
    }),
  )
  inspect(
    quoted_selected.source,
    content="Intro\n> let x = 1\n> let y = 2\nTail",
  )
  inspect(quoted_selected.caret, content="29")
  guard quoted_selected.selection is Some(quoted_selection) else {
    fail("expected unwrapped quoted code selection")
  }
  inspect(quoted_selection.start, content="6")
  inspect(quoted_selection.end, content="29")
  let nested_quoted = markdown_editor_apply_command_at(
    "> > ```\n> > code\n> > ```",
    CodeBlock,
    Some({ caret: 12, selection: None }),
  )
  inspect(nested_quoted.source, content="> > code")
  inspect(nested_quoted.caret, content="4")
}

///|
test "markdown editor block command appends snippet without caret context" {
  let result = markdown_editor_apply_command_at("Base", Heading(1), None)
  inspect(result.source, content="Base\n\n# Heading")
}

///|
test "markdown editor command duplicates current block" {
  let source = "Alpha\nBeta\nGamma"
  let result = markdown_editor_apply_command_at(
    source,
    DuplicateBlock,
    Some({ caret: 8, selection: None }),
  )
  inspect(result.source, content="Alpha\nBeta\nBeta\nGamma")
  inspect(result.caret, content="13")
  let selected = markdown_editor_apply_command_at(
    source,
    DuplicateBlock,
    Some({ caret: 10, selection: Some(@core.TextRange::new(start=6, end=10)) }),
  )
  inspect(selected.source, content="Alpha\nBeta\nBeta\nGamma")
  inspect(selected.caret, content="15")
  guard selected.selection is Some(selection) else {
    fail("expected duplicated selection")
  }
  inspect(selection.start, content="11")
  inspect(selection.end, content="15")
}

///|
test "markdown editor command duplicates multiline fenced block" {
  let source = "Intro\n```moonbit\nlet x = 1\n```\nTail"
  let result = markdown_editor_apply_command_at(
    source,
    DuplicateBlock,
    Some({ caret: 20, selection: None }),
  )
  inspect(
    result.source,
    content="Intro\n```moonbit\nlet x = 1\n```\n```moonbit\nlet x = 1\n```\nTail",
  )
  inspect(result.caret, content="45")
}

///|
test "markdown editor command duplicates selected block ranges" {
  let source = "Alpha\nBeta\nGamma"
  let result = markdown_editor_apply_command_at(
    source,
    DuplicateBlock,
    Some({ caret: 8, selection: Some(@core.TextRange::new(start=1, end=10)) }),
  )
  inspect(result.source, content="Alpha\nBeta\nAlpha\nBeta\nGamma")
  inspect(result.caret, content="19")
  guard result.selection is Some(selection) else {
    fail("expected duplicated block range selection")
  }
  inspect(selection.start, content="12")
  inspect(selection.end, content="21")
}

///|
test "markdown editor command moves current block up and down" {
  let source = "Alpha\nBeta\nGamma"
  let moved_up = markdown_editor_apply_command_at(
    source,
    MoveBlockUp,
    Some({ caret: 8, selection: None }),
  )
  inspect(moved_up.source, content="Beta\nAlpha\nGamma")
  inspect(moved_up.caret, content="2")
  let moved_down = markdown_editor_apply_command_at(
    source,
    MoveBlockDown,
    Some({ caret: 8, selection: None }),
  )
  inspect(moved_down.source, content="Alpha\nGamma\nBeta")
  inspect(moved_down.caret, content="14")
}

///|
test "markdown editor command moves selected block ranges as a group" {
  let down = markdown_editor_apply_command_at(
    "Alpha\nBeta\nGamma",
    MoveBlockDown,
    Some({ caret: 8, selection: Some(@core.TextRange::new(start=1, end=10)) }),
  )
  inspect(down.source, content="Gamma\nAlpha\nBeta")
  inspect(down.caret, content="14")
  guard down.selection is Some(down_selection) else {
    fail("expected moved block range selection")
  }
  inspect(down_selection.start, content="7")
  inspect(down_selection.end, content="16")

  let up = markdown_editor_apply_command_at(
    "Intro\nAlpha\nBeta\nGamma",
    MoveBlockUp,
    Some({ caret: 14, selection: Some(@core.TextRange::new(start=7, end=16)) }),
  )
  inspect(up.source, content="Alpha\nBeta\nIntro\nGamma")
  inspect(up.caret, content="8")
  guard up.selection is Some(up_selection) else {
    fail("expected moved block range selection")
  }
  inspect(up_selection.start, content="1")
  inspect(up_selection.end, content="10")
}

///|
test "markdown editor command moves blocks across blank separators" {
  let moved_up = markdown_editor_apply_command_at(
    "Alpha\n\nBeta",
    MoveBlockUp,
    Some({ caret: 8, selection: None }),
  )
  inspect(moved_up.source, content="Beta\n\nAlpha")
  inspect(moved_up.caret, content="1")
  let moved_down = markdown_editor_apply_command_at(
    "Alpha\n\nBeta",
    MoveBlockDown,
    Some({ caret: 1, selection: None }),
  )
  inspect(moved_down.source, content="Beta\n\nAlpha")
  inspect(moved_down.caret, content="7")
}

///|
test "markdown editor command moves selected block ranges across blank separators" {
  let moved_down = markdown_editor_apply_command_at(
    "Intro\n\nAlpha\n\nBeta\n\nTail",
    MoveBlockDown,
    Some({ caret: 16, selection: Some(@core.TextRange::new(start=8, end=18)) }),
  )
  inspect(moved_down.source, content="Intro\n\nTail\n\nAlpha\n\nBeta")
  inspect(moved_down.caret, content="22")
  guard moved_down.selection is Some(selection) else {
    fail("expected moved block range selection across blank separators")
  }
  inspect(selection.start, content="14")
  inspect(selection.end, content="24")
}

///|
test "markdown editor block move no-ops at document edges" {
  let source = "Alpha\nBeta"
  let first = markdown_editor_apply_command_at(
    source,
    MoveBlockUp,
    Some({ caret: 1, selection: None }),
  )
  inspect(first.source, content=source)
  inspect(first.caret, content="1")
  let last = markdown_editor_apply_command_at(
    source,
    MoveBlockDown,
    Some({ caret: 8, selection: None }),
  )
  inspect(last.source, content=source)
  inspect(last.caret, content="8")
}

///|
test "markdown editor enter completes pipe table header" {
  let completed = markdown_editor_transform_input("Name | Done", 11, None, "\n").unwrap()
  inspect(completed.text, content="Name | Done\n| --- | --- |\n|  |  |")
  inspect(completed.caret, content="28")
  let placeholder = markdown_editor_transform_input(
    "| Name | |",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(placeholder.text, content="| Name | |\n| --- | --- |\n|  |  |")
  inspect(placeholder.caret, content="27")
  inspect(
    markdown_editor_transform_input("Name | ", 7, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor enter inserts table row below current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_transform_input(source, 30, None, "\n").unwrap()
  inspect(inserted.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(inserted.caret, content="39")
  let middle = markdown_editor_transform_input(source, 26, None, "\n").unwrap()
  inspect(middle.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(middle.caret, content="36")
  let header = markdown_editor_transform_input(source, 6, None, "\n").unwrap()
  inspect(header.text, content="| A | B |\n| --- | --- |\n|  |  |\n| 1 | 2 |")
  inspect(header.caret, content="29")
}

///|
test "markdown editor command inserts table row below current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  inspect(inserted.caret, content="39")
  let header = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 6, selection: None }),
  )
  inspect(header.source, content="| A | B |\n| --- | --- |\n|  |  |\n| 1 | 2 |")
  inspect(header.caret, content="29")
}

///|
test "markdown editor command inserts table column after current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 30, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
  inspect(inserted.caret, content="35")
  let middle = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 26, selection: None }),
  )
  inspect(
    middle.source,
    content="| A |  | B |\n| --- | --- | --- |\n| 1 |  | 2 |",
  )
  inspect(middle.caret, content="31")
}

///|
test "markdown editor table column edits preserve alignment markers" {
  let source = "| A | B | C |\n| :--- | :---: | ---: |\n| 1 | 2 | 3 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 44, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |  | C |\n| :--- | :---: | --- | ---: |\n| 1 | 2 |  | 3 |",
  )
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableColumn,
    Some({ caret: 44, selection: None }),
  )
  inspect(deleted.source, content="| A | C |\n| :--- | ---: |\n| 1 | 3 |")
}

///|
test "markdown editor command sets table column alignment" {
  let source = "| A | B | C |\n| --- | :---: | ---: |\n| 1 | 2 | 3 |"
  let centered = markdown_editor_apply_command_at(
    source,
    SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
    Some({ caret: 48, selection: None }),
  )
  inspect(
    centered.source,
    content="| A | B | C |\n| --- | :---: | :---: |\n| 1 | 2 | 3 |",
  )
  inspect(centered.caret, content="47")
  let auto = markdown_editor_apply_command_at(
    centered.source,
    SetTableColumnAlignment(None),
    Some({ caret: 48, selection: None }),
  )
  inspect(
    auto.source,
    content="| A | B | C |\n| --- | :---: | --- |\n| 1 | 2 | 3 |",
  )
  let snapshot = MarkdownEditorSnapshot::parse(auto.source)
  guard snapshot.rich_text.blocks[0].table is Some(table) else {
    fail("expected table preview")
  }
  guard table.rows[0][1].align is Some(@core.TextAlign::TextCenter) else {
    fail("expected center alignment to remain")
  }
  guard table.rows[0][2].align is None else {
    fail("expected cleared alignment")
  }
  let plain = markdown_editor_apply_command_at(
    "Plain text",
    SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)),
    Some({ caret: 5, selection: None }),
  )
  inspect(plain.source, content="Plain text")
  inspect(plain.caret, content="5")
  let selected = markdown_editor_apply_command_at(
    "Plain text",
    SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
    Some({ caret: 5, selection: Some(@core.TextRange::new(start=0, end=5)) }),
  )
  inspect(selected.source, content="Plain text")
}

///|
test "markdown editor app action sets table column alignment" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-align-right")
  inspect(app.document(), content="| A | B |\n| --- | ---: |\n| 1 | 2 |")
  app.apply_action("table-align-auto")
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 1 | 2 |")
}

///|
test "markdown editor table row and column commands no-op outside tables" {
  let source = "Plain text"
  let row = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 5, selection: None }),
  )
  inspect(row.source, content=source)
  inspect(row.caret, content="5")
  let column = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 5, selection: None }),
  )
  inspect(column.source, content=source)
  inspect(column.caret, content="5")
  let delete_row = markdown_editor_apply_command_at(
    source,
    DeleteTableRow,
    Some({ caret: 5, selection: None }),
  )
  inspect(delete_row.source, content=source)
  inspect(delete_row.caret, content="5")
  let delete_column = markdown_editor_apply_command_at(
    source,
    DeleteTableColumn,
    Some({ caret: 5, selection: None }),
  )
  inspect(delete_column.source, content=source)
  inspect(delete_column.caret, content="5")

  let selected = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 5, selection: Some(@core.TextRange::new(start=0, end=5)) }),
  )
  inspect(selected.source, content=source)
  guard selected.selection is Some(selection) else {
    fail("expected unchanged selection")
  }
  inspect(selection.start, content="0")
  inspect(selection.end, content="5")

  let without_context = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    None,
  )
  inspect(without_context.source, content=source)
  inspect(without_context.caret, content="10")
}

///|
test "markdown editor command deletes current table row" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |"
  let cleared_header = markdown_editor_apply_command_at(
    source,
    DeleteTableRow,
    Some({ caret: 6, selection: None }),
  )
  inspect(
    cleared_header.source,
    content="|  |  |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |",
  )
  inspect(cleared_header.caret, content="2")
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(deleted.source, content="| A | B |\n| --- | --- |\n| 3 | 4 |")
  inspect(deleted.caret, content="23")
  let cleared = markdown_editor_apply_command_at(
    "| A | B |\n| --- | --- |\n| 1 | 2 |",
    DeleteTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(cleared.source, content="| A | B |\n| --- | --- |\n|  |  |")
  inspect(cleared.caret, content="26")
}

///|
test "markdown editor command deletes current table column" {
  let source = "| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |"
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableColumn,
    Some({ caret: 40, selection: None }),
  )
  inspect(deleted.source, content="| A | C |\n| --- | --- |\n| 1 | 3 |")
  inspect(deleted.caret, content="2")
  let cleared = markdown_editor_apply_command_at(
    "| A |\n| --- |\n| 1 |",
    DeleteTableColumn,
    Some({ caret: 16, selection: None }),
  )
  inspect(cleared.source, content="|  |\n| --- |\n|  |")
  inspect(cleared.caret, content="3")
}

///|
