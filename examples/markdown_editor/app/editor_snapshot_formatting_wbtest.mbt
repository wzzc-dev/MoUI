///|
test "markdown editor formatter emits source ranges for visual mapping" {
  let document = markdown_editor_format("# Title\n- [ ] task")
  inspect(document.blocks.length(), content="2")
  guard document.blocks[0]
    is {
      source_range: Some({ start: 0, end: 7 }),
      content_range: Some({ start: 2, end: 7 }),
      runs: [{ source_range: Some({ start: 2, end: 7 }), .. }],
      ..,
    } else {
    fail("expected heading source ranges")
  }
  guard document.blocks[1]
    is {
      source_range: Some({ start: 8, end: 18 }),
      content_range: Some({ start: 14, end: 18 }),
      runs: [{ source_range: Some({ start: 14, end: 18 }), .. }],
      ..,
    } else {
    fail("expected task source ranges")
  }
  let nested = markdown_editor_format("  - [x] nested")
  guard nested.blocks[0]
    is {
      content_range: Some({ start: 8, end: 14 }),
      runs: [{ source_range: Some({ start: 8, end: 14 }), .. }],
      ..,
    } else {
    fail("expected nested task source ranges")
  }
}

///|
test "markdown editor formatter reveals active block markers" {
  let heading = markdown_editor_format_for_selection("# Title\n- [ ] task", {
    caret: 4,
    selection: None,
  })
  guard heading.blocks[0]
    is {
      prefix: "",
      runs: [
        {
          text: "# Title",
          visual_text: None,
          source_range: Some({ start: 0, end: 7 }),
          ..,
        },
      ],
      ..,
    } else {
    fail("expected active heading marker to reveal")
  }
  guard heading.blocks[1]
    is {
      prefix: _,
      runs: [{ text: "task", source_range: Some({ start: 14, end: 18 }), .. }],
      ..,
    } else {
    fail("expected inactive task marker to stay hidden")
  }
  let task = markdown_editor_format_for_selection("# Title\n- [ ] task", {
    caret: 16,
    selection: None,
  })
  guard task.blocks[1]
    is {
      prefix: "- [ ] ",
      runs: [{ text: "task", source_range: Some({ start: 14, end: 18 }), .. }],
      ..,
    } else {
    fail("expected active task marker to reveal")
  }
  let marker_caret = markdown_editor_format_for_selection(
    "# Title\n- [ ] task",
    { caret: 9, selection: None },
  )
  guard marker_caret.blocks[1]
    is {
      runs: [{ text: "task", source_range: Some({ start: 14, end: 18 }), .. }],
      ..,
    } else {
    fail("expected marker-only caret to keep task prefix clickable")
  }
  let code = markdown_editor_format_for_selection(
    "```moonbit\nlet saved = markdown\n```",
    { caret: 15, selection: None },
  )
  guard code.blocks[0].content_range is Some(range) else {
    fail("expected active code block source range")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="35")
  inspect(code.blocks[0].runs.length(), content="1")
  inspect(
    code.blocks[0].runs[0].text,
    content="```moonbit\nlet saved = markdown\n```",
  )
  guard code.blocks[0].runs[0].source_range is Some(run_range) else {
    fail("expected active code block run source range")
  }
  inspect(run_range.start, content="0")
  inspect(run_range.end, content="35")
}

///|
test "markdown editor formatter reveals active quote and ordered markers" {
  let document = markdown_editor_format_for_selection("> quote\n12. item", {
    caret: 3,
    selection: None,
  })
  guard document.blocks[0]
    is {
      prefix: "",
      runs: [
        {
          text: "> quote",
          visual_text: None,
          source_range: Some({ start: 0, end: 7 }),
          ..,
        },
      ],
      ..,
    } else {
    fail("expected active quote marker to reveal")
  }
  let ordered = markdown_editor_format_for_selection("> quote\n12. item", {
    caret: 12,
    selection: None,
  })
  guard ordered.blocks[1]
    is {
      prefix: "12. ",
      runs: [{ text: "item", source_range: Some({ start: 12, end: 16 }), .. }],
      ..,
    } else {
    fail("expected active ordered marker to reveal")
  }
  let paren_ordered = markdown_editor_format_for_selection("3) third", {
    caret: 4,
    selection: None,
  })
  guard paren_ordered.blocks[0]
    is {
      prefix: "3) ",
      runs: [{ text: "third", source_range: Some({ start: 3, end: 8 }), .. }],
      content_range: Some({ start: 3, end: 8 }),
      ..,
    } else {
    fail("expected active paren ordered marker to reveal")
  }
}

