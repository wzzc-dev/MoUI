///|
test "markdown editor paragraph reference probe avoids unicode boundary drift" {
  let text = "前缀 🤣 [MoUI](https://wzzc-dev.github.io/MoUI) tail"
  inspect(
    markdown_editor_paragraph_reference_probe(text, 9, image=false),
    content="true",
  )
  inspect(
    markdown_editor_paragraph_reference_probe(text, 9, image=true),
    content="false",
  )
  let image = "前缀 🤣 ![logo](assets/logo.png) tail"
  inspect(
    markdown_editor_paragraph_reference_probe(image, 10, image=true),
    content="true",
  )
  inspect(
    markdown_editor_paragraph_reference_probe(image, 10, image=false),
    content="false",
  )
}

///|
test "markdown editor paragraph reference probe stays on current line" {
  inspect(
    markdown_editor_paragraph_reference_probe("[old\ntext]", 6, image=false),
    content="false",
  )
  inspect(
    markdown_editor_paragraph_reference_probe("<old\ntext>", 6, image=false),
    content="false",
  )
}
