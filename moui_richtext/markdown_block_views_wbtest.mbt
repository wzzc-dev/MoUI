///|
/// Regression coverage for the block-view contribution registry and the
/// nesting-aware HTML container scanner.
fn markdown_block_view_wbtest_projects(block : MarkdownBlock) -> Bool {
  match
    markdown_block_view_project(
      block,
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    Some(projection) => projection.runs.length() > 0
    None => false
  }
}

///|
fn markdown_block_view_wbtest_images(block : MarkdownBlock) -> Int {
  match
    markdown_block_view_project(
      block,
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    Some(projection) =>
      projection.runs.fold(
        (count, run) => {
          count + (if run.image_source is Some(_) { 1 } else { 0 })
        },
        init=0,
      )
    None => -1
  }
}

///|
fn markdown_block_view_wbtest_projected_flags(source : String) -> Array[Bool] {
  parse_markdown(source).map(block => {
    if block.kind is MarkdownBlockKind::HtmlBlock {
      markdown_block_view_wbtest_projects(block)
    } else {
      false
    }
  })
}

///|
test "container view projects badge rows wrapped in anchors" {
  let blocks = parse_markdown(
    "<div align=\"center\"><a href=\"#\"><img src=\"b1.svg\"/></a><a href=\"#\"><img src=\"b2.svg\"/></a></div>",
  )
  inspect(blocks.length(), content="1")
  guard blocks[0].kind is MarkdownBlockKind::HtmlBlock else {
    fail("expected a single html block")
  }
  inspect(markdown_block_view_wbtest_images(blocks[0]), content="2")
}

///|
test "container view skips comments and keeps nbsp spacing inline" {
  let blocks = parse_markdown(
    "<div align=\"center\">\n<!-- logos -->\n  <img src=\"a.png\"/>&nbsp;<img src=\"b.png\"/>\n</div>",
  )
  inspect(blocks.length(), content="1")
  match
    markdown_block_view_project(
      blocks[0],
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    None => fail("expected the comment/nbsp container to project")
    Some(projection) => {
      inspect(projection.runs.length(), content="3")
      inspect(
        projection.runs[1].visual_text.unwrap_or("<missing>"),
        content=" ",
      )
      for run in projection.runs {
        if run.text.contains("<!--") {
          fail("comments must not leak into projected runs")
        }
      }
    }
  }
}

///|
test "container view projects paragraphs and captions as text runs" {
  let blocks = parse_markdown(
    "<div align=\"center\">\n  <img src=\"logo.png\"/>\n  <p>A project by someone</p>\n</div>",
  )
  inspect(blocks.length(), content="1")
  match
    markdown_block_view_project(
      blocks[0],
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    None => fail("expected the caption container to project")
    Some(projection) => {
      let mut caption = false
      for run in projection.runs {
        if run.visual_text.unwrap_or("").contains("A project by someone") {
          caption = true
        }
      }
      guard caption else {
        fail("expected the paragraph caption as a text run")
      }
    }
  }
}

///|
test "unclosed container cannot swallow the next healthy container" {
  let source =
    #|<div align="center">
    #|  <img src="a.png"/>
    #|
    #|<div align="center">
    #|  <img src="b.png"/>
    #|</div>
  debug_inspect(
    markdown_block_view_wbtest_projected_flags(source),
    content="[false, true]",
  )
  let session = MarkdownDocumentSession::new(source)
  let session_flags = session.editor_blocks.map(editor_block => {
    if editor_block.block.kind is MarkdownBlockKind::HtmlBlock {
      markdown_block_view_wbtest_projects(editor_block.block)
    } else {
      false
    }
  })
  debug_inspect(session_flags, content="[false, false, true]")
}

///|
test "nested containers close at their own depth and flatten" {
  let blocks = parse_markdown(
    "<div align=\"center\">\n  <div>\n    <img src=\"a.png\"/>\n  </div>\n</div>",
  )
  inspect(blocks.length(), content="1")
  inspect(markdown_block_view_wbtest_images(blocks[0]), content="1")
}

///|
test "sibling containers split into separate projectable blocks" {
  let blocks = parse_markdown(
    "<div align=\"center\">\n  <img src=\"a.png\"/>\n</div>\n<div align=\"center\">\n  <img src=\"b.png\"/>\n</div>",
  )
  inspect(blocks.length(), content="2")
  inspect(markdown_block_view_wbtest_images(blocks[0]), content="1")
  inspect(markdown_block_view_wbtest_images(blocks[1]), content="1")
}

///|
test "unsupported structural tags keep the container raw" {
  let blocks = parse_markdown(
    "<div align=\"center\"><img src=\"a.png\"/><table><tr><td>x</td></tr></table></div>",
  )
  inspect(blocks.length(), content="1")
  guard !markdown_block_view_wbtest_projects(blocks[0]) else {
    fail("expected the table container to stay raw")
  }
}

///|
test "text after the closing container stays visible" {
  let blocks = parse_markdown(
    "<div align=\"center\"><img src=\"a.png\"/></div> tail",
  )
  inspect(blocks.length(), content="1")
  match
    markdown_block_view_project(
      blocks[0],
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    None => fail("expected the trailing-text container to project")
    Some(projection) => {
      let mut tail = false
      for run in projection.runs {
        if run.visual_text.unwrap_or("").contains("tail") {
          tail = true
        }
      }
      guard tail else { fail("expected trailing text run") }
    }
  }
}

