///|
test "probe inline rendering in lists and tables" {
  let doc = "# T\n\n- `A` **AA**\n- [ ] `A` **AA**\n1. `A` **AA**\n\n> `A` **AA**\n"
  let blocks = parse_markdown(doc)
  for b in blocks {
    let mut info = "kind="
    match b.kind {
      Heading(_) => info = "heading"
      UnorderedListItem => info = "ul"
      TaskListItem(false) => info = "task"
      OrderedListItem(_) => info = "ol"
      Blockquote => info = "quote"
      Paragraph => info = "para"
      _ => info = "other"
    }
    for i in b.inlines {
      let kd = match i.kind {
        Plain => "P"
        Code => "C"
        Bold => "B"
        Italic => "I"
        _ => "O"
      }
      info = info + " {" + kd + " " + i.text + "}"
    }
    println(info)
  }
}
