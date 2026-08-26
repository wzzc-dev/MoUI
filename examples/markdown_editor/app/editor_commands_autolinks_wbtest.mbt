///|
test "markdown editor paste and typed space complete autolinks" {
  let pasted = markdown_editor_transform_input(
    "Visit ",
    6,
    None,
    "https://wzzc-dev.github.io/MoUI",
  ).unwrap()
  inspect(pasted.text, content="Visit <https://wzzc-dev.github.io/MoUI>")
  inspect(pasted.caret, content="39")
  let unicode_pasted = markdown_editor_transform_input(
    "前缀 🤣 ",
    5,
    None,
    "https://wzzc-dev.github.io/MoUI",
  ).unwrap()
  inspect(
    unicode_pasted.text,
    content="前缀 🤣 <https://wzzc-dev.github.io/MoUI>",
  )
  inspect(unicode_pasted.caret, content="38")
  let punctuated_paste = markdown_editor_transform_input(
    "Visit ",
    6,
    None,
    "https://wzzc-dev.github.io/MoUI,",
  ).unwrap()
  inspect(
    punctuated_paste.text,
    content="Visit <https://wzzc-dev.github.io/MoUI>,",
  )
  inspect(punctuated_paste.caret, content="40")
  let wrapped_paste = markdown_editor_transform_input(
    "Visit ",
    6,
    None,
    "(https://wzzc-dev.github.io/MoUI),",
  ).unwrap()
  inspect(
    wrapped_paste.text,
    content="Visit (<https://wzzc-dev.github.io/MoUI>),",
  )
  inspect(wrapped_paste.caret, content="42")
  let typed = markdown_editor_transform_input(
    "Visit https://wzzc-dev.github.io/MoUI",
    37,
    None,
    " ",
  ).unwrap()
  inspect(typed.text, content="Visit <https://wzzc-dev.github.io/MoUI> ")
  inspect(typed.caret, content="40")
  let punctuated_typed = markdown_editor_transform_input(
    "Visit https://wzzc-dev.github.io/MoUI,",
    38,
    None,
    " ",
  ).unwrap()
  inspect(
    punctuated_typed.text,
    content="Visit <https://wzzc-dev.github.io/MoUI>, ",
  )
  inspect(punctuated_typed.caret, content="41")
  let wrapped_typed = markdown_editor_transform_input(
    "Visit (https://wzzc-dev.github.io/MoUI),",
    40,
    None,
    " ",
  ).unwrap()
  inspect(
    wrapped_typed.text,
    content="Visit (<https://wzzc-dev.github.io/MoUI>), ",
  )
  inspect(wrapped_typed.caret, content="43")
  inspect(
    markdown_editor_transform_input(
      "Visit <https://wzzc-dev.github.io/MoUI>",
      38,
      None,
      " ",
    )
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input(
      "```\nhttps://wzzc-dev.github.io/MoUI\n```",
      35,
      None,
      " ",
    )
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