///|
test "session editor projects container blocks through the registry" {
  let source = "<div align=\"center\"><a href=\"#\"><img src=\"b1.svg\"/></a></div>"
  let session = MarkdownDocumentSession::new(source)
  guard session.editor_blocks.length() == 1 else {
    fail("expected a single editor block")
  }
  let rich = markdown_editor_block_to_rich_text(
    source,
    session.editor_blocks[0],
    @core.FontSpec::new(size=16.0),
  )
  guard rich.runs.length() > 0 && rich.runs[0].image_source is Some(_) else {
    fail("expected the session container block to project an image")
  }
}

///|
test "paragraph with an inline anchor projects instead of staying raw" {
  let blocks = parse_markdown(
    "<div align=\"center\">\n<p>\n简体中文 | <a href=\"./README.md\">English</a>\n</p>\n</div>",
  )
  inspect(blocks.length(), content="1")
  guard blocks[0].kind is MarkdownBlockKind::HtmlBlock else {
    fail("expected a single html block")
  }
  match
    markdown_block_view_project(
      blocks[0],
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    None => fail("expected the inline-link paragraph to project")
    Some(projection) => {
      let mut english = false
      for run in projection.runs {
        if run.visual_text.unwrap_or("").contains("English") {
          english = true
        }
      }
      guard english else { fail("expected the inline link text as a run") }
    }
  }
}

///|
test "badge row anchored inside a paragraph projects its images" {
  let blocks = parse_markdown(
    "<div align=\"center\">\n<p>\n<a href=\"#\"><img src=\"b1.svg\"/></a>\n<a href=\"#\"><img src=\"b2.svg\"/></a>\n</p>\n</div>",
  )
  inspect(blocks.length(), content="1")
  guard blocks[0].kind is MarkdownBlockKind::HtmlBlock else {
    fail("expected a single html block")
  }
  inspect(markdown_block_view_wbtest_images(blocks[0]), content="2")
}

///|
/// End-to-end reproduction of a README hero block: a multi-line `img` tag,
/// a heading, a paragraph with an inline link, and anchored badge rows —
/// all of which must project instead of falling back to raw HTML source.
test "readme hero container projects images, heading and links" {
  let source =
    #|<div align="center">
    #|<img src="resource/branding/moonbud-mascot.svg" width="100"
    #|alt="MoUI Logo" />
    #|<h1>MoUI</h1>
    #|<p>多平台 MoonBit 声明式 GUI 框架</p>
    #|<p>
    #|简体中文 | <a href="./README.md">English</a>
    #|</p>
    #|<p>
    #|<a href="./LICENSE"><img src="https://img.shields.io/badge/license.svg" alt="license" /></a>
    #|<a href="https://github.com/wzzc-dev/MoUI"><img src="https://img.shields.io/github/stars.svg" alt="stars" /></a>
    #|</p>
    #|<p>
    #|<a href="#快速开始">快速开始</a> ·
    #|<a href="#项目结构">项目结构</a>
    #|</p>
    #|</div>
  let blocks = parse_markdown(source)
  inspect(blocks.length(), content="1")
  guard blocks[0].kind is MarkdownBlockKind::HtmlBlock else {
    fail("expected a single html block")
  }
  match
    markdown_block_view_project(
      blocks[0],
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    None => fail("expected the README hero container to project")
    Some(projection) => {
      let mut mascot = false
      let mut heading = false
      let mut english = false
      let mut nav = false
      for run in projection.runs {
        match run.image_source {
          Some(path) => if path.contains("moonbud-mascot") { mascot = true }
          None => ()
        }
        let visual = run.visual_text.unwrap_or("")
        if visual.contains("MoUI") {
          heading = true
        }
        if visual.contains("English") {
          english = true
        }
        if visual.contains("快速开始") {
          nav = true
        }
      }
      guard mascot else { fail("expected the mascot image run") }
      guard heading else { fail("expected the heading text run") }
      guard english else { fail("expected the inline link run") }
      guard nav else { fail("expected the nav link run") }
      guard projection.line_align is Some(@core.TextAlign::TextCenter) else {
        fail("expected the container to project center alignment")
      }
    }
  }
}

///|
test "container view drops the trailing newline after the last child" {
  let blocks = parse_markdown(
    "<div align=\"center\"><img src=\"logo.png\" alt=\"logo\"/><p>intro</p><p>nav</p>\n</div>",
  )
  inspect(blocks.length(), content="1")
  guard blocks[0].kind is MarkdownBlockKind::HtmlBlock else {
    fail("expected a single html block")
  }
  match
    markdown_block_view_project(
      blocks[0],
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    None => fail("expected the container to project")
    Some(projection) => {
      // logo row separator, intro row separator, then the nav text — the
      // newline after the final </p> must not survive as an empty last line.
      inspect(projection.runs.length(), content="5")
      let last = projection.runs[projection.runs.length() - 1]
      inspect(rich_text_run_visual_text(last), content="nav")
    }
  }
}

///|
test "container view keeps interior row separators" {
  let blocks = parse_markdown(
    "<div align=\"center\"><p>first</p><p>second</p></div>",
  )
  guard blocks[0].kind is MarkdownBlockKind::HtmlBlock else {
    fail("expected a single html block")
  }
  match
    markdown_block_view_project(
      blocks[0],
      @core.FontSpec::new(size=16.0),
      base_dir=None,
    ) {
    None => fail("expected the container to project")
    Some(projection) => {
      let visuals = projection.runs.map(run => rich_text_run_visual_text(run))
      debug_inspect(visuals, content="[\"first\", \"\\n\", \"second\"]")
    }
  }
}
