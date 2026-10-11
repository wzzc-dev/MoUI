///|
test "markdown format palette catalog is stable" {
  let items = markdown_format_palette_items()
  inspect(items.length(), content="32")
  inspect(items[0].action, content="paragraph")
  inspect(items[0].label, content="Paragraph")
  inspect(items[0].group, content="Block")
  inspect(items[0].shortcut, content="Meta+0 / Ctrl+0")
  // Every catalog row has a unique action id.
  let actions : Array[String] = []
  for item in items {
    assert_false(actions.contains(item.action))
    actions.push(item.action)
  }
  // The "look-wide" entry mirrors MoMark's labels.
  let wide = items.filter(item => item.action == "look-wide")
  inspect(wide.length(), content="1")
  inspect(wide[0].label, content="Wide Look")
  inspect(wide[0].group, content="View")
}

///|
test "markdown format palette filter matches label group and shortcut" {
  inspect(markdown_format_palette_filtered_items("").length(), content="32")
  inspect(markdown_format_palette_filtered_items("   ").length(), content="32")
  // Case-insensitive label match.
  inspect(
    markdown_format_palette_filtered_items("BOLD")[0].action,
    content="bold",
  )
  // Group match returns every block entry.
  let block = markdown_format_palette_filtered_items("block")
  inspect(block.length(), content="13")
  // Shortcut match is case-insensitive too.
  let meta_alt = markdown_format_palette_filtered_items("meta+alt")
  assert_true(meta_alt.length() > 0)
  // Unknown queries return nothing.
  inspect(markdown_format_palette_filtered_items("zzz").length(), content="0")
}

///|
test "markdown palette action maps engine commands" {
  guard markdown_command_from_palette_action("bold") is Some(command) else {
    fail("expected bold command")
  }
  assert_true(command == @richtext.MarkdownEditorCommand::Bold)
  guard markdown_command_from_palette_action("h4") is Some(command) else {
    fail("expected heading command")
  }
  assert_true(command == @richtext.MarkdownEditorCommand::Heading(4))
  guard markdown_command_from_palette_action("table-align-right")
    is Some(command) else {
    fail("expected table alignment command")
  }
  assert_true(
    command ==
    @richtext.MarkdownEditorCommand::SetTableColumnAlignment(
      Some(@core.TextAlign::TextEnd),
    ),
  )
  guard markdown_command_from_palette_action("link-target") is Some(command) else {
    fail("expected link target command")
  }
  assert_true(
    command ==
    @richtext.MarkdownEditorCommand::SetLinkTarget(
      "https://wzzc-dev.github.io/MoUI",
    ),
  )
  // View/app actions intentionally have no engine command.
  assert_true(markdown_command_from_palette_action("source-mode") is None)
  assert_true(markdown_command_from_palette_action("html-export") is None)
  assert_true(markdown_command_from_palette_action("look-warm") is None)
  assert_true(markdown_command_from_palette_action("unknown") is None)
}
