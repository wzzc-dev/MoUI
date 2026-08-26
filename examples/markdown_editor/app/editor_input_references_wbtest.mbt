///|
test "markdown editor removes reference-style markers at caret edges" {
  let backspace_link = markdown_editor_transform_input(
    "Visit [MoUI][site] today",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_link.text, content="Visit MoUI today")
  inspect(backspace_link.caret, content="6")

  let delete_link = markdown_editor_transform_input(
    "Visit [MoUI][site] today",
    11,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_link.text, content="Visit MoUI today")
  inspect(delete_link.caret, content="6")

  let backspace_image = markdown_editor_transform_input(
    "Insert ![logo][asset] here",
    9,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_image.text, content="Insert logo here")
  inspect(backspace_image.caret, content="7")

  let delete_image = markdown_editor_transform_input(
    "Insert ![logo][asset] here",
    13,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_image.text, content="Insert logo here")
  inspect(delete_image.caret, content="7")

  let shortcut = markdown_editor_transform_input(
    "Visit [MoUI] today\n\n[MoUI]: https://wzzc-dev.github.io/MoUI",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(
    shortcut.text,
    content="Visit MoUI today\n\n[MoUI]: https://wzzc-dev.github.io/MoUI",
  )
  inspect(shortcut.caret, content="6")

  inspect(
    markdown_editor_transform_input("Visit [MoUI] today", 7, None, "\u{0008}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes reference markers at outside edges" {
  let link_backspace = markdown_editor_transform_input(
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI) today",
    45,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(link_backspace.text, content="Visit MoUI today")
  inspect(link_backspace.caret, content="6")

  let link_delete = markdown_editor_transform_input(
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI) today",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(link_delete.text, content="Visit MoUI today")
  inspect(link_delete.caret, content="6")

  let image_backspace = markdown_editor_transform_input(
    "Insert ![logo](image.png) here",
    25,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(image_backspace.text, content="Insert logo here")
  inspect(image_backspace.caret, content="7")

  let image_delete = markdown_editor_transform_input(
    "Insert ![logo](image.png) here",
    7,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(image_delete.text, content="Insert logo here")
  inspect(image_delete.caret, content="7")

  let reference_backspace = markdown_editor_transform_input(
    "Visit [MoUI][site] today",
    18,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(reference_backspace.text, content="Visit MoUI today")
  inspect(reference_backspace.caret, content="6")

  let reference_delete = markdown_editor_transform_input(
    "Visit [MoUI][site] today",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(reference_delete.text, content="Visit MoUI today")
  inspect(reference_delete.caret, content="6")

  let shortcut_backspace = markdown_editor_transform_input(
    "Visit [MoUI] today\n\n[MoUI]: https://wzzc-dev.github.io/MoUI",
    12,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(
    shortcut_backspace.text,
    content="Visit MoUI today\n\n[MoUI]: https://wzzc-dev.github.io/MoUI",
  )
  inspect(shortcut_backspace.caret, content="6")

  inspect(
    markdown_editor_transform_input("Visit [MoUI] today", 12, None, "\u{0008}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes footnote reference markers at caret edges" {
  let source = "See [^note] here\n\n[^note]: More"
  let backspace_open = markdown_editor_transform_input(
    source,
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_open.text, content="See note here\n\n[^note]: More")
  inspect(backspace_open.caret, content="4")

  let delete_close = markdown_editor_transform_input(
    source,
    10,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_close.text, content="See note here\n\n[^note]: More")
  inspect(delete_close.caret, content="4")

  let backspace_end = markdown_editor_transform_input(
    source,
    11,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_end.text, content="See note here\n\n[^note]: More")
  inspect(backspace_end.caret, content="4")

  let delete_open = markdown_editor_transform_input(source, 4, None, "\u{007f}").unwrap()
  inspect(delete_open.text, content="See note here\n\n[^note]: More")
  inspect(delete_open.caret, content="4")

  inspect(
    markdown_editor_transform_input("See [^] here", 6, None, "\u{0008}") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("See [^note here", 6, None, "\u{0008}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes autolink markers at caret edges" {
  let backspace_url = markdown_editor_transform_input(
    "Visit <https://wzzc-dev.github.io/MoUI> today",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(
    backspace_url.text,
    content="Visit https://wzzc-dev.github.io/MoUI today",
  )
  inspect(backspace_url.caret, content="6")

  let delete_url = markdown_editor_transform_input(
    "Visit <https://wzzc-dev.github.io/MoUI> today",
    38,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(
    delete_url.text,
    content="Visit https://wzzc-dev.github.io/MoUI today",
  )
  inspect(delete_url.caret, content="6")

  let backspace_email = markdown_editor_transform_input(
    "Mail <hello@example.dev> now",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_email.text, content="Mail hello@example.dev now")
  inspect(backspace_email.caret, content="5")

  let delete_email = markdown_editor_transform_input(
    "Mail <hello@example.dev> now",
    23,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_email.text, content="Mail hello@example.dev now")
  inspect(delete_email.caret, content="5")

  inspect(
    markdown_editor_transform_input("Visit <not a link>", 17, None, "\u{007f}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes autolink markers at outside edges" {
  let backspace_url = markdown_editor_transform_input(
    "Visit <https://wzzc-dev.github.io/MoUI> today",
    39,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(
    backspace_url.text,
    content="Visit https://wzzc-dev.github.io/MoUI today",
  )
  inspect(backspace_url.caret, content="6")

  let delete_url = markdown_editor_transform_input(
    "Visit <https://wzzc-dev.github.io/MoUI> today",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(
    delete_url.text,
    content="Visit https://wzzc-dev.github.io/MoUI today",
  )
  inspect(delete_url.caret, content="6")

  let backspace_email = markdown_editor_transform_input(
    "Mail <hello@example.dev> now",
    24,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_email.text, content="Mail hello@example.dev now")
  inspect(backspace_email.caret, content="5")

  let delete_email = markdown_editor_transform_input(
    "Mail <hello@example.dev> now",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_email.text, content="Mail hello@example.dev now")
  inspect(delete_email.caret, content="5")

  inspect(
    markdown_editor_transform_input("Visit <not a link>", 6, None, "\u{007f}")
    is None,
    content="true",
  )
}
