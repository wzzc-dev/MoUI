///|
/// Fake outline used by the resolver tests: a closed triangle 20 wide, 8 tall
/// above the baseline (negative y is up in SVG user space).
fn svg_test_triangle() -> SvgTextRunOutline {
  {
    width: 20.0,
    polygons: [[(0.0, 0.0), (20.0, 0.0), (10.0, -8.0)]],
  }
}

///|
test "svg_scan_text_anchors resolves inheritance in document order" {
  let svg = "<svg><text x=\"1\"/></svg>"
  let scanned = svg_scan_text_anchors(svg)
  inspect(scanned.length(), content="1")
  debug_inspect(scanned[0].anchor, content="Start")
  debug_inspect(scanned[0].font_size, content="None")
  let centered = "<svg><g text-anchor=\"middle\" font-size=\"110\">" +
    "<text x=\"1\"/><text x=\"2\" font-size=\"9\"/></g>" +
    "<text text-anchor=\"end\" x=\"3\"/></svg>"
  let runs = svg_scan_text_anchors(centered)
  inspect(runs.length(), content="3")
  debug_inspect(runs[0].anchor, content="Middle")
  // Container font-size inherits; an own value wins over the inherited one.
  debug_inspect(runs[0].font_size, content="Some(110)")
  debug_inspect(runs[1].font_size, content="Some(9)")
  // After the container closes, later text is back to defaults.
  debug_inspect(runs[2].anchor, content="End")
  debug_inspect(runs[2].font_size, content="None")
  // textLength is captured per text element when present.
  let sized = "<svg><text textLength=\"410\" x=\"1\"/></svg>"
  let with_length = svg_scan_text_anchors(sized)
  debug_inspect(with_length[0].text_length, content="Some(410)")
  let popped = "<svg><g text-anchor=\"end\"></g><text x=\"1\"/></svg>"
  let after_pop = svg_scan_text_anchors(popped)
  debug_inspect(after_pop[0].anchor, content="Start")
  // Self-closing containers must not leak their anchor onto later text.
  let self_closing = "<svg><g text-anchor=\"middle\"/><text x=\"1\"/></svg>"
  debug_inspect(svg_scan_text_anchors(self_closing)[0].anchor, content="Start")
}

///|
test "svg_apply_text_paths replaces resolved runs with anchored paths" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"20\">" +
    "<g text-anchor=\"middle\"><text x=\"50\" y=\"15\" font-size=\"11\">build</text></g>" +
    "<text x=\"10\" y=\"15\" font-size=\"11\">left</text></svg>"
  let document = @svg.parse_svg_document(svg).unwrap()
  let requested : Array[SvgTextRun] = []
  let resolver : SvgTextPathResolver = fn(run) {
    requested.push(run)
    Some(svg_test_triangle())
  }
  let anchors = svg_scan_text_anchors(svg)
  let cursor : SvgTextAnchorCursor = { value: 0 }
  let replaced = svg_apply_text_paths(
    document.root(),
    resolver,
    anchors,
    cursor,
  )
  inspect(replaced, content="2")
  inspect(cursor.value, content="2")
  // Document order: the centered run first, then the start-anchored run.
  let first_commands : Array[String] = []
  svg_text_path_collect_first_commands(document.root(), first_commands)
  debug_inspect(first_commands, content="[MoveTo(40, 15), MoveTo(10, 15)]")
  // The request carried the scan results.
  inspect(requested.length(), content="2")
  debug_inspect(requested[0].anchor, content="Middle")
  debug_inspect(requested[0].text, content="build")
  debug_inspect(requested[1].anchor, content="Start")
}

///|
test "svg_apply_text_paths keeps declined runs on their original shape" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"20\">" +
    "<text x=\"10\" y=\"15\" font-size=\"11\">left</text></svg>"
  let document = @svg.parse_svg_document(svg).unwrap()
  let resolver : SvgTextPathResolver = fn(_run) { None }
  let anchors = svg_scan_text_anchors(svg)
  let cursor : SvgTextAnchorCursor = { value: 0 }
  let replaced = svg_apply_text_paths(
    document.root(),
    resolver,
    anchors,
    cursor,
  )
  inspect(replaced, content="0")
  let mut saw_text = false
  fn walk(node : @svg.SVGNode) -> Unit {
    match node.shape {
      @svg.Shape::Text(..) => saw_text = true
      @svg.Shape::Group => for child in node.children {
        walk(child)
      }
      _ => ()
    }
  }

  walk(document.root())
  assert_true(saw_text)
}

///|
test "svg_rasterize_rgba keeps working without an installed resolver" {
  clear_svg_text_path_resolver()
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 10\">" +
    "<rect width=\"20\" height=\"10\" fill=\"#ff0000\"/></svg>"
  assert_true(svg_rasterize_rgba(svg, 40, 20) is Some(_))
}

///|
test "svg_rasterize_rgba replaces text when a resolver is installed" {
  let resolver : SvgTextPathResolver = fn(run) {
    // Cover only the first run; the second keeps the bitmap fallback.
    if run.text == "build" {
      Some(svg_test_triangle())
    } else {
      None
    }
  }
  set_svg_text_path_resolver(resolver)
  // A document whose only paint is one resolved text run: the triangle now
  // comes from the resolver, so the pixels above its 20x8 box (scaled 2x)
  // must contain filled coverage even though the document has no shapes.
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 30 20\">" +
    "<text x=\"5\" y=\"15\" font-size=\"11\">build</text></svg>"
  match svg_rasterize_rgba(svg, 60, 40) {
    Some(pixels) => {
      // Center of the triangle's fill region in 2x space: y ~ 2*(15-4)=22,
      // x ~ 2*(5+10)=30.
      let row_bytes = 60 * 4
      let offset = 22 * row_bytes + 30 * 4
      assert_true(pixels[offset + 3].to_int() > 0)
    }
    None => fail("expected rasterized pixels")
  }
  clear_svg_text_path_resolver()
}

///|
/// Collect the first path command of every replaced text path, in document
/// order, as display strings.
fn svg_text_path_collect_first_commands(
  node : @svg.SVGNode,
  out : Array[String],
) -> Unit {
  match node.shape {
    @svg.Shape::Path(commands~) =>
      if commands.length() > 0 {
        match commands[0] {
          @svg.PathCommand::MoveTo(x, y) => out.push("MoveTo(\{x}, \{y})")
          _ => out.push("other")
        }
      }
    @svg.Shape::Group =>
      for child in node.children {
        svg_text_path_collect_first_commands(child, out)
      }
    _ => ()
  }
}