///|
test "markdown editor formatter maps inline spans past hidden markers" {
  let document = markdown_editor_format("Text **bold** and `code`")
  inspect(document.blocks.length(), content="1")
  guard document.blocks[0].runs
    is [
      { text: "Text ", source_range: Some({ start: 0, end: 5 }), .. },
      { text: "bold", source_range: Some({ start: 7, end: 11 }), .. },
      { text: " and ", source_range: Some({ start: 13, end: 18 }), .. },
      { text: "code", source_range: Some({ start: 19, end: 23 }), .. },
    ] else {
    fail("expected inline source ranges to skip markdown delimiters")
  }
}

///|
test "markdown editor formatter reveals active inline markers" {
  let document = markdown_editor_format_for_selection(
    "Text **bold** and `code`",
    { caret: 9, selection: None },
  )
  inspect(document.blocks.length(), content="1")
  guard document.blocks[0].runs
    is [
      { text: "Text ", source_range: Some({ start: 0, end: 5 }), .. },
      {
        text: "**bold**",
        visual_text: None,
        source_range: Some({ start: 5, end: 13 }),
        ..,
      },
      { text: " and ", source_range: Some({ start: 13, end: 18 }), .. },
      { text: "code", source_range: Some({ start: 19, end: 23 }), .. },
    ] else {
    fail("expected active bold run to reveal markdown markers")
  }
}

///|
test "markdown editor formatter keeps inactive inline markers hidden" {
  let document = markdown_editor_format_for_selection(
    "Text **bold** and `code`",
    { caret: 2, selection: None },
  )
  guard document.blocks[0].runs
    is [
      { text: "Text ", source_range: Some({ start: 0, end: 5 }), .. },
      { text: "bold", source_range: Some({ start: 7, end: 11 }), .. },
      { text: " and ", source_range: Some({ start: 13, end: 18 }), .. },
      { text: "code", source_range: Some({ start: 19, end: 23 }), .. },
    ] else {
    fail("expected inactive inline markers to stay hidden")
  }
}

///|
test "markdown editor formatter reveals active inline marker variants" {
  let italic = markdown_editor_format_for_selection(
    "Try *one* and __two__ and ~~old~~",
    { caret: 6, selection: None },
  )
  guard italic.blocks[0].runs[1]
    is {
      text: "*one*",
      visual_text: None,
      source_range: Some({ start: 4, end: 9 }),
      ..,
    } else {
    fail("expected active italic marker to reveal")
  }
  let underscore = markdown_editor_format_for_selection(
    "Try *one* and __two__ and ~~old~~",
    { caret: 16, selection: None },
  )
  guard underscore.blocks[0].runs[3]
    is {
      text: "__two__",
      visual_text: None,
      source_range: Some({ start: 14, end: 21 }),
      ..,
    } else {
    fail("expected active underscore bold marker to reveal")
  }
  let strike = markdown_editor_format_for_selection(
    "Try *one* and __two__ and ~~old~~",
    { caret: 28, selection: None },
  )
  guard strike.blocks[0].runs[5]
    is {
      text: "~~old~~",
      visual_text: None,
      source_range: Some({ start: 26, end: 33 }),
      ..,
    } else {
    fail("expected active strike marker to reveal")
  }
  let code = markdown_editor_format_for_selection("Use `code` here", {
    caret: 6,
    selection: None,
  })
  guard code.blocks[0].runs[1]
    is {
      text: "`code`",
      visual_text: None,
      source_range: Some({ start: 4, end: 10 }),
      ..,
    } else {
    fail("expected active code marker to reveal")
  }
}

