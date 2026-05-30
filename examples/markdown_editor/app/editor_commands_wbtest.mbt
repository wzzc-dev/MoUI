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
test "markdown editor app toggles task checkbox by prefix offset" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  app.toggle_task_at(6)
  inspect(app.document(), content="- [x] todo")
  app.toggle_task_at(6)
  inspect(app.document(), content="- [ ] todo")
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
  let lines = markdown_editor_apply_command_at(
    "- one\n> two\n3. three",
    Paragraph,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=0, end=20)) }),
  )
  inspect(lines.source, content="one\ntwo\nthree")
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
}

///|
test "markdown editor block command appends snippet without caret context" {
  let result = markdown_editor_apply_command_at("Base", Heading(1), None)
  inspect(result.source, content="Base\n\n# Heading")
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
test "markdown editor command deletes current table row" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |"
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
