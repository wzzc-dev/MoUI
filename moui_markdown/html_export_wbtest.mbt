///|
test "markdown html export renders document structure" {
  let source = "# Draft\n\nParagraph with **bold** and [MoUI](https://wzzc-dev.github.io/MoUI?a=1&b=2).\n\n![Alt & logo](assets/logo.png)\n\n- [x] Done\n- [ ] Todo\n\n| Name | Value |\n| :--- | ---: |\n| A | 1 |\n\n```mbt\nlet x = 1 < 2\n```\n\nAT&T > 1"
  let snapshot = @richtext.MarkdownEditorSnapshot::parse(source)
  let html = markdown_html_document(snapshot, "Draft")
  assert_true(html.contains("<!doctype html>"))
  assert_true(html.contains("<title>Draft</title>"))
  assert_true(html.contains("<h1>Draft</h1>"))
  assert_true(html.contains("<strong>bold</strong>"))
  assert_true(
    html.contains(
      "<a href=\"https://wzzc-dev.github.io/MoUI?a=1&amp;b=2\">MoUI</a>",
    ),
  )
  assert_true(
    html.contains("<img src=\"assets/logo.png\" alt=\"Alt &amp; logo\">"),
  )
  assert_true(
    html.contains(
      "<li class=\"task-list-item\"><input type=\"checkbox\" disabled checked> Done</li>",
    ),
  )
  assert_true(html.contains("<table>"))
  assert_true(html.contains("<th>Name</th>"))
  assert_true(html.contains("<td style=\"text-align:right\">1</td>"))
  assert_true(
    html.contains(
      "<pre><code class=\"language-mbt\">let x = 1 &lt; 2</code></pre>",
    ),
  )
  assert_true(html.contains("<p>AT&amp;T &gt; 1</p>"))
}

///|
test "markdown html export escapes titles and attributes" {
  inspect(
    markdown_html_escape_text("<a> & </a>"),
    content="&lt;a&gt; &amp; &lt;/a&gt;",
  )
  inspect(
    markdown_html_escape_attribute("\"x\" & 'y' <z>"),
    content="&quot;x&quot; &amp; &#39;y&#39; &lt;z&gt;",
  )
  let html = markdown_html_document(
    @richtext.MarkdownEditorSnapshot::parse("Text"),
    "A < B & C",
  )
  assert_true(html.contains("<title>A &lt; B &amp; C</title>"))
}

///|
test "markdown html export preserves raw html galleries" {
  let gallery =
    #|<div align="center">
    #|
    #|  <img src="resource/a.png" width="48%" alt="A"/>
    #|
    #|  <br/><br/>
    #|
    #|  <img src="resource/b.png" width="48%" alt="B"/>
    #|
    #|</div>
  let snapshot = @richtext.MarkdownEditorSnapshot::parse(gallery)
  let html = markdown_html_document(snapshot, "Gallery")
  assert_true(html.contains(gallery))
}