///|
test "markdown editor formatter reveals active reference markers" {
  let document = markdown_editor_format_for_selection(
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI), ![logo](logo.png), <https://wzzc-dev.github.io/MoUI> and <hello@example.dev>",
    { caret: 9, selection: None },
  )
  guard document.blocks[0].runs
    is [
      { text: "Visit ", source_range: Some({ start: 0, end: 6 }), .. },
      {
        text: "[MoUI](https://wzzc-dev.github.io/MoUI)",
        visual_text: None,
        source_range: Some({ start: 6, end: 30 }),
        ..,
      },
      { text: ", ", source_range: Some({ start: 30, end: 32 }), .. },
      {
        text: "logo",
        visual_text: Some("logo"),
        source_range: Some({ start: 34, end: 38 }),
        ..,
      },
      { text: ", ", source_range: Some({ start: 49, end: 51 }), .. },
      {
        text: "https://wzzc-dev.github.io/MoUI",
        source_range: Some({ start: 52, end: 68 }),
        ..,
      },
      { text: " and ", source_range: Some({ start: 69, end: 74 }), .. },
      {
        text: "hello@example.dev",
        source_range: Some({ start: 75, end: 92 }),
        ..,
      },
    ] else {
    fail("expected active link to reveal markdown reference markers")
  }
  let image = markdown_editor_format_for_selection(
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI), ![logo](logo.png), <https://wzzc-dev.github.io/MoUI> and <hello@example.dev>",
    { caret: 36, selection: None },
  )
  guard image.blocks[0].runs[3]
    is {
      text: "![logo](logo.png)",
      visual_text: None,
      source_range: Some({ start: 32, end: 49 }),
      ..,
    } else {
    fail("expected active image to reveal markdown reference markers")
  }
  let autolink = markdown_editor_format_for_selection(
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI), ![logo](logo.png), <https://wzzc-dev.github.io/MoUI> and <hello@example.dev>",
    { caret: 60, selection: None },
  )
  guard autolink.blocks[0].runs[5]
    is {
      text: "<https://wzzc-dev.github.io/MoUI>",
      visual_text: None,
      source_range: Some({ start: 51, end: 69 }),
      ..,
    } else {
    fail("expected active autolink to reveal angle brackets")
  }
  let email = markdown_editor_format_for_selection(
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI), ![logo](logo.png), <https://wzzc-dev.github.io/MoUI> and <hello@example.dev>",
    { caret: 82, selection: None },
  )
  guard email.blocks[0].runs[7]
    is {
      text: "<hello@example.dev>",
      visual_text: None,
      source_range: Some({ start: 74, end: 93 }),
      ..,
    } else {
    fail("expected active email autolink to reveal angle brackets")
  }
}

///|
test "markdown editor formatter maps link image and strike delimiters" {
  let document = markdown_editor_format(
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI), ![logo](logo.png), ~~old~~, <https://wzzc-dev.github.io/MoUI> and <hello@example.dev>",
  )
  inspect(document.blocks.length(), content="1")
  guard document.blocks[0].runs
    is [
      { text: "Visit ", source_range: Some({ start: 0, end: 6 }), .. },
      { text: "MoUI", source_range: Some({ start: 7, end: 11 }), .. },
      { text: ", ", source_range: Some({ start: 30, end: 32 }), .. },
      {
        text: "logo",
        visual_text: Some("logo"),
        image_source: Some("logo.png"),
        source_range: Some({ start: 34, end: 38 }),
        ..,
      },
      { text: ", ", source_range: Some({ start: 49, end: 51 }), .. },
      { text: "old", source_range: Some({ start: 53, end: 56 }), .. },
      { text: ", ", source_range: Some({ start: 58, end: 60 }), .. },
      {
        text: "https://wzzc-dev.github.io/MoUI",
        source_range: Some({ start: 61, end: 77 }),
        ..,
      },
      { text: " and ", source_range: Some({ start: 78, end: 83 }), .. },
      {
        text: "hello@example.dev",
        source_range: Some({ start: 84, end: 101 }),
        ..,
      },
    ] else {
    fail(
      "expected source ranges to skip link image strike and autolink delimiters",
    )
  }
  guard document.blocks[0].runs[5].decoration
    is Some(@moui_richtext.RichTextDecoration::Strikethrough) else {
    fail("expected strikethrough decoration")
  }
}

///|
test "markdown editor renders image preview while mapping alt text" {
  let app = MarkdownEditorApp::new()
  app.set_document("![logo](image.png)")
  let runtime = app.runtime(width=980.0, height=640.0)
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawImage({ source: "image.png", .. })
    }),
  )
  assert_false(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text: "[image: logo]", .. })
    }),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  let copied = runtime.dispatch_focused_text_command(@core.CommandIntent::Copy)
  guard copied.clipboard_text is Some(text) else {
    fail("expected copied image alt text")
  }
  inspect(text, content="logo")
}
