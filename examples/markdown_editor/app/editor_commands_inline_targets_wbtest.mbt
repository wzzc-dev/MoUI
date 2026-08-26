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
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(updated.source, content="Visit [MoUI](https://wzzc-dev.github.io/MoUI) today")
  guard updated.selection is Some(selection) else {
    fail("expected updated link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
  let wrapped = markdown_editor_apply_command_at(
    "Visit MoUI today",
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 10, selection: Some(@core.TextRange::new(start=6, end=10)) }),
  )
  inspect(wrapped.source, content="Visit [MoUI](https://wzzc-dev.github.io/MoUI) today")
}

///|
test "markdown editor link target command updates target at caret" {
  let inline = markdown_editor_apply_command_at(
    "Visit [MoUI](https://old.example) today",
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 9, selection: None }),
  )
  inspect(inline.source, content="Visit [MoUI](https://wzzc-dev.github.io/MoUI) today")
  guard inline.selection is Some(inline_selection) else {
    fail("expected inline link text selection")
  }
  inspect(inline_selection.start, content="7")
  inspect(inline_selection.end, content="11")

  let reference = markdown_editor_apply_command_at(
    "Visit [MoUI][site] today\n\n[site]: https://old.example",
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 9, selection: None }),
  )
  inspect(
    reference.source,
    content="Visit [MoUI][site] today\n\n[site]: https://wzzc-dev.github.io/MoUI",
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
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 54, selection: Some(@core.TextRange::new(start=35, end=54)) }),
  )
  inspect(
    updated_url.source,
    content="Mail <hello@example.dev> or visit <https://wzzc-dev.github.io/MoUI>",
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
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI][site] today\n\n[site]: https://wzzc-dev.github.io/MoUI",
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
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI][site] today\n\n[site]: https://wzzc-dev.github.io/MoUI",
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
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI] today\n\n[MoUI]: https://wzzc-dev.github.io/MoUI",
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
    SetLinkTarget("https://wzzc-dev.github.io/MoUI"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI] today\n\n[MoUI]: https://wzzc-dev.github.io/MoUI",
  )
  guard updated.selection is Some(selection) else {
    fail("expected shortcut reference link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor reads selected link and image targets" {
  let source = "Visit [MoUI](https://wzzc-dev.github.io/MoUI) and ![logo](assets/logo.png)"
  guard markdown_editor_selected_link_target(source, {
      caret: 11,
      selection: Some(@core.TextRange::new(start=7, end=11)),
    })
    is Some("https://wzzc-dev.github.io/MoUI") else {
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

  let unicode_wrapped = markdown_editor_transform_input(
    "前缀 🤣 note here",
    9,
    Some(@core.TextRange::new(start=5, end=9)),
    "[^u]: 脚注",
  ).unwrap()
  inspect(
    unicode_wrapped.text,
    content="前缀 🤣 note[^u] here\n\n[^u]: 脚注",
  )
  inspect(unicode_wrapped.caret, content="9")
  guard unicode_wrapped.selection is Some(unicode_selection) else {
    fail("expected selected unicode footnote source text")
  }
  inspect(unicode_selection.start, content="5")
  inspect(unicode_selection.end, content="9")

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
  guard @moui_richtext.markdown_editor_selected_html_block_text(source, {
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
